// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"dotfiles.local/core/protocol"
)

var namePattern = regexp.MustCompile(`^[a-z][a-z0-9-]{0,30}\.txt$`)
var hashPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)

type Engine struct {
	Root     *os.Root
	ID       string
	lockFile *os.File
	// Fault is a test-only injection point. The CLI never exposes it.
	Fault func(string) error
}

func Init(path string) error {
	if runtime.GOOS != "darwin" && runtime.GOOS != "linux" {
		return fmt.Errorf("DOT_E_POLICY: platform mutation driver unavailable")
	}
	if !filepath.IsAbs(path) {
		return fmt.Errorf("DOT_E_POLICY: absolute new directory required")
	}
	if err := os.Mkdir(path, 0700); err != nil {
		return err
	}
	r, err := os.OpenRoot(path)
	if err != nil {
		return err
	}
	defer r.Close()
	var nonce [32]byte
	if _, err = rand.Read(nonce[:]); err != nil {
		return err
	}
	if err = write(r, ".dot-root", []byte("dot-hello-profile-v1:"+hex.EncodeToString(nonce[:])+"\n"), 0600); err != nil {
		return err
	}
	if err = syncDir(r); err != nil {
		return err
	}
	p, err := os.Open(filepath.Dir(path))
	if err != nil {
		return err
	}
	defer p.Close()
	return p.Sync()
}

func Open(path string) (*Engine, error) {
	if !filepath.IsAbs(path) {
		return nil, fmt.Errorf("DOT_E_POLICY: absolute root required")
	}
	i, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !i.IsDir() {
		return nil, fmt.Errorf("DOT_E_POLICY: root must not be a symlink")
	}
	r, err := os.OpenRoot(path)
	if err != nil {
		return nil, err
	}
	f, err := r.Open(".")
	if err != nil {
		r.Close()
		return nil, err
	}
	err = privateDir(f)
	f.Close()
	if err != nil {
		r.Close()
		return nil, err
	}
	b, _, err := read(r, ".dot-root")
	id := strings.TrimSuffix(strings.TrimPrefix(string(b), "dot-hello-profile-v1:"), "\n")
	if err != nil || !strings.HasPrefix(string(b), "dot-hello-profile-v1:") || !hashPattern.MatchString(id) {
		r.Close()
		return nil, fmt.Errorf("DOT_E_POLICY: not an initialized demo root")
	}
	l, err := lock(r)
	if err != nil {
		r.Close()
		return nil, err
	}
	return &Engine{Root: r, ID: id, lockFile: l}, nil
}
func (e *Engine) Close() { e.lockFile.Close(); e.Root.Close() }
func (e *Engine) hit(point string) error {
	if e.Fault != nil {
		return e.Fault(point)
	}
	return nil
}
func (e *Engine) Observe(name string) (Snapshot, error) {
	if !namePattern.MatchString(name) {
		return Snapshot{}, fmt.Errorf("DOT_E_PATH_ESCAPE")
	}
	_, s, err := read(e.Root, name)
	return s, err
}
func ReadArtifact(root *os.Root, name string) ([]byte, Snapshot, error) {
	if !namePattern.MatchString(name) {
		return nil, Snapshot{}, fmt.Errorf("DOT_E_PATH_ESCAPE")
	}
	return read(root, name)
}

