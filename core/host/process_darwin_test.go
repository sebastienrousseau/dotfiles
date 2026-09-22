// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
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
