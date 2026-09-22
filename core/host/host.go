// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

// Package host runs only explicitly registered, digest-pinned hello-profile plugins.
// Audit mode requires explicit consent. Process mode is a Linux-only experimental
// Landlock/seccomp boundary and fails closed when its enforcement is unavailable.
package host

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"os"
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
	Profile   string `json:"profile"`
	Assurance string `json:"assurance"`
}

func binary(path string) ([]byte, error) {
	f, b, err := openBinary(path)
	if f != nil {
		f.Close()
	}
	return b, err
}

func openBinary(path string) (*os.File, []byte, error) {
	i, err := os.Lstat(path)
	if err != nil {
		return nil, nil, err
	}
	if !i.Mode().IsRegular() || i.Size() > 16<<20 || i.Mode().Perm()&0022 != 0 {
		return nil, nil, fmt.Errorf("DOT_E_PLUGIN_IDENTITY: binary type/mode/size")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	opened, err := f.Stat()
	if err != nil || !os.SameFile(i, opened) || !opened.Mode().IsRegular() ||
		opened.Size() > 16<<20 || opened.Mode().Perm()&0022 != 0 {
		f.Close()
		return nil, nil, fmt.Errorf("DOT_E_PLUGIN_IDENTITY: executable changed")
	}
	b, err := io.ReadAll(io.LimitReader(f, (16<<20)+1))
	if err != nil {
		f.Close()
		return nil, nil, err
	}
	if len(b) > 16<<20 {
		f.Close()
		return nil, nil, fmt.Errorf("DOT_E_PLUGIN_IDENTITY: binary limit")
	}
	return f, b, nil
}

func Register(e *transaction.Engine, source string) error {
	return RegisterWithAssurance(e, source, protocol.AssuranceAudit)
}

func RegisterWithAssurance(e *transaction.Engine, source, assurance string) error {
	if assurance != protocol.AssuranceAudit && assurance != protocol.AssuranceProcess {
		return fmt.Errorf("DOT_E_POLICY: unsupported assurance")
	}
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
	m := Manifest{
		ID: "org.dot.hello", SHA256: transaction.Digest(b), Protocol: 1,
		Profile: protocol.HelloProfile, Assurance: assurance,
	}
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
	return apply(ctx, e, protocol.AssuranceAudit)
}

func ApplyContained(ctx context.Context, e *transaction.Engine) error {
	return apply(ctx, e, protocol.AssuranceProcess)
}

func apply(ctx context.Context, e *transaction.Engine, requiredAssurance string) error {
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
	if m.ID != "org.dot.hello" || m.Protocol != 1 || m.Profile != protocol.HelloProfile || m.Assurance != requiredAssurance {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: manifest policy")
	}
	path := filepath.Join(e.Root.Name(), ".dot-plugin")
	plugin, b, err := openBinary(path)
	if err != nil {
		return err
	}
	defer plugin.Close()
	if transaction.Digest(b) != m.SHA256 {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: digest")
	}
	if err = e.Root.Mkdir(".dot-stage", 0700); err != nil {
		return err
	}
	stage := filepath.Join(e.Root.Name(), ".dot-stage")
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	cmd, closeCommand, err := pluginCommand(ctx, plugin, stage, requiredAssurance)
	if err != nil {
		return err
	}
	defer closeCommand()
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
	initialize := protocol.Initialize{
		Protocol: 1, Profile: protocol.HelloProfile,
		RequiredAssurance: requiredAssurance,
		Capabilities:      append([]string(nil), protocol.HelloCapabilities...), Nonce: nonceText,
	}
	var identity protocol.Identity
	if err = call("dot.initialize", initialize, &identity); err != nil {
		return err
	}
	if err = validateIdentity(m, initialize, identity); err != nil {
		return err
	}
	var proposal protocol.Proposal
	if err = call("dot.plan", struct{}{}, &proposal); err != nil {
		return err
	}
	if len(proposal.Names) != 2 || proposal.Names[0] != "hello.txt" || proposal.Names[1] != "welcome.txt" {
		return fmt.Errorf("DOT_E_POLICY: hello allowlist")
	}
	if len(proposal.Effects) != 1 || proposal.Effects[0] != (protocol.Effect{Kind: "sync", Target: "managed-root", FailurePolicy: "required"}) {
		return fmt.Errorf("DOT_E_POLICY: hello effect allowlist")
	}
	p := transaction.Plan{Version: 1, RootID: e.ID, Nonce: nonceText, PluginDigest: m.SHA256}
	for _, name := range proposal.Names {
		before, err := e.Observe(name)
		if err != nil {
			return err
		}
		p.Operations = append(p.Operations, transaction.Operation{Name: name, Before: before})
	}
	for _, effect := range proposal.Effects {
		p.Effects = append(p.Effects, transaction.Effect{
			Kind: effect.Kind, Target: effect.Target, FailurePolicy: effect.FailurePolicy,
		})
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
	if err = e.Commit(); err != nil {
		return err
	}
	return e.ApplyEffects()
}

func validateIdentity(m Manifest, request protocol.Initialize, identity protocol.Identity) error {
	if identity.ID != m.ID || identity.Protocol != request.Protocol || identity.Profile != request.Profile ||
		identity.Assurance != request.RequiredAssurance || identity.Nonce != request.Nonce ||
		len(identity.Capabilities) != len(request.Capabilities) {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: handshake downgrade or mismatch")
	}
	for i := range request.Capabilities {
		if identity.Capabilities[i] != request.Capabilities[i] {
			return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: capability mismatch")
		}
	}
	return nil
}
