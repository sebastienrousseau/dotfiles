// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"strconv"

	"dotfiles.local/core/protocol"
)

const maxEffectEntries = 256

type effectEntry struct {
	Index          int    `json:"index"`
	IdempotencyKey string `json:"idempotency_key"`
	State          string `json:"state"`
}

func effectKey(planID string, index int) string {
	return Digest([]byte(planID + ":commit:" + strconv.Itoa(index)))
}

func effectLedger(r *os.Root, sealed Sealed) ([]string, int, error) {
	states := make([]string, len(sealed.Plan.Effects))
	b, snapshot, err := read(r, "effects.wal")
	if err != nil || !snapshot.Exists {
		return states, 0, err
	}
	lines := bytes.Split(b, []byte{'\n'})
	complete := bytes.Count(b, []byte{'\n'})
	if complete > maxEffectEntries {
		return states, 0, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effect WAL entry limit")
	}
	for _, line := range lines[:complete] {
		var entry effectEntry
		if err = protocol.Strict(line, &entry); err != nil || entry.Index < 0 || entry.Index >= len(states) ||
			entry.IdempotencyKey != effectKey(sealed.ID, entry.Index) {
			return states, 0, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: corrupt effect WAL")
		}
		for i := 0; i < entry.Index; i++ {
			if states[i] != "SUCCEEDED" {
				return states, 0, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effect order")
			}
		}
		current := states[entry.Index]
		switch entry.State {
		case "ATTEMPTED":
			if current == "SUCCEEDED" {
				return states, 0, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effect after success")
			}
		case "FAILED", "SUCCEEDED":
			if current != "ATTEMPTED" {
				return states, 0, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effect result without attempt")
			}
		default:
			return states, 0, fmt.Errorf("DOT_E_RECOVERY_REQUIRED: unknown effect state")
		}
		states[entry.Index] = entry.State
	}
	return states, complete, nil
}

func recordEffect(r *os.Root, entry effectEntry) error {
	b, snapshot, err := read(r, "effects.wal")
	if err != nil {
		return err
	}
	if snapshot.Exists && len(b) > MaxFile-256 {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effect WAL limit")
	}
	if snapshot.Exists && len(b) > 0 && b[len(b)-1] != '\n' {
		f, err := r.OpenFile("effects.wal", os.O_WRONLY, 0)
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
	f, err := r.OpenFile("effects.wal", os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0600)
	if err != nil {
		return err
	}
	line, err := json.Marshal(entry)
	if err == nil {
		_, err = f.Write(append(line, '\n'))
	}
	if err == nil {
		err = f.Sync()
	}
	f.Close()
	if err != nil {
		return err
	}
	return syncDir(r)
}

func effectsState(r *os.Root, sealed Sealed) (string, error) {
	if len(sealed.Plan.Effects) == 0 {
		_, snapshot, err := read(r, "effects.wal")
		if err != nil {
			return "", err
		}
		if snapshot.Exists {
			return "", fmt.Errorf("DOT_E_RECOVERY_REQUIRED: unexpected effect WAL")
		}
		return "COMMITTED", nil
	}
	states, _, err := effectLedger(r, sealed)
	if err != nil {
		return "", err
	}
	for _, state := range states {
		if state != "SUCCEEDED" {
			if state == "" {
				return "POST_COMMIT_PENDING", nil
			}
			return "POST_COMMIT_FAILED", nil
		}
	}
	return "COMMITTED", nil
}

// ApplyEffects retries sealed, core-allowlisted effects. A retry reuses the same
// idempotency key. The only hello effect is a root directory sync; no command,
// plugin callback, path, PID, or user-controlled argument is executed.
func (e *Engine) ApplyEffects() error {
	r, err := e.txn()
	if err != nil {
		return err
	}
	defer r.Close()
	sealed, state, err := load(r)
	if err != nil {
		return err
	}
	if sealed.Plan.RootID != e.ID || state != "COMMITTED" {
		return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effects require committed matching plan")
	}
	states, entries, err := effectLedger(r, sealed)
	if err != nil {
		return err
	}
	for i, effect := range sealed.Plan.Effects {
		if states[i] == "SUCCEEDED" {
			continue
		}
		if entries+2 > maxEffectEntries {
			return fmt.Errorf("DOT_E_RECOVERY_REQUIRED: effect retry limit")
		}
		entry := effectEntry{Index: i, IdempotencyKey: effectKey(sealed.ID, i), State: "ATTEMPTED"}
		if err = recordEffect(r, entry); err != nil {
			return err
		}
		entries++
		if err = e.hit(fmt.Sprintf("effect-run-%d", i)); err == nil {
			switch effect {
			case Effect{Kind: "sync", Target: "managed-root", FailurePolicy: "required"}:
				err = syncDir(e.Root)
			default:
				err = fmt.Errorf("DOT_E_POLICY: unsupported effect")
			}
		}
		if err != nil {
			entry.State = "FAILED"
			if recordErr := recordEffect(r, entry); recordErr != nil {
				return recordErr
			}
			return fmt.Errorf("DOT_E_POST_COMMIT: effect %d failed: %w", i, err)
		}
		if err = e.hit(fmt.Sprintf("effect-executed-%d", i)); err != nil {
			return err
		}
		entry.State = "SUCCEEDED"
		if err = recordEffect(r, entry); err != nil {
			return err
		}
		entries++
		if err = e.hit(fmt.Sprintf("effect-succeeded-%d", i)); err != nil {
			return err
		}
	}
	return nil
}
