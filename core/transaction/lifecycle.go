// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	"dotfiles.local/core/protocol"
)

// MaxHistory bounds retained generations. This prototype never deletes evidence.
const MaxHistory = 32

type discardDirectory struct {
	name    string
	root    *os.Root
	entries []string
}

type archiveIntent struct {
	PlanID string `json:"plan_id"`
	Stage  bool   `json:"stage"`
}

func privateRoot(parent *os.Root, name string) (*os.Root, error) {
	i, err := parent.Lstat(name)
	if err != nil {
		return nil, err
	}
	if !i.IsDir() {
		return nil, fmt.Errorf("DOT_E_POLICY: expected private directory")
	}
	r, err := parent.OpenRoot(name)
	if err != nil {
		return nil, err
	}
	f, err := r.Open(".")
	if err == nil {
		err = privateDir(f)
		f.Close()
	}
	if err != nil {
		r.Close()
		return nil, err
	}
	return r, nil
}

func entries(r *os.Root, limit int) ([]os.DirEntry, error) {
	f, err := r.Open(".")
	if err != nil {
		return nil, err
	}
	defer f.Close()
	names, err := f.ReadDir(limit + 1)
	if err != nil && err != io.EOF {
		return nil, err
	}
	if len(names) > limit {
		return nil, fmt.Errorf("DOT_E_POLICY: directory entry limit")
	}
	return names, nil
}

func (e *Engine) archiveIntent() (archiveIntent, bool, error) {
	var intent archiveIntent
	b, s, err := read(e.Root, ".dot-archive")
	if err != nil || !s.Exists {
		return intent, s.Exists, err
	}
	if err = protocol.Strict(b, &intent); err != nil || !hashPattern.MatchString(intent.PlanID) {
		return intent, true, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: invalid archive intent")
	}
	return intent, true, nil
}

// Ready never silently advances or discards a previous operation.
func (e *Engine) Ready() error {
	if _, pending, err := e.archiveIntent(); err != nil {
		return err
	} else if pending {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: recover interrupted archive first")
	}
	for _, name := range []string{".dot-txn", ".dot-stage"} {
		if _, err := e.Root.Lstat(name); !os.IsNotExist(err) {
			return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: retain/recover/archive prior operation; use discard-abandoned only before durable PREPARED")
		}
	}
	return nil
}

func durablePrepare(r *os.Root) (bool, error) {
	b, state, err := read(r, "wal")
	if err != nil || !state.Exists {
		return false, err
	}
	end := bytes.IndexByte(b, '\n')
	if end < 0 {
		// record writes are durable only after the complete newline-terminated
		// entry is fsynced. A partial first entry cannot authorize target writes.
		return false, nil
	}
	var entry struct {
		State string `json:"state"`
	}
	if err = protocol.Strict(b[:end], &entry); err != nil || entry.State != "PREPARED" {
		return false, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: preserve unrecognized transaction journal")
	}
	return true, nil
}

func discardEntry(kind, name string) bool {
	if kind == "stage" {
		return namePattern.MatchString(name)
	}
	if name == "plan.json" || name == "wal" {
		return true
	}
	for _, prefix := range []string{"artifact-", "backup-"} {
		if strings.HasPrefix(name, prefix) {
			n, err := strconv.Atoi(strings.TrimPrefix(name, prefix))
			return err == nil && n >= 0 && n < 16
		}
	}
	return false
}

func inspectDiscardDirectory(parent *os.Root, name, kind string, limit int) (*discardDirectory, error) {
	r, err := privateRoot(parent, name)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	names, err := entries(r, limit)
	if err != nil {
		r.Close()
		return nil, err
	}
	d := &discardDirectory{name: name, root: r}
	for _, entry := range names {
		if entry.IsDir() || !discardEntry(kind, entry.Name()) {
			r.Close()
			return nil, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: preserve unexpected abandoned %s entry", kind)
		}
		_, state, err := read(r, entry.Name())
		if err != nil || !state.Exists {
			r.Close()
			return nil, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: preserve unsafe abandoned %s entry", kind)
		}
		d.entries = append(d.entries, entry.Name())
	}
	return d, nil
}

