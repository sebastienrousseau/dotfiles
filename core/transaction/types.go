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
	var out bytes.Buffer
	var emit func(any) error
	emit = func(v any) error {
		switch x := v.(type) {
		case nil:
			out.WriteString("null")
			return nil
		case bool:
			out.WriteString(strconv.FormatBool(x))
			return nil
		case string:
			for _, c := range x {
				if c < 32 || c > 126 {
					return fmt.Errorf("DOT_E_VALIDATION: hello profile requires printable ASCII")
				}
			}
			e := json.NewEncoder(&out)
			e.SetEscapeHTML(false)
			if err := e.Encode(x); err != nil {
				return err
			}
			bs := out.Bytes()
			if len(bs) > 0 && bs[len(bs)-1] == '\n' {
				out.Truncate(len(bs) - 1)
			}
			return nil
		case json.Number:
			n, err := strconv.ParseUint(string(x), 10, 53)
			if err != nil {
				return fmt.Errorf("DOT_E_VALIDATION: integer profile")
			}
			out.WriteString(strconv.FormatUint(n, 10))
			return nil
		case []any:
			out.WriteByte('[')
			for i, item := range x {
				if i > 0 {
					out.WriteByte(',')
				}
				if err := emit(item); err != nil {
					return err
				}
			}
			out.WriteByte(']')
			return nil
		case map[string]any:
			keys := make([]string, 0, len(x))
			for k := range x {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			out.WriteByte('{')
			for i, k := range keys {
				if i > 0 {
					out.WriteByte(',')
				}
				if err := emit(k); err != nil {
					return err
				}
				out.WriteByte(':')
				if err := emit(x[k]); err != nil {
					return err
				}
			}
			out.WriteByte('}')
			return nil
		default:
			return fmt.Errorf("DOT_E_VALIDATION: unsupported canonical value")
		}
	}
	if err := emit(value); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func Seal(p Plan) (Sealed, error) { b, err := Canonical(p); return Sealed{Plan: p, ID: Digest(b)}, err }
