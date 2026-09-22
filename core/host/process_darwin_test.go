// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"errors"
	"syscall"
	"testing"

	"golang.org/x/sys/unix"
)

func TestOnlyZombies(t *testing.T) {
	if !onlyZombies(nil) {
		t.Fatal("absent group should be harmless")
	}
	for state := int8(0); state <= 7; state++ {
		group := make([]unix.KinfoProc, 2)
		group[0].Proc.P_stat = 5
		group[1].Proc.P_stat = state
		if got := onlyZombies(group); got != (state == 5) {
			t.Fatalf("state %d: got %v", state, got)
		}
	}
}

func TestGroupExitTransition(t *testing.T) {
	for _, kind := range []string{"exiting", "gone", "live", "unknown", "query-error", "permission-settles", "permission-live"} {
		t.Run(kind, func(t *testing.T) {
			calls, signals, pauses := 0, 0, 0
			err := settleGroup(func() ([]unix.KinfoProc, error) {
				calls++
				if kind == "query-error" {
					return nil, errors.New("permission denied")
				}
				if kind == "gone" && calls == 3 {
					return nil, nil
				}
				group := make([]unix.KinfoProc, 2)
				group[0].Proc.P_stat = 5
				group[1].Proc.P_stat = 2 // Runnable, including an exit transition.
				if kind == "unknown" {
					group[1].Proc.P_stat = 0
				}
				if (kind == "exiting" || kind == "permission-settles") && calls == 3 {
					group[1].Proc.P_stat = 5
				}
				return group, nil
			}, func() error {
				signals++
				if kind == "permission-settles" || kind == "permission-live" {
					return syscall.EPERM
				}
				return nil
			}, func() { pauses++ })
			wantSuccess := kind == "exiting" || kind == "gone" || kind == "permission-settles"
			if (err == nil) != wantSuccess {
				t.Fatalf("unexpected result: %v", err)
			}
			if (wantSuccess && calls != 3) || (kind == "query-error" && calls != 1) ||
				(kind == "permission-live" && calls != 1000) ||
				(!wantSuccess && kind != "query-error" && kind != "permission-live" && calls != 50) ||
				pauses != calls-1 || ((kind == "permission-settles" || kind == "permission-live") && signals != 1) ||
				(kind != "permission-settles" && kind != "permission-live" && signals != calls) {
				t.Fatalf("unexpected bound: %d queries, %d signals, %d pauses", calls, signals, pauses)
			}
		})
	}
}
