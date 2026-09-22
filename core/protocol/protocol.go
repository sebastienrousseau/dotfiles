// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

// Package protocol implements the bounded DPP/1 hello profile, not arbitrary JSON-RPC.
package protocol

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
	"unicode/utf8"
)

const MaxFrame = 65536

type Message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int             `json:"id"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
}

// Strict rejects duplicate keys, unknown fields, trailing values and invalid UTF-8.
func Strict(data []byte, dst any) error {
	if !utf8.Valid(data) || len(data) > MaxFrame {
		return fmt.Errorf("DOT_E_PROTOCOL: encoding or size")
	}
	d := json.NewDecoder(bytes.NewReader(data))
	var walk func(int) error
	walk = func(depth int) error {
		if depth > 16 {
			return fmt.Errorf("DOT_E_PROTOCOL: nesting")
		}
		t, err := d.Token()
		if err != nil {
			return err
		}
		if delim, ok := t.(json.Delim); ok {
			switch delim {
			case '{':
				seen := map[string]bool{}
				for d.More() {
					k, err := d.Token()
					if err != nil {
						return err
					}
					key, ok := k.(string)
					if !ok || seen[key] {
						return fmt.Errorf("DOT_E_PROTOCOL: duplicate key")
					}
					seen[key] = true
					if err := walk(depth + 1); err != nil {
						return err
					}
				}
			case '[':
				for d.More() {
					if err := walk(depth + 1); err != nil {
						return err
					}
				}
			default:
				return fmt.Errorf("DOT_E_PROTOCOL: delimiter")
			}
			_, err = d.Token()
			return err
		}
		return nil
	}
	if err := walk(0); err != nil {
		return err
	}
	if _, err := d.Token(); err != io.EOF {
		return fmt.Errorf("DOT_E_PROTOCOL: trailing JSON")
	}
	d = json.NewDecoder(bytes.NewReader(data))
	d.DisallowUnknownFields()
	return d.Decode(dst)
}

func Read(r *bufio.Reader) (Message, error) {
	var m Message
	line, err := r.ReadSlice('\n')
	if err != nil || len(line) > 64 || !bytes.HasSuffix(line, []byte("\r\n")) {
		return m, fmt.Errorf("DOT_E_PROTOCOL: header")
	}
	s := strings.TrimSuffix(string(line), "\r\n")
	if !strings.HasPrefix(s, "Content-Length: ") {
		return m, fmt.Errorf("DOT_E_PROTOCOL: framing")
	}
	n, err := strconv.Atoi(strings.TrimPrefix(s, "Content-Length: "))
	if err != nil || n < 1 || n > MaxFrame {
		return m, fmt.Errorf("DOT_E_PROTOCOL: length")
	}
	blank, err := r.ReadSlice('\n')
	if err != nil || string(blank) != "\r\n" {
		return m, fmt.Errorf("DOT_E_PROTOCOL: extra header")
	}
	data := make([]byte, n)
	if _, err := io.ReadFull(r, data); err != nil {
		return m, err
	}
	if err := Strict(data, &m); err != nil {
		return m, err
	}
	if m.JSONRPC != "2.0" || m.ID <= 0 {
		return m, fmt.Errorf("DOT_E_PROTOCOL: envelope")
	}
	return m, nil
}

func Write(w io.Writer, m Message) error {
	b, err := json.Marshal(m)
	if err != nil {
		return err
	}
	if len(b) > MaxFrame {
		return fmt.Errorf("DOT_E_PROTOCOL: length")
	}
	_, err = fmt.Fprintf(w, "Content-Length: %d\r\n\r\n%s", len(b), b)
	return err
}

func Value(v any) json.RawMessage {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}

type Initialize struct {
	Protocol int    `json:"protocol"`
	Nonce    string `json:"nonce"`
}
type Identity struct {
	Protocol int    `json:"protocol"`
	Nonce    string `json:"nonce"`
	ID       string `json:"id"`
}
type Proposal struct {
	Names []string `json:"names"`
}
type Materialize struct {
	Stage string `json:"stage"`
}
type Artifact struct {
	Name   string `json:"name"`
	SHA256 string `json:"sha256"`
	Size   int    `json:"size"`
}
type Materialized struct {
	Artifacts []Artifact `json:"artifacts"`
}
type Validated struct {
	Valid bool `json:"valid"`
}
