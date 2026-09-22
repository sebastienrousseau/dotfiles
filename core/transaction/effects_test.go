//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func committedEffectFixture(t *testing.T) (*Engine, string) {
	t.Helper()
	e, plan, artifacts := setup(t)
	plan.Effects = []Effect{{Kind: "sync", Target: "managed-root", FailurePolicy: "required"}}
	id, err := e.Prepare(plan, artifacts)
	if err != nil {
		t.Fatal(err)
	}
	if err = e.Commit(); err != nil {
		t.Fatal(err)
	}
	return e, id
}

func TestEffectsRetryAndArchiveGate(t *testing.T) {
	e, id := committedEffectFixture(t)
	if state, err := e.Status(); err != nil || state != "POST_COMMIT_PENDING" {
		t.Fatal(state, err)
	}
	if err := e.Archive(id); err == nil {
		t.Fatal("archived before required effect completed")
	}
	e.Fault = func(point string) error {
		if point == "effect-run-0" {
			return errors.New("reload unavailable")
		}
		return nil
	}
	if err := e.ApplyEffects(); err == nil {
		t.Fatal("required effect failure ignored")
	}
	if state, err := e.Status(); err != nil || state != "POST_COMMIT_FAILED" {
		t.Fatal(state, err)
	}
	e.Fault = nil
	if err := e.ApplyEffects(); err != nil {
		t.Fatal(err)
	}
	r, err := e.txn()
	if err != nil {
		t.Fatal(err)
	}
	sealed, _, err := load(r)
	if err != nil {
		t.Fatal(err)
	}
	states, entries, err := effectLedger(r, sealed)
	ledger, _, readErr := read(r, "effects.wal")
	r.Close()
	if err != nil || readErr != nil || entries != 4 || len(states) != 1 || states[0] != "SUCCEEDED" {
		t.Fatal(states, entries, err, readErr)
	}
	for _, line := range bytes.Split(bytes.TrimSpace(ledger), []byte{'\n'}) {
		var entry effectEntry
		if err = json.Unmarshal(line, &entry); err != nil || entry.IdempotencyKey != effectKey(id, 0) {
			t.Fatal("effect retry did not retain its idempotency key", entry, err)
		}
	}
	if err = e.ApplyEffects(); err != nil {
		t.Fatal("completed effect not idempotent", err)
	}
	r, _ = e.txn()
	_, entriesAfter, err := effectLedger(r, sealed)
	r.Close()
	if err != nil || entriesAfter != entries {
		t.Fatal("idempotent retry appended effect records", entriesAfter, err)
	}
	if err = e.Archive(id); err != nil {
		t.Fatal(err)
	}
}

func TestEffectCrashAfterExecutionRecovers(t *testing.T) {
	e, _ := committedEffectFixture(t)
	e.Fault = func(point string) error {
		if point == "effect-executed-0" {
			return errors.New("crash after external effect")
		}
		return nil
	}
	if err := e.ApplyEffects(); err == nil {
		t.Fatal("fault not reached")
	}
	if state, err := e.Status(); err != nil || state != "POST_COMMIT_FAILED" {
		t.Fatal(state, err)
	}
	root := e.Root.Name()
	e.Close()
	reopened, err := Open(root)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	if err = reopened.Recover(false); err != nil {
		t.Fatal(err)
	}
	if state, err := reopened.Status(); err != nil || state != "COMMITTED" {
		t.Fatal(state, err)
	}
}

func TestEffectCrashAfterDurableSuccessIsComplete(t *testing.T) {
	e, _ := committedEffectFixture(t)
	e.Fault = func(point string) error {
		if point == "effect-succeeded-0" {
			return errors.New("crash after durable result")
		}
		return nil
	}
	if err := e.ApplyEffects(); err == nil {
		t.Fatal("fault not reached")
	}
	if state, err := e.Status(); err != nil || state != "COMMITTED" {
		t.Fatal(state, err)
	}
	e.Fault = nil
	if err := e.ApplyEffects(); err != nil {
		t.Fatal("durably completed effect was rerun", err)
	}
}

func TestEffectPolicyAndLedgerTamper(t *testing.T) {
	for _, kind := range []string{"kind", "target", "failure-policy", "extra", "bad-key", "result-without-attempt", "unexpected-ledger"} {
		t.Run(kind, func(t *testing.T) {
			if kind == "kind" || kind == "target" || kind == "failure-policy" || kind == "extra" {
				e, plan, artifacts := setup(t)
				effect := Effect{Kind: "sync", Target: "managed-root", FailurePolicy: "required"}
				switch kind {
				case "kind":
					effect.Kind = "shell"
				case "target":
					effect.Target = "/tmp"
				case "failure-policy":
					effect.FailurePolicy = "ignore"
				case "extra":
					plan.Effects = make([]Effect, 5)
				}
				if kind != "extra" {
					plan.Effects = []Effect{effect}
				}
				if _, err := e.Prepare(plan, artifacts); err == nil {
					t.Fatal("unsafe effect accepted")
				}
				return
			}
			if kind == "unexpected-ledger" {
				e, plan, artifacts := setup(t)
				id, err := e.Prepare(plan, artifacts)
				if err != nil {
					t.Fatal(id, err)
				}
				if err = e.Commit(); err != nil {
					t.Fatal(err)
				}
				if err = recordEffect(mustTxn(t, e), effectEntry{Index: 0, IdempotencyKey: effectKey(id, 0), State: "ATTEMPTED"}); err != nil {
					t.Fatal(err)
				}
				if _, err = e.Status(); err == nil {
					t.Fatal("unexpected effect ledger accepted")
				}
				return
			}
			e, id := committedEffectFixture(t)
			entry := effectEntry{Index: 0, IdempotencyKey: effectKey(id, 0), State: "ATTEMPTED"}
			if kind == "bad-key" {
				entry.IdempotencyKey = Digest([]byte("wrong"))
			} else {
				entry.State = "SUCCEEDED"
			}
			if err := recordEffect(mustTxn(t, e), entry); err != nil {
				t.Fatal(err)
			}
			if _, err := e.Status(); err == nil {
				t.Fatal("tampered effect ledger accepted")
			}
			if _, err := os.Stat(filepath.Join(e.Root.Name(), "hello.txt")); err != nil {
				t.Fatal("committed target lost", err)
			}
		})
	}
}

func mustTxn(t *testing.T, e *Engine) *os.Root {
	t.Helper()
	r, err := e.txn()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r
}