func syncDir(r *os.Root) error {
	f, err := r.Open(".")
	if err != nil {
		return err
	}
	defer f.Close()
	return f.Sync()
}
func write(r *os.Root, name string, b []byte, mode os.FileMode) error {
	f, err := r.OpenFile(name, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err = f.Write(b); err != nil {
		return err
	}
	if err = f.Chmod(mode); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	return f.Close()
}
func (e *Engine) txn() (*os.Root, error) {
	i, err := e.Root.Lstat(".dot-txn")
	if err != nil {
		return nil, err
	}
	if !i.IsDir() {
		return nil, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: transaction type")
	}
	r, err := e.Root.OpenRoot(".dot-txn")
	if err != nil {
		return nil, err
	}
	f, err := r.Open(".")
	if err != nil {
		r.Close()
		return nil, err
	}
	err = privateDir(f)
	f.Close()
	if err != nil {
		r.Close()
		return nil, err
	}
	return r, nil
}

func validate(p Plan) error {
	if !hashPattern.MatchString(p.RootID) {
		return fmt.Errorf("DOT_E_VALIDATION: root identity")
	}
	if p.Version != 1 || !hashPattern.MatchString(p.Nonce) || !hashPattern.MatchString(p.PluginDigest) || !hashPattern.MatchString(p.ProposalID) || len(p.Operations) < 1 || len(p.Operations) > 16 {
		return fmt.Errorf("DOT_E_VALIDATION: plan bounds")
	}
	seen := map[string]bool{}
	for _, o := range p.Operations {
		if !namePattern.MatchString(o.Name) || seen[o.Name] {
			return fmt.Errorf("DOT_E_PATH_ESCAPE: duplicate or invalid target")
		}
		seen[o.Name] = true
		if !o.After.Exists || o.After.Mode != 0600 || !hashPattern.MatchString(o.After.Digest) {
			return fmt.Errorf("DOT_E_VALIDATION: artifact policy")
		}
		if o.Before.Exists && (!hashPattern.MatchString(o.Before.Digest) || o.Before.Mode&0077 != 0) {
			return fmt.Errorf("DOT_E_VALIDATION: precondition")
		}
		if !o.Before.Exists && o.Before != (Snapshot{}) {
			return fmt.Errorf("DOT_E_VALIDATION: absent precondition")
		}
	}
	return nil
}

// Prepare persists sealed bytes and backups before a PREPARED record. No target changes.
func (e *Engine) Prepare(p Plan, artifacts [][]byte) (string, error) {
	if p.RootID != e.ID {
		return "", fmt.Errorf("DOT_E_POLICY: plan belongs to a different root")
	}
	if err := validate(p); err != nil {
		return "", err
	}
	if len(artifacts) != len(p.Operations) {
		return "", fmt.Errorf("DOT_E_ARTIFACT_MISMATCH")
	}
	for i, o := range p.Operations {
		if len(artifacts[i]) > MaxFile || Digest(artifacts[i]) != o.After.Digest {
			return "", fmt.Errorf("DOT_E_ARTIFACT_MISMATCH")
		}
	}
	if err := e.Root.Mkdir(".dot-txn", 0700); err != nil {
		return "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: transaction already exists or cannot be created: %w", err)
	}
	if err := syncDir(e.Root); err != nil {
		return "", err
	}
	r, err := e.txn()
	if err != nil {
		return "", err
	}
	defer r.Close()
	for i, o := range p.Operations {
		b, s, err := read(e.Root, o.Name)
		if err != nil {
			return "", err
		}
		if s != o.Before {
			return "", fmt.Errorf("DOT_E_CONFLICT: %s", o.Name)
		}
		if s.Exists {
			if err = write(r, fmt.Sprintf("backup-%d", i), b, os.FileMode(s.Mode)); err != nil {
				return "", err
			}
		}
		name := fmt.Sprintf("artifact-%d", i)
		if err = write(r, name, artifacts[i], 0600); err != nil {
			return "", err
		}
		_, actual, err := read(r, name)
		if err != nil {
			return "", err
		}
		if actual != o.After {
			return "", fmt.Errorf("DOT_E_ARTIFACT_MISMATCH: metadata")
		}
	}
	sealed, err := Seal(p)
	if err != nil {
		return "", err
	}
	b, err := json.Marshal(sealed)
	if err != nil {
		return "", err
	}
	if err = write(r, "plan.json", b, 0600); err != nil {
		return "", err
	}
	if err = syncDir(r); err != nil {
		return "", err
	}
	if err = e.record(r, "PREPARED"); err != nil {
		return "", err
	}
	return sealed.ID, e.hit("prepared")
}

func (e *Engine) record(r *os.Root, state string) error {
	// Transaction dir is private, core-owned, and no plugin remains alive here.
	b, _, err := read(r, "wal")
	if err != nil {
		return err
	}
	if len(b) > MaxFile-128 {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: WAL limit")
	}
	if len(b) > 0 && b[len(b)-1] != '\n' {
		f, err := r.OpenFile("wal", os.O_WRONLY, 0)
		if err != nil {
			return err
		}
		err = f.Truncate(int64(bytes.LastIndexByte(b, '\n') + 1))
		if err == nil {
			err = f.Sync()
		}
		f.Close()
		if err != nil {
			return err
		}
	}
	f, err := r.OpenFile("wal", os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	b, _ = json.Marshal(struct {
		State string `json:"state"`
	}{state})
	b = append(b, '\n')
	if _, err = f.Write(b); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	return syncDir(r)
}

func load(r *os.Root) (Sealed, string, error) {
	var s Sealed
	b, _, err := read(r, "plan.json")
	if err != nil {
		return s, "", err
	}
	if err = protocol.Strict(b, &s); err != nil {
		return s, "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: invalid sealed plan")
	}
	if err = validate(s.Plan); err != nil {
		return s, "", err
	}
	want, err := Seal(s.Plan)
	if err != nil || want.ID != s.ID {
		return s, "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: plan seal mismatch")
	}
	b, _, err = read(r, "wal")
	if err != nil {
		return s, "", err
	}
	state := ""
	edges := map[string]string{"": "PREPARED", "PREPARED": "COMMITTING|ROLLING_BACK", "COMMITTING": "COMMITTED|ROLLING_BACK", "COMMITTED": "ROLLING_BACK", "ROLLING_BACK": "ROLLING_BACK|ROLLED_BACK", "ROLLED_BACK": ""}
	for _, line := range bytes.Split(b, []byte{'\n'})[:bytes.Count(b, []byte{'\n'})] {
		var entry struct {
			State string `json:"state"`
		}
		if err = protocol.Strict(line, &entry); err != nil {
			return s, "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: corrupt WAL")
		}
		valid := false
		for _, next := range strings.Split(edges[state], "|") {
			if next != "" && next == entry.State {
				valid = true
			}
		}
		if !valid {
			return s, "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: illegal transition")
		}
		state = entry.State
	}
	if state == "" {
		return s, "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: no durable prepare")
	}
	return s, state, nil
}

