// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"context"
	"dotfiles.local/core/host"
	"dotfiles.local/core/protocol"
	"dotfiles.local/core/transaction"
	"flag"
	"fmt"
	"os"
	"os/signal"
)

func run(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: dot-core init|register|apply|status|plan-id|recover|retry-effects|rollback|archive --root NEW_DEMO_DIRECTORY [--plugin ABSOLUTE_BINARY] [--assurance audit|process] [--allow-audit-plugin|--require-process-sandbox] [--plan-id SHA256]")
	}
	switch args[0] {
	case "init", "register", "apply", "status", "plan-id", "recover", "retry-effects", "rollback", "archive":
	default:
		return fmt.Errorf("DOT_E_PROTOCOL: unknown command %q", args[0])
	}
	f := flag.NewFlagSet(args[0], flag.ContinueOnError)
	root := f.String("root", "", "isolated hello demo directory (not your home/config)")
	var plugin, planID, assurance string
	var audit, process bool
	switch args[0] {
	case "register":
		f.StringVar(&plugin, "plugin", "", "absolute hello executable")
		f.StringVar(&assurance, "assurance", protocol.AssuranceAudit, "required plugin assurance: audit or process")
	case "apply":
		f.BoolVar(&audit, "allow-audit-plugin", false, "explicitly accept trusted unsandboxed demo plugin")
		f.BoolVar(&process, "require-process-sandbox", false, "require the Linux Landlock/seccomp process sandbox")
	case "archive":
		f.StringVar(&planID, "plan-id", "", "exact sealed transaction ID to archive")
	}
	if err := f.Parse(args[1:]); err != nil {
		return err
	}
	if *root == "" || f.NArg() != 0 {
		return fmt.Errorf("DOT_E_POLICY: explicit root required")
	}
	if (args[0] == "register" && plugin == "") || (args[0] == "archive" && planID == "") {
		return fmt.Errorf("DOT_E_POLICY: command requires an explicit plugin or plan ID")
	}
	if args[0] == "register" && assurance != protocol.AssuranceAudit && assurance != protocol.AssuranceProcess {
		return fmt.Errorf("DOT_E_POLICY: unsupported assurance")
	}
	if args[0] == "apply" && audit == process {
		return fmt.Errorf("DOT_E_POLICY: select exactly one assurance flag")
	}
	if args[0] == "init" {
		return transaction.Init(*root)
	}
	e, err := transaction.Open(*root)
	if err != nil {
		return err
	}
	defer e.Close()
	switch args[0] {
	case "register":
		return host.RegisterWithAssurance(e, plugin, assurance)
	case "apply":
		ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
		defer cancel()
		if process {
			return host.ApplyContained(ctx, e)
		}
		return host.Apply(ctx, e, audit)
	case "recover":
		return e.Recover(false)
	case "retry-effects":
		return e.ApplyEffects()
	case "archive":
		return e.Archive(planID)
	case "plan-id":
		id, err := e.PlanID()
		if err == nil {
			fmt.Println(id)
		}
		return err
	case "rollback":
		return e.Recover(true)
	case "status":
		state, err := e.Status()
		if err == nil {
			fmt.Println(state)
		}
		return err
	default:
		return fmt.Errorf("DOT_E_PROTOCOL: unknown command")
	}
}
func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
