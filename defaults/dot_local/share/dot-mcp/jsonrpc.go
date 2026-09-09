// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// JSON-RPC 2.0 framing for the stdio transport: one JSON object per line, no
// Content-Length headers. Everything in this file is transport-level and knows
// nothing about MCP semantics.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
)

// JSON-RPC 2.0 error codes (§5.1) plus the MCP-specific codes this server
// returns. Kept as named constants so a handler cannot invent a code.
const (
	codeParseError     = -32700 // malformed JSON in a frame
	codeInvalidRequest = -32600 // well-formed JSON, not a valid request object
	codeMethodNotFound = -32601 // unknown method
	codeInvalidParams  = -32602 // params failed schema validation
	codeInternalError  = -32603 // handler failed for an internal reason
	codeResourceNotOK  = -32002 // MCP: resource URI is not served
)

// maxFrameBytes caps a single line so a peer cannot exhaust memory by sending
// an unterminated stream. 8 MiB is far beyond any legitimate MCP frame (the
// largest thing this server returns is an attestation document).
const maxFrameBytes = 8 << 20

// errFrameTooLarge is returned when a single line exceeds maxFrameBytes.
var errFrameTooLarge = errors.New("jsonrpc: frame exceeds maximum size")

// rpcError is the JSON-RPC error object.
type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

// Error implements error so a handler can return an *rpcError directly.
func (e *rpcError) Error() string { return fmt.Sprintf("jsonrpc %d: %s", e.Code, e.Message) }

// newRPCError builds an error object; data is omitted when nil.
func newRPCError(code int, message string, data any) *rpcError {
	return &rpcError{Code: code, Message: message, Data: data}
}

// request is an incoming JSON-RPC request or notification. ID is kept raw
// because the spec allows a string, a number or null, and the response must
// echo it back byte-for-byte.
type request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// isNotification reports whether the message carries no id and therefore must
// never be answered (JSON-RPC 2.0 §4.1).
func (r *request) isNotification() bool {
	return len(r.ID) == 0 || string(r.ID) == "null"
}

// response is an outgoing JSON-RPC response. Exactly one of Result and Error
// is set; Result uses a pointer-free `any` with omitempty suppressed by the
// wrapper functions so `"result": {}` still marshals.
type response struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

// notification is an outgoing server-initiated message (no id, no reply).
type notification struct {
	JSONRPC string `json:"jsonrpc"`
	Method  string `json:"method"`
	Params  any    `json:"params,omitempty"`
}

// nullID is the id used when a request could not be parsed well enough to
// recover its own id (JSON-RPC 2.0 §5).
var nullID = json.RawMessage("null")

// decodeRequest parses one frame and validates the envelope. A frame that is
// valid JSON but not a valid request object yields codeInvalidRequest, so the
// caller can still answer rather than dropping the connection.
func decodeRequest(frame []byte) (*request, *rpcError) {
	var req request
	if err := json.Unmarshal(frame, &req); err != nil {
		return nil, newRPCError(codeParseError, "parse error", err.Error())
	}
	if req.JSONRPC != "2.0" {
		return nil, newRPCError(codeInvalidRequest, "invalid request", `"jsonrpc" must be "2.0"`)
	}
	if req.Method == "" {
		return nil, newRPCError(codeInvalidRequest, "invalid request", `"method" must be a non-empty string`)
	}
	if len(req.ID) > 0 && !validID(req.ID) {
		return nil, newRPCError(codeInvalidRequest, "invalid request", `"id" must be a string, number or null`)
	}
	return &req, nil
}

// validID reports whether a raw id is one of the JSON types the spec allows.
// Objects and arrays are rejected; null is allowed and treated as absent.
func validID(raw json.RawMessage) bool {
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return false
	}
	switch v.(type) {
	case string, float64, nil:
		return true
	default:
		return false
	}
}

// frameReader reads newline-delimited frames, skipping blank lines and
// enforcing maxFrameBytes. It is deliberately not bufio.Scanner: Scanner
// reports an oversize line as a terminal error with no way to distinguish it
// from EOF, and the frame limit needs its own error.
type frameReader struct {
	r     *bufio.Reader
	limit int
}

// newFrameReader wraps r with the default frame limit.
func newFrameReader(r io.Reader) *frameReader {
	return &frameReader{r: bufio.NewReaderSize(r, 64<<10), limit: maxFrameBytes}
}

// next returns the next non-blank frame with its line terminator stripped.
// It returns io.EOF when the stream ends cleanly, including on a trailing
// fragment with no newline (which is still delivered first).
func (fr *frameReader) next() ([]byte, error) {
	for {
		line, err := fr.readLine()
		if len(line) > 0 {
			return line, nil
		}
		if err != nil {
			return nil, err
		}
	}
}

// readLine reads one line, trims CR/LF, and enforces the size limit. A
// non-empty final line without a newline is returned with a nil error so the
// caller processes it before seeing EOF on the next call.
func (fr *frameReader) readLine() ([]byte, error) {
	var buf []byte
	for {
		chunk, err := fr.r.ReadSlice('\n')
		if len(buf)+len(chunk) > fr.limit {
			return nil, errFrameTooLarge
		}
		buf = append(buf, chunk...)
		if err == nil {
			return trimEOL(buf), nil
		}
		if errors.Is(err, bufio.ErrBufferFull) {
			continue // long line: keep accumulating
		}
		if errors.Is(err, io.EOF) && len(buf) > 0 {
			return trimEOL(buf), nil // trailing fragment, no newline
		}
		return nil, err
	}
}

// trimEOL strips a trailing "\n" and an optional preceding "\r".
func trimEOL(b []byte) []byte {
	if n := len(b); n > 0 && b[n-1] == '\n' {
		b = b[:n-1]
	}
	if n := len(b); n > 0 && b[n-1] == '\r' {
		b = b[:n-1]
	}
	return b
}

// frameWriter serialises outgoing messages as one JSON object per line. Writes
// are mutex-guarded: log notifications are emitted from the same goroutine as
// responses today, but the lock keeps the invariant true if that ever changes,
// and a half-interleaved frame is unrecoverable for the client.
type frameWriter struct {
	mu sync.Mutex
	w  io.Writer
}

// newFrameWriter wraps w.
func newFrameWriter(w io.Writer) *frameWriter { return &frameWriter{w: w} }

// write marshals v and emits it as a single newline-terminated frame.
func (fw *frameWriter) write(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	b = append(b, '\n')
	fw.mu.Lock()
	defer fw.mu.Unlock()
	_, err = fw.w.Write(b)
	return err
}

// writeResult answers a request with a result payload.
func (fw *frameWriter) writeResult(id json.RawMessage, result any) error {
	if len(id) == 0 {
		id = nullID
	}
	return fw.write(response{JSONRPC: "2.0", ID: id, Result: result})
}

// writeError answers a request with an error object.
func (fw *frameWriter) writeError(id json.RawMessage, e *rpcError) error {
	if len(id) == 0 {
		id = nullID
	}
	return fw.write(response{JSONRPC: "2.0", ID: id, Error: e})
}

// writeNotification emits a server-initiated notification.
func (fw *frameWriter) writeNotification(method string, params any) error {
	return fw.write(notification{JSONRPC: "2.0", Method: method, Params: params})
}