func (e *Engine) Commit() error {
	r, err := e.txn()
	if err != nil {
		return err
	}
	defer r.Close()
	s, state, err := load(r)
	if err != nil {
		return err
	}
	if s.Plan.RootID != e.ID {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: root identity mismatch")
	}
	if state != "PREPARED" {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: expected PREPARED, got %s", state)
	}
	for _, o := range s.Plan.Operations {
		now, err := e.Observe(o.Name)
		if err != nil {
			return err
		}
		if now != o.Before {
			return fmt.Errorf("DOT_E_CONFLICT: %s", o.Name)
		}
	}
	if err = e.record(r, "COMMITTING"); err != nil {
		return err
	}
	if err = e.hit("committing"); err != nil {
		return err
	}
	for i, o := range s.Plan.Operations {
		b, after, err := read(r, fmt.Sprintf("artifact-%d", i))
		if err != nil {
			return err
		}
		if after != o.After {
			return fmt.Errorf("DOT_E_ARTIFACT_MISMATCH")
		}
		if err = e.replace(o.Name, b, o.Before, o.After.Mode, i); err != nil {
			return err
		}
		if err = e.hit(fmt.Sprintf("renamed-%d", i)); err != nil {
			return err
		}
	}
	if err = e.record(r, "COMMITTED"); err != nil {
		return err
	}
	return e.hit("committed")
}

func (e *Engine) replace(name string, b []byte, before Snapshot, mode uint32, index int) error {
	tmp := fmt.Sprintf(".dot-next-%d", index)
	// Recovery can encounter this name after a crash before rename. It is core-owned.
	if _, s, err := read(e.Root, tmp); err != nil {
		return err
	} else if s.Exists {
		if err = e.Root.Remove(tmp); err != nil {
			return err
		}
	}
	if err := write(e.Root, tmp, b, os.FileMode(mode)); err != nil {
		return err
	}
	if err := e.hit(fmt.Sprintf("flushed-%d", index)); err != nil {
		return err
	}
	now, err := e.Observe(name)
	if err != nil {
		return err
	}
	if now != before {
		return fmt.Errorf("DOT_E_CONFLICT: %s", name)
	}
	if err = e.Root.Rename(tmp, name); err != nil {
		return fmt.Errorf("DOT_E_COMMIT: %w", err)
	}
	return syncDir(e.Root)
}

// Recover always rolls an incomplete commit back; it never depends on a plugin.
// A third-party edit blocks recovery instead of being overwritten.
func (e *Engine) Recover(explicitRollback bool) error {
	r, err := e.txn()
	if err != nil {
		return err
	}
	defer r.Close()
	s, state, err := load(r)
	if err != nil {
		return err
	}
	if s.Plan.RootID != e.ID {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: root identity mismatch")
	}
	if state == "ROLLED_BACK" {
		return nil
	}
	if state == "COMMITTED" && !explicitRollback {
		return nil
	}
	if state != "ROLLING_BACK" {
		if err = e.record(r, "ROLLING_BACK"); err != nil {
			return err
		}
	}
	for i := len(s.Plan.Operations) - 1; i >= 0; i-- {
		o := s.Plan.Operations[i]
		now, err := e.Observe(o.Name)
		if err != nil {
			return err
		}
		if now == o.Before {
			continue
		}
		if now != o.After {
			return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: concurrent edit to %s; preserve evidence", o.Name)
		}
		if o.Before.Exists {
			b, before, err := read(r, fmt.Sprintf("backup-%d", i))
			if err != nil {
				return err
			}
			if before != o.Before {
				return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: backup mismatch")
			}
			if err = e.replace(o.Name, b, now, o.Before.Mode, i); err != nil {
				return err
			}
		} else {
			if err = e.Root.Remove(o.Name); err != nil {
				return err
			}
			if err = syncDir(e.Root); err != nil {
				return err
			}
		}
		if err = e.hit(fmt.Sprintf("restored-%d", i)); err != nil {
			return err
		}
	}
	return e.record(r, "ROLLED_BACK")
}

func (e *Engine) Status() (string, error) {
	r, err := e.txn()
	if err != nil {
		return "", err
	}
	defer r.Close()
	s, state, err := load(r)
	if err == nil && s.Plan.RootID != e.ID {
		return "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: root identity mismatch")
	}
	return state, err
}

// ReadState is intentionally a value-only observation helper, not an MCP transport.
func ReadState(path string) (string, error) {
	e, err := Open(path)
	if err != nil {
		return "", err
	}
	defer e.Close()
	return e.Status()
}
