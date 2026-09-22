// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"dotfiles.local/core/protocol"
	"encoding/hex"
	"fmt"
	"io"
	"os"
)

func run() error {
	r := bufio.NewReaderSize(os.Stdin, 128)
	methods := []string{"dot.initialize", "dot.plan", "dot.materialize", "dot.validate", "dot.shutdown"}
	for step, method := range methods {
		m, err := protocol.Read(r)
		if err != nil {
			return err
		}
		if m.Method != method || m.ID != step+1 {
			return fmt.Errorf("DOT_E_PROTOCOL: lifecycle")
		}
		var result any
		switch method {
		case "dot.initialize":
			var p protocol.Initialize
			if err = protocol.Strict(m.Params, &p); err != nil {
				return err
			}
			if p.Protocol != 1 || len(p.Nonce) != 64 {
				return fmt.Errorf("DOT_E_PROTOCOL: negotiation")
			}
			result = protocol.Identity{Protocol: 1, Nonce: p.Nonce, ID: "org.dot.hello"}
		case "dot.plan":
			result = protocol.Proposal{Names: []string{"hello.txt", "welcome.txt"}}
		case "dot.materialize":
			var p protocol.Materialize
			if err = protocol.Strict(m.Params, &p); err != nil {
				return err
			}
			if p.Stage != os.Getenv("DOT_STAGE_ROOT") {
				return fmt.Errorf("DOT_E_POLICY: stage")
			}
			r, err := os.OpenRoot(p.Stage)
			if err != nil {
				return err
			}
			defer r.Close()
			out := protocol.Materialized{}
			for _, name := range []string{"hello.txt", "welcome.txt"} {
				b := []byte("Hello from an unprivileged calculation plugin.\n")
				f, err := r.OpenFile(name, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
				if err != nil {
					return err
				}
				if _, err = f.Write(b); err != nil {
					f.Close()
					return err
				}
				if err = f.Close(); err != nil {
					return err
				}
				sum := sha256.Sum256(b)
				out.Artifacts = append(out.Artifacts, protocol.Artifact{Name: name, SHA256: hex.EncodeToString(sum[:]), Size: len(b)})
			}
			result = out
		case "dot.validate":
			root, err := os.OpenRoot(os.Getenv("DOT_STAGE_ROOT"))
			if err != nil {
				return err
			}
			defer root.Close()
			for _, name := range []string{"hello.txt", "welcome.txt"} {
				f, err := root.Open(name)
				if err != nil {
					return err
				}
				data, err := io.ReadAll(io.LimitReader(f, 65537))
				f.Close()
				if err != nil || !bytes.Equal(data, []byte("Hello from an unprivileged calculation plugin.\n")) {
					return fmt.Errorf("DOT_E_VALIDATION: staged content changed")
				}
			}
			result = protocol.Validated{Valid: true}
		case "dot.shutdown":
			result = protocol.Validated{Valid: true}
		}
		if err = protocol.Write(os.Stdout, protocol.Message{JSONRPC: "2.0", ID: m.ID, Result: protocol.Value(result)}); err != nil {
			return err
		}
	}
	return nil
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
