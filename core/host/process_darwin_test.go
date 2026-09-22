// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"errors"
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
	for _, kind := range []string{"exiting", "gone", "live", "unknown", "query-error"} {
		t.Run(kind, func(t *testing.T) {
			calls, pauses := 0, 0
			got := settledGroup(func() ([]unix.KinfoProc, error) {
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
				if kind == "exiting" && calls == 3 {
					group[1].Proc.P_stat = 5
				}
				return group, nil
			}, func() { pauses++ })
			want := kind == "exiting" || kind == "gone"
			if got != want {
				t.Fatalf("got %v, want %v", got, want)
			}
			if (want && calls != 3) || (!want && kind != "query-error" && calls != 50) || (kind == "query-error" && calls != 1) || pauses != calls-1 {
				t.Fatalf("unexpected sampling bound: %d calls, %d pauses", calls, pauses)
			}
		})
	}
}
