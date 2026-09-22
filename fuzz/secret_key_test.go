// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// FuzzSecretKey ports the key-name gates of scripts/lib/secrets_provider.sh:
//
//	dot_secrets_valid_key      ^[A-Za-z0-9_][A-Za-z0-9_.-]*$
//	    (keys become "<store>/<key>.age" and keychain service names)
//	dot_secrets_valid_env_key  ^[A-Za-z_][A-Za-z0-9_]*$
//	    (bucket keys are emitted as `export KEY=...` for a shell to source)
//
// The literals below must stay byte-identical to secrets_provider.sh;
// tests/unit/security/test_fuzz_ports_lockstep.sh fails when they drift.
//
// Invariants:
//  1. An accepted storage key, joined as "<store>/<key>.age", stays a
//     direct child of the store (no traversal, no separator).
//  2. An accepted storage key never starts with "-" (provider argv) or "."
//  3. An accepted env key is a POSIX shell identifier and is also a
//     valid storage key.
//
// Run locally:
//
//	cd fuzz && go test -run '^$' -fuzz=FuzzSecretKey -fuzztime=30s

package fuzz

import (
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

const (
	secretKeyPattern    = `^[A-Za-z0-9_][A-Za-z0-9_.-]*$`
	secretEnvKeyPattern = `^[A-Za-z_][A-Za-z0-9_]*$`
)

var (
	secretKeyRE    = regexp.MustCompile(secretKeyPattern)
	secretEnvKeyRE = regexp.MustCompile(secretEnvKeyPattern)
)

func FuzzSecretKey(f *testing.F) {
	for _, s := range []string{
		"OPENAI_API_KEY", "my-api.key", "_x", "9lives",
		"../escape", "a/b", "-flag", ".hidden", "", "X;touch", "has space",
		"a..b", "é", "KEY\n", "..", "a\\b",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, key string) {
		if secretKeyRE.MatchString(key) {
			store := "/home/u/.config/dotfiles/secrets/store"
			p := filepath.Join(store, key+".age")
			if filepath.Dir(p) != store {
				t.Fatalf("accepted key %q leaves the store: %s", key, p)
			}
			if strings.HasPrefix(key, "-") || strings.HasPrefix(key, ".") {
				t.Fatalf("accepted key %q with a leading - or .", key)
			}
		}
		if secretEnvKeyRE.MatchString(key) {
			for i, c := range key {
				ok := c == '_' || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (i > 0 && c >= '0' && c <= '9')
				if !ok {
					t.Fatalf("accepted env key %q is not a shell identifier", key)
				}
			}
			if !secretKeyRE.MatchString(key) {
				t.Fatalf("env key %q is not a valid storage key", key)
			}
		}
	})
}
