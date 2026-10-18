// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"os"
	"strings"
	"testing"
	"time"
)

const claudeIdentity = "Sat Oct 18 09:00:00 2026     /opt/bin/claude"

// killFixture selects claude (cursor 0) with one claude and one ollama
// process, and records every SIGTERM sent.
func killFixture(t *testing.T) (m model, killed *[]int, identity map[int]string) {
	t.Helper()
	m = sized()
	m.cursor = 0
	m.ecoSnap.ActiveProcs = []AIProcess{
		{PID: 700, Name: "ollama", Role: "local-llm", CPUPct: 90},
		{PID: 48210, Name: "claude", Role: "agent", CPUPct: 12},
	}
	killed = &[]int{}
	identity = map[int]string{48210: claudeIdentity, 700: "Sat Oct 18 08:00:00 2026     ollama"}
	origKill, origID := killProcess, procIdentity
	t.Cleanup(func() { killProcess, procIdentity = origKill, origID })
	killProcess = func(pid int) error { *killed = append(*killed, pid); return nil }
	procIdentity = func(pid int) string { return identity[pid] }
	return m, killed, identity
}

func TestKillNeedsASecondPressAndTargetsTheSelectedTool(t *testing.T) {
	m, killed, _ := killFixture(t)
	m = upd(m, key("x"))
	if len(*killed) != 0 {
		t.Fatalf("first x must only arm, sent %v", *killed)
	}
	if !strings.Contains(m.status, "x again") || !strings.Contains(m.status, "48210") {
		t.Fatalf("arm prompt: %q", m.status)
	}
	m = upd(m, key("x"))
	if len(*killed) != 1 || (*killed)[0] != 48210 {
		t.Fatalf("want SIGTERM to claude 48210 (not top-CPU ollama), got %v", *killed)
	}
	if !strings.Contains(m.status, "sent SIGTERM to claude (PID 48210)") || m.kill.pid != 0 {
		t.Fatalf("after kill: status %q pending %+v", m.status, m.kill)
	}
}

func TestKillNeverFallsBackToAnotherTool(t *testing.T) {
	m, killed, _ := killFixture(t)
	m.cursor = 2 // copilot: nothing running
	m = upd(m, key("x"))
	m = upd(m, key("x"))
	if len(*killed) != 0 {
		t.Fatalf("no copilot process: nothing may be signalled, got %v", *killed)
	}
	if !strings.Contains(m.status, "no running copilot process") {
		t.Fatalf("status: %q", m.status)
	}
}

func TestKillIsCancelledByAnyOtherKey(t *testing.T) {
	m, killed, _ := killFixture(t)
	m = upd(m, key("x"))
	m = upd(m, key("left")) // navigation leaves the status line to the cancel notice
	if m.kill.pid != 0 || !strings.Contains(m.status, "cancelled") {
		t.Fatalf("other key must cancel: %+v %q", m.kill, m.status)
	}
	m = upd(m, key("x"))
	if len(*killed) != 0 {
		t.Fatalf("x after a cancel must re-arm, not kill: %v", *killed)
	}
}

func TestKillArmExpires(t *testing.T) {
	m, killed, _ := killFixture(t)
	m = upd(m, key("x"))
	m.kill.deadline = time.Now().Add(-time.Second)
	m = upd(m, key("x"))
	if len(*killed) != 0 || m.kill.pid != 48210 {
		t.Fatalf("expired arm must re-arm instead of killing: killed=%v pending=%+v", *killed, m.kill)
	}
}

func TestKillRefusesAReusedOrVanishedPID(t *testing.T) {
	m, killed, identity := killFixture(t)
	m = upd(m, key("x"))
	identity[48210] = "Sat Oct 18 09:30:00 2026     /usr/bin/python3" // PID reused
	m = upd(m, key("x"))
	if len(*killed) != 0 || !strings.Contains(m.status, "changed") {
		t.Fatalf("reused PID: killed=%v status=%q", *killed, m.status)
	}

	m, killed, identity = killFixture(t)
	delete(identity, 48210) // exited since the last ps sample
	m = upd(m, key("x"))
	if len(*killed) != 0 || m.kill.pid != 0 || !strings.Contains(m.status, "no longer running") {
		t.Fatalf("vanished PID: killed=%v pending=%+v status=%q", *killed, m.kill, m.status)
	}

	m, killed, identity = killFixture(t)
	identity[48210] = "Sat Oct 18 09:00:00 2026     /usr/sbin/sshd" // stale snapshot: PID is someone else now
	m = upd(m, key("x"))
	if len(*killed) != 0 || m.kill.pid != 0 {
		t.Fatalf("snapshot PID no longer claude: killed=%v pending=%+v", *killed, m.kill)
	}
}

func TestKillReportsSignalErrors(t *testing.T) {
	m, _, _ := killFixture(t)
	killProcess = func(int) error { return errors.New("operation not permitted") }
	m = upd(m, key("x"))
	m = upd(m, key("x"))
	if !strings.Contains(m.status, "operation not permitted") {
		t.Fatalf("status: %q", m.status)
	}
}

func TestIdentityComm(t *testing.T) {
	for in, want := range map[string]string{
		claudeIdentity:                      "claude",
		"Sat Oct 18 09:00:00 2026 node app": "node app",
		"short":                             "",
		"Sat Oct 18 09:00:00 2026":          "",
		"":                                  "",
	} {
		if got := identityComm(in); got != want {
			t.Errorf("identityComm(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestDefaultProcIdentityReadsThisProcess(t *testing.T) {
	if got := identityComm(procIdentity(os.Getpid())); got == "" {
		t.Fatal("procIdentity of the test process must name a program")
	}
	if procIdentity(0) != "" || procIdentity(-1) != "" {
		t.Fatal("PID 0 (the process group) and negative PIDs must yield no identity")
	}
}
