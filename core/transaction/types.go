// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
)

const MaxFile = 65536

type Snapshot struct {
	Exists bool   `json:"exists"`
	Digest string `json:"sha256"`
	Mode   uint32 `json:"mode"`
	UID    uint32 `json:"uid"`
	GID    uint32 `json:"gid"`
}
type Operation struct {
	Name   string   `json:"name"`
	Before Snapshot `json:"before"`
	After  Snapshot `json:"after"`
}
type Effect struct {
	Kind          string `json:"kind"`
	Target        string `json:"target"`
	FailurePolicy string `json:"failure_policy"`
}
type Plan struct {
	Version      int         `json:"version"`
	RootID       string      `json:"root_id"`
	Nonce        string      `json:"nonce"`
	PluginDigest string      `json:"plugin_digest"`
	ProposalID   string      `json:"proposal_id"`
	Operations   []Operation `json:"operations"`
	Effects      []Effect    `json:"effects,omitempty"`
}
type Sealed struct {
	Plan Plan   `json:"plan"`
	ID   string `json:"plan_id"`
}

func Digest(b []byte) string { s := sha256.Sum256(b); return hex.EncodeToString(s[:]) }

// Canonical implements the deliberately restricted JCS profile: ASCII strings,
// integer-safe nonnegative numbers, arrays and closed ASCII-key objects only.
// It rejects Unicode/floating point rather than silently minting non-JCS hashes.
func Canonical(v any) ([]byte, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	d := json.NewDecoder(bytes.NewReader(b))
	d.UseNumber()
	var value any
	if err := d.Decode(&value); err != nil {
		return nil, err
	}
	var emit func(any) (string, error)
	emit = func(v any) (string, error) {
		switch x := v.(type) {
		case nil:
			return "null", nil
		case bool:
			return strconv.FormatBool(x), nil
		case string:
			for _, c := range x {
				if c < 32 || c > 126 {
					return "", fmt.Errorf("DOT_E_VALIDATION: hello profile requires printable ASCII")
				}
			}
			var out bytes.Buffer
			e := json.NewEncoder(&out)
			e.SetEscapeHTML(false)
			if err := e.Encode(x); err != nil {
				return "", err
			}
			return strings.TrimSuffix(out.String(), "\n"), nil
		case json.Number:
			n, err := strconv.ParseUint(string(x), 10, 53)
			if err != nil {
				return "", fmt.Errorf("DOT_E_VALIDATION: integer profile")
			}
			return strconv.FormatUint(n, 10), nil
		case []any:
			a := []string{}
			for _, item := range x {
				s, err := emit(item)
				if err != nil {
					return "", err
				}
				a = append(a, s)
			}
			return "[" + strings.Join(a, ",") + "]", nil
		case map[string]any:
			keys := []string{}
			for k := range x {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			a := []string{}
			for _, k := range keys {
				key, err := emit(k)
				if err != nil {
					return "", err
				}
				val, err := emit(x[k])
				if err != nil {
					return "", err
				}
				a = append(a, key+":"+val)
			}
			return "{" + strings.Join(a, ",") + "}", nil
		default:
			return "", fmt.Errorf("DOT_E_VALIDATION: unsupported canonical value")
		}
	}
	s, err := emit(value)
	return []byte(s), err
}

func Seal(p Plan) (Sealed, error) { b, err := Canonical(p); return Sealed{Plan: p, ID: Digest(b)}, err }
