//go:build !darwin && !linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"fmt"
	"os"
)

func read(*os.Root, string) ([]byte, Snapshot, error) {
	return nil, Snapshot{}, fmt.Errorf("DOT_E_POLICY: platform mutation driver unavailable")
}
func lock(*os.Root) (*os.File, error) {
	return nil, fmt.Errorf("DOT_E_POLICY: platform mutation driver unavailable")
}
func privateDir(*os.File) error {
	return fmt.Errorf("DOT_E_POLICY: platform mutation driver unavailable")
}