func (e *Engine) discardDirectory(d *discardDirectory, point string) error {
	if d == nil {
		return nil
	}
	for _, name := range d.entries {
		if err := d.root.Remove(name); err != nil {
			d.root.Close()
			return err
		}
	}
	if err := syncDir(d.root); err != nil {
		d.root.Close()
		return err
	}
	if err := d.root.Close(); err != nil {
		return err
	}
	if err := e.hit(point + "-entries"); err != nil {
		return err
	}
	if err := e.Root.Remove(d.name); err != nil {
		return err
	}
	if err := syncDir(e.Root); err != nil {
		return err
	}
	return e.hit(point)
}

// DiscardAbandoned removes only bounded, core-owned staging and transaction
// artifacts that cannot have reached durable PREPARED. It never changes a
// managed target and refuses recognized recovery evidence or unknown entries.
func (e *Engine) DiscardAbandoned() error {
	if _, pending, err := e.archiveIntent(); err != nil {
		return err
	} else if pending {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: finish interrupted archive first")
	}
	txn, err := inspectDiscardDirectory(e.Root, ".dot-txn", "transaction", 34)
	if err != nil {
		return err
	}
	if txn != nil {
		prepared, err := durablePrepare(txn.root)
		if err != nil {
			txn.root.Close()
			return err
		}
		if prepared {
			txn.root.Close()
			return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: transaction reached durable PREPARED; use recover")
		}
	}
	stage, err := inspectDiscardDirectory(e.Root, ".dot-stage", "stage", 16)
	if err != nil {
		if txn != nil {
			txn.root.Close()
		}
		return err
	}
	if err = e.discardDirectory(stage, "discard-stage"); err != nil {
		if txn != nil {
			txn.root.Close()
		}
		return err
	}
	return e.discardDirectory(txn, "discard-transaction")
}

func (e *Engine) terminal(r *os.Root, id string, targets bool) (Sealed, error) {
	s, state, err := load(r)
	if err != nil {
		return s, err
	}
	if s.ID != id || s.Plan.RootID != e.ID || (state != "COMMITTED" && state != "ROLLED_BACK") {
		return s, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: archive requires matching terminal plan")
	}
	effectState, err := effectsState(r, s)
	if err != nil {
		return s, err
	}
	if state == "COMMITTED" && effectState != "COMMITTED" {
		return s, fmt.Errorf("DOT_E_POST_COMMIT: complete required effects before archive")
	}
	for i, o := range s.Plan.Operations {
		_, a, err := read(r, fmt.Sprintf("artifact-%d", i))
		if err != nil || a != o.After {
			return s, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: artifact evidence mismatch")
		}
		_, b, err := read(r, fmt.Sprintf("backup-%d", i))
		if err != nil || b != o.Before {
			return s, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: backup evidence mismatch")
		}
		if targets {
			want := o.After
			if state == "ROLLED_BACK" {
				want = o.Before
			}
			now, err := e.Observe(o.Name)
			if err != nil || now != want {
				return s, fmt.Errorf("DOT_E_CONFLICT: changed target; retain transaction")
			}
		}
	}
	return s, nil
}

func checkStage(parent *os.Root, name string, p Plan) (bool, error) {
	r, err := privateRoot(parent, name)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	defer r.Close()
	names, err := entries(r, len(p.Operations))
	if err != nil || len(names) != len(p.Operations) {
		return true, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: unexpected stage entries")
	}
	for _, o := range p.Operations {
		_, s, err := read(r, o.Name)
		if err != nil || s != o.After {
			return true, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: changed stage evidence")
		}
	}
	return true, nil
}

