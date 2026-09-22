// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"fmt"
	"os"

	"dotfiles.local/core/sandbox"
)

func run(args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("DOT_E_POLICY: internal sandbox requires exact plugin and stage paths")
	}
	return sandbox.Run(args[0], args[1])
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
