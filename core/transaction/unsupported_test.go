//go:build !darwin && !linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"os"
	"path/filepath"
	"testing"
)

func TestUnsupportedPlatformFailsBeforeMutation(t *testing.T) {
	path := filepath.Join(t.TempDir(), "must-not-exist")
	if err := Init(path); err == nil {
		t.Fatal("unsupported mutation accepted")
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("unsupported driver mutated state")
	}
}
