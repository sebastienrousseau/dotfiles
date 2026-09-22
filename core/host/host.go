// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

// Package host runs only explicitly registered, digest-pinned hello-profile plugins.
// Its process boundary is AUDIT ONLY; the caller must explicitly accept that policy.
package host

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"dotfiles.local/core/protocol"
	"dotfiles.local/core/transaction"
)

type Manifest struct {
	ID        string `json:"id"`
	SHA256    string `json:"sha256"`
	Protocol  int    `json:"protocol"`
	Assurance string `json:"assurance"`
}

func binary(path string) ([]byte, error) {
	i, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !i.Mode().IsRegular() || i.Size() > 16<<20 || i.Mode().Perm()&0022 != 0 {
		return nil, fmt.Errorf("DOT_E_PLUGIN_IDENTITY: binary type/mode/size")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	opened, err := f.Stat()
	if err != nil || !os.SameFile(i, opened) {
		return nil, fmt.Errorf("DOT_E_PLUGIN_IDENTITY: executable changed")
	}
	b, err := io.ReadAll(io.LimitReader(f, (16<<20)+1))
	if len(b) > 16<<20 {
		return nil, fmt.Errorf("DOT_E_PLUGIN_IDENTITY: binary limit")
	}
	return b, err
}

func Register(e *transaction.Engine, source string) error {
	if !filepath.IsAbs(source) {
		return fmt.Errorf("DOT_E_POLICY: absolute executable required")
	}
	b, err := binary(source)
	if err != nil {
		return err
	}
	f, err := e.Root.OpenFile(".dot-plugin", os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0500)
	if err != nil {
		return err
	}
	if _, err = f.Write(b); err == nil {
		err = f.Sync()
	}
	f.Close()
	if err != nil {
		return err
	}
	m := Manifest{"org.dot.hello", transaction.Digest(b), 1, "audit"}
	f, err = e.Root.OpenFile(".dot-plugin.json", os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	if _, err = f.Write(protocol.Value(m)); err == nil {
		err = f.Sync()
	}
	f.Close()
	if err != nil {
		return err
	}
	d, err := e.Root.Open(".")
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

type boundedLog struct {
	mu       sync.Mutex
	n        int
	overflow bool
}

func (l *boundedLog) Write(b []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.n += len(b)
	if l.n > 8192 {
		l.overflow = true
		return 0, fmt.Errorf("DOT_E_PROTOCOL: stderr limit")
	}
	return len(b), nil
}

func Apply(ctx context.Context, e *transaction.Engine, allowAudit bool) error {
	if !allowAudit {
		return fmt.Errorf("DOT_E_POLICY: explicit --allow-audit-plugin required; no OS sandbox")
	}
	if err := e.Ready(); err != nil {
		return err
	}
	info, err := e.Root.Lstat(".dot-plugin.json")
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() || info.Mode().Perm() != 0600 || info.Size() > protocol.MaxFrame {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: manifest file")
	}
	mf, err := e.Root.Open(".dot-plugin.json")
	if err != nil {
		return err
	}
	metadata, err := io.ReadAll(io.LimitReader(mf, protocol.MaxFrame+1))
	mf.Close()
	if err != nil {
		return err
	}
	var m Manifest
	if err = protocol.Strict(metadata, &m); err != nil {
		return err
	}
	if m.ID != "org.dot.hello" || m.Protocol != 1 || m.Assurance != "audit" {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: manifest policy")
	}
	path := filepath.Join(e.Root.Name(), ".dot-plugin")
	b, err := binary(path)
	if err != nil {
		return err
	}
	if transaction.Digest(b) != m.SHA256 {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: digest")
	}
	if err = e.Root.Mkdir(".dot-stage", 0700); err != nil {
		return err
	}
	stage := filepath.Join(e.Root.Name(), ".dot-stage")
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, path)
	stopGroup, err := configureProcess(cmd)
	if err != nil {
		return err
	}
	cmd.Dir = stage
	cmd.Env = []string{"LANG=C", "DOT_STAGE_ROOT=" + stage}
	cmd.WaitDelay = time.Second
	var log boundedLog
	cmd.Stderr = &log
	in, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err = cmd.Start(); err != nil {
		return err
	}
	// A descendant holding stdout must not defeat the parent's deadline.
	go func() { <-ctx.Done(); in.Close(); out.Close() }()
	stopped := false
	defer func() {
		in.Close()
		if !stopped {
			cancel()
			stopGroup()
			cmd.Wait()
		}
	}()
	r := bufio.NewReaderSize(io.LimitReader(out, 8*protocol.MaxFrame), 128)
	requestID := 0
	call := func(method string, params any, result any) error {
		requestID++
		if err := protocol.Write(in, protocol.Message{JSONRPC: "2.0", ID: requestID, Method: method, Params: protocol.Value(params)}); err != nil {
			return err
		}
		response, err := protocol.Read(r)
		if err != nil {
			return err
		}
		if response.ID != requestID || response.Method != "" || len(response.Params) != 0 || len(response.Result) == 0 {
			return fmt.Errorf("DOT_E_PROTOCOL: response correlation")
		}
		return protocol.Strict(response.Result, result)
	}
	var nonce [32]byte
	if _, err = rand.Read(nonce[:]); err != nil {
		return err
	}
	nonceText := hex.EncodeToString(nonce[:])
	var identity protocol.Identity
	if err = call("dot.initialize", protocol.Initialize{Protocol: 1, Nonce: nonceText}, &identity); err != nil {
		return err
	}
	if identity.ID != m.ID || identity.Protocol != 1 || identity.Nonce != nonceText {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: handshake")
	}
	var proposal protocol.Proposal
	if err = call("dot.plan", struct{}{}, &proposal); err != nil {
		return err
	}
	if len(proposal.Names) != 2 || proposal.Names[0] != "hello.txt" || proposal.Names[1] != "welcome.txt" {
		return fmt.Errorf("DOT_E_POLICY: hello allowlist")
	}
	p := transaction.Plan{Version: 1, RootID: e.ID, Nonce: nonceText, PluginDigest: m.SHA256}
	for _, name := range proposal.Names {
		before, err := e.Observe(name)
		if err != nil {
			return err
		}
		p.Operations = append(p.Operations, transaction.Operation{Name: name, Before: before})
	}
	proposalBytes, err := transaction.Canonical(p)
	if err != nil {
		return err
	}
	p.ProposalID = transaction.Digest(proposalBytes)
	var materialized protocol.Materialized
	if err = call("dot.materialize", protocol.Materialize{Stage: stage}, &materialized); err != nil {
		return err
	}
	var validated protocol.Validated
	if err = call("dot.validate", struct{}{}, &validated); err != nil {
		return err
	}
	if !validated.Valid {
		return fmt.Errorf("DOT_E_VALIDATION: plugin rejected stage")
	}
	if err = call("dot.shutdown", struct{}{}, &validated); err != nil {
		return err
	}
	in.Close()
	_, err = r.ReadByte()
	if err != io.EOF {
		return fmt.Errorf("DOT_E_PROTOCOL: trailing stdout")
	}
	// Kill the group before reaping its leader, so its PID cannot be reused
	// between Wait and a later group signal. This also cleans up background
	// children that closed their protocol descriptors before the leader exited.
	if err = stopGroup(); err != nil {
		return fmt.Errorf("DOT_E_POLICY: plugin group cleanup failed: %w", err)
	}
	err = cmd.Wait()
	stopped = true
	if err != nil {
		return fmt.Errorf("DOT_E_PROTOCOL: plugin failed")
	}
	if log.overflow {
		return fmt.Errorf("DOT_E_PROTOCOL: stderr budget")
	}
	if len(materialized.Artifacts) != len(p.Operations) {
		return fmt.Errorf("DOT_E_ARTIFACT_MISMATCH: count")
	}
	stageInfo, err := e.Root.Lstat(".dot-stage")
	if err != nil {
		return err
	}
	if !stageInfo.IsDir() || stageInfo.Mode().Perm() != 0700 {
		return fmt.Errorf("DOT_E_PATH_ESCAPE: stage replaced")
	}
	sr, err := e.Root.OpenRoot(".dot-stage")
	if err != nil {
		return err
	}
	defer sr.Close()
	artifacts := [][]byte{}
	for i, a := range materialized.Artifacts {
		if a.Name != p.Operations[i].Name || a.Size < 1 || a.Size > transaction.MaxFile {
			return fmt.Errorf("DOT_E_ARTIFACT_MISMATCH: slots")
		}
		data, s, err := transaction.ReadArtifact(sr, a.Name)
		if err != nil {
			return err
		}
		if s.Digest != a.SHA256 || len(data) != a.Size || s.Mode != 0600 {
			return fmt.Errorf("DOT_E_ARTIFACT_MISMATCH: sealed bytes")
		}
		p.Operations[i].After = s
		artifacts = append(artifacts, data)
	}
	if err = ctx.Err(); err != nil {
		return fmt.Errorf("DOT_E_TIMEOUT: before transaction prepare: %w", err)
	}
	if _, err = e.Prepare(p, artifacts); err != nil {
		return err
	}
	if err = ctx.Err(); err != nil {
		return fmt.Errorf("DOT_E_TIMEOUT: before transaction commit; recover retained prepared evidence: %w", err)
	}
	return e.Commit()
}
