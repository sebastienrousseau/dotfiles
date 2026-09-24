// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// FuzzGatewayGate ports the request gate of the local AI gateway
// (defaults/dot_local/bin/executable_dot-ai-serve): every request's Host
// header must name the gateway's own loopback address (DNS-rebinding
// guard, `allowed_hosts` / `_host_allowed`), and a request must carry the
// key in `x-api-key` or `authorization: Bearer <key>` (`_authed`).
//
// Invariants:
//  1. An allowed Host is exactly one of 127.0.0.1:P, localhost:P, [::1]:P
//     (case-insensitive, surrounding whitespace ignored) for the gateway's
//     own port P; a DNS name that merely contains those strings is refused.
//  2. A request is authenticated only when one header equals the key
//     exactly after the documented trimming; an empty key authenticates
//     nothing (fail closed).
//
// Run locally:
//
//	cd fuzz && go test -run '^$' -fuzz=FuzzGatewayGate -fuzztime=30s

package fuzz

import (
	"fmt"
	"strings"
	"testing"
)

// gatewayHostAllowed mirrors _host_allowed() over allowed_hosts() for a
// loopback bind with no DOT_AI_ALLOWED_HOSTS.
func gatewayHostAllowed(host string, port uint16) bool {
	h := strings.ToLower(strings.TrimSpace(host))
	for _, name := range []string{"127.0.0.1", "localhost", "[::1]"} {
		if h == fmt.Sprintf("%s:%d", name, port) {
			return true
		}
	}
	return false
}

// gatewayAuthed mirrors _authed(): x-api-key, or an Authorization header
// whose "bearer " prefix (any case) is stripped; both trimmed.
func gatewayAuthed(key, xAPIKey, authorization string) bool {
	if key == "" {
		return false
	}
	sent := strings.TrimSpace(xAPIKey)
	auth := strings.TrimSpace(authorization)
	if len(auth) >= 7 && strings.EqualFold(auth[:7], "bearer ") {
		auth = strings.TrimSpace(auth[7:])
	}
	return sent == key || auth == key
}

func FuzzGatewayGate(f *testing.F) {
	f.Add("127.0.0.1:3456", uint16(3456), "tok", "tok", "")
	f.Add("localhost:3456", uint16(3456), "tok", "", "Bearer tok")
	f.Add("attacker.example:3456", uint16(3456), "tok", "tok", "")
	f.Add("127.0.0.1.evil.test:3456", uint16(3456), "tok", "", "bearer tok")
	f.Add("[::1]:9", uint16(9), "", "", "")
	f.Add(" LOCALHOST:1 ", uint16(1), "k", "k ", "BEARER  k")
	f.Fuzz(func(t *testing.T, host string, port uint16, key, xAPIKey, authorization string) {
		if gatewayHostAllowed(host, port) {
			h := strings.ToLower(strings.TrimSpace(host))
			name := h[:strings.LastIndex(h, ":")]
			if name != "127.0.0.1" && name != "localhost" && name != "[::1]" {
				t.Fatalf("allowed non-loopback Host %q", host)
			}
			if h[strings.LastIndex(h, ":")+1:] != fmt.Sprint(port) {
				t.Fatalf("allowed Host %q for another port than %d", host, port)
			}
		}
		if gatewayAuthed(key, xAPIKey, authorization) {
			if key == "" {
				t.Fatal("an empty key authenticated a request")
			}
			if strings.TrimSpace(xAPIKey) != key && !strings.Contains(authorization, key) {
				t.Fatalf("authenticated without presenting the key: %q %q", xAPIKey, authorization)
			}
		}
	})
}