// Archive retains a terminal transaction by sealed ID. A durable intent covers
// the two renames; Recover resumes it. No target or backup content is deleted.
func (e *Engine) Archive(id string) error {
	if !hashPattern.MatchString(id) {
		return fmt.Errorf("DOT_E_POLICY: exact --plan-id required")
	}
	intent, pending, err := e.archiveIntent()
	if err != nil {
		return err
	}
	if pending && intent.PlanID != id {
		return fmt.Errorf("DOT_E_CONFLICT: different archive in progress")
	}
	if err = e.Root.Mkdir(".dot-history", 0700); err != nil && !os.IsExist(err) {
		return err
	}
	h, err := privateRoot(e.Root, ".dot-history")
	if err != nil {
		return err
	}
	defer h.Close()
	names, err := entries(h, MaxHistory)
	if err != nil {
		return err
	}
	for _, name := range names {
		if !name.IsDir() || !hashPattern.MatchString(name.Name()) {
			return fmt.Errorf("DOT_E_POLICY: unexpected history entry")
		}
	}
	r, err := e.txn()
	if os.IsNotExist(err) {
		// Either the rename completed before a crash or this is an idempotent retry.
		r, err = privateRoot(h, id)
		if err != nil {
			return err
		}
		defer r.Close()
		s, err := e.terminal(r, id, pending)
		if err != nil {
			return err
		}
		stage, err := checkStage(r, "stage", s.Plan)
		if err != nil || (pending && stage != intent.Stage) {
			return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: archived stage mismatch")
		}
		if pending {
			if _, err := e.Root.Lstat(".dot-stage"); !os.IsNotExist(err) {
				return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: unexpected stage after archive rename")
			}
			return e.finishArchive(h)
		}
		return nil
	}
	if err != nil {
		return err
	}
	defer r.Close()
	s, err := e.terminal(r, id, true)
	if err != nil {
		return err
	}
	if _, err = h.Lstat(id); !os.IsNotExist(err) {
		return fmt.Errorf("DOT_E_CONFLICT: archive destination exists")
	}
	if len(names) >= MaxHistory {
		return fmt.Errorf("DOT_E_POLICY: history full; retain evidence, no automatic pruning")
	}
	stage, err := checkStage(e.Root, ".dot-stage", s.Plan)
	if err != nil {
		return err
	}
	retained, err := checkStage(r, "stage", s.Plan)
	if err != nil {
		return err
	}
	if (!pending && retained) || (pending && (intent.Stage != (stage || retained) || (stage && retained))) {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: ambiguous stage state")
	}
	if !pending {
		intent = archiveIntent{PlanID: id, Stage: stage}
		if err = write(e.Root, ".dot-archive", protocol.Value(intent), 0600); err != nil {
			return err
		}
		if err = syncDir(e.Root); err != nil {
			return err
		}
		if err = e.hit("archive-intent"); err != nil {
			return err
		}
	}
	if stage {
		if err = e.Root.Rename(".dot-stage", ".dot-txn/stage"); err != nil {
			return err
		}
	}
	if err = syncDir(r); err != nil {
		return err
	}
	if err = syncDir(e.Root); err != nil {
		return err
	}
	if err = e.hit("archive-stage"); err != nil {
		return err
	}
	if err = e.Root.Rename(".dot-txn", ".dot-history/"+id); err != nil {
		return err
	}
	if err = e.hit("archive-rename"); err != nil {
		return err
	}
	return e.finishArchive(h)
}

func (e *Engine) finishArchive(history *os.Root) error {
	if err := syncDir(history); err != nil {
		return err
	}
	if err := syncDir(e.Root); err != nil {
		return err
	}
	if err := e.hit("archive-durable"); err != nil {
		return err
	}
	if err := e.Root.Remove(".dot-archive"); err != nil {
		return err
	}
	if err := syncDir(e.Root); err != nil {
		return err
	}
	return e.hit("archive-finished")
}

func (e *Engine) PlanID() (string, error) {
	r, err := e.txn()
	if err != nil {
		return "", err
	}
	defer r.Close()
	s, _, err := load(r)
	if err == nil && s.Plan.RootID != e.ID {
		return "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: root identity mismatch")
	}
	return s.ID, err
}
