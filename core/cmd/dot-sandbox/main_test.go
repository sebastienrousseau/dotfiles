// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import "testing"

func TestExactArguments(t *testing.T) {
	for _, args := range [][]string{nil, {"one"}, {"one", "two", "three"}} {
		if err := run(args); err == nil {
			t.Fatal("invalid internal invocation accepted")
		}
	}
}
