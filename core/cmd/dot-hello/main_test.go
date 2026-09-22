// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"strings"
	"testing"

	"dotfiles.local/core/protocol"
)

func TestNegotiation(t *testing.T) {
	request := protocol.Initialize{
		Protocol: 1, Profile: protocol.HelloProfile, RequiredAssurance: protocol.AssuranceAudit,
		Capabilities: append([]string(nil), protocol.HelloCapabilities...), Nonce: strings.Repeat("a", 64),
	}
	identity, err := negotiate(request)
	if err != nil || identity.Nonce != request.Nonce || identity.Assurance != protocol.AssuranceAudit {
		t.Fatal(identity, err)
	}
	for _, kind := range []string{"protocol", "profile", "assurance", "missing-capability", "capability-order", "nonce-length", "nonce-encoding"} {
		t.Run(kind, func(t *testing.T) {
			bad := request
			bad.Capabilities = append([]string(nil), request.Capabilities...)
			switch kind {
			case "protocol":
				bad.Protocol = 2
			case "profile":
				bad.Profile = "org.dot.general/v1"
			case "assurance":
				bad.RequiredAssurance = "os-enforced"
			case "missing-capability":
				bad.Capabilities = bad.Capabilities[:2]
			case "capability-order":
				bad.Capabilities[0], bad.Capabilities[1] = bad.Capabilities[1], bad.Capabilities[0]
			case "nonce-length":
				bad.Nonce = strings.Repeat("a", 62)
			case "nonce-encoding":
				bad.Nonce = strings.Repeat("z", 64)
			}
			if _, err := negotiate(bad); err == nil {
				t.Fatal("invalid negotiation accepted")
			}
		})
	}
}
