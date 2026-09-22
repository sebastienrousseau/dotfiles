//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"io"
	"os/exec"
	"testing"
	"time"
)

func TestProcessExitCleanup(t *testing.T) {
	// EOF can precede the kernel's final zombie transition. Exercise the real
	// short-lived process rather than inserting a sleep that hides this race.
	for i := 0; i < 100; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		cmd := exec.CommandContext(ctx, "/usr/bin/true")
		stop, err := configureProcess(cmd)
		if err != nil {
			cancel()
			t.Fatal(err)
		}
		out, err := cmd.StdoutPipe()
		if err != nil {
			cancel()
			t.Fatal(err)
		}
		if err = cmd.Start(); err != nil {
			cancel()
			t.Fatal(err)
		}
		_, readErr := io.Copy(io.Discard, out)
		stopErr := stop()
		waitErr := cmd.Wait()
		cancel()
		if readErr != nil || stopErr != nil || waitErr != nil {
			t.Fatalf("iteration %d: read=%v cleanup=%v wait=%v", i, readErr, stopErr, waitErr)
		}
	}
}
