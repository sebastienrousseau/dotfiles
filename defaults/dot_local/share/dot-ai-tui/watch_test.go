// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"bytes"
	"errors"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

// A record exactly as plugins/cli/libexec/hook.sh writes it.
const hookRecord = `{"schema":"cli/agent-event.v1","time":"2026-11-08T07:00:00Z","agent":"codex","session":"th-1","state":"blocked","event":"PermissionRequest","cwd":"/home/u/src/shop"}`

var watchT0 = time.Date(2026, 11, 8, 7, 0, 0, 0, time.UTC)

func record(agent, session, state, event string, at time.Time) []byte {
	r := strings.NewReplacer("codex", agent, "th-1", session, `"blocked"`, `"`+state+`"`,
		"PermissionRequest", event, "2026-11-08T07:00:00Z", at.UTC().Format(time.RFC3339))
	return []byte(r.Replace(hookRecord))
}

// shortDir: a temp dir under /tmp, so a socket path in it fits sun_path
// (104 bytes on macOS) whatever $TMPDIR is.
func shortDir(t *testing.T) string {
	t.Helper()
	d, err := os.MkdirTemp("/tmp", "dw")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(d) })
	return d
}

func TestParseAgentEventAcceptsWhatTheHookWrites(t *testing.T) {
	e, err := parseAgentEvent([]byte(hookRecord))
	if err != nil || e.Agent != "codex" || e.Session != "th-1" || e.State != "blocked" || e.Cwd != "/home/u/src/shop" {
		t.Fatalf("got %+v, %v", e, err)
	}
	if e.key() != "codex/th-1" {
		t.Errorf("key %q", e.key())
	}
}

func TestParseAgentEventRefusesWhatIsNotARecord(t *testing.T) {
	bad := map[string]string{
		"json":    `{`,
		"schema":  strings.Replace(hookRecord, "agent-event.v1", "agent-event.v2", 1),
		"agent":   strings.Replace(hookRecord, `"codex"`, `"../x"`, 1),
		"session": strings.Replace(hookRecord, `"th-1"`, `"a/b"`, 1),
		"dotted":  strings.Replace(hookRecord, `"th-1"`, `".hidden"`, 1),
		"state":   strings.Replace(hookRecord, `"blocked"`, `"asleep"`, 1),
		"time":    strings.Replace(hookRecord, "2026-11-08T07:00:00Z", "yesterday", 1),
	}
	for name, in := range bad {
		if _, err := parseAgentEvent([]byte(in)); err == nil {
			t.Errorf("%s: accepted %s", name, in)
		}
	}
}

func TestAgentTableFoldsRecordsAndDropsGoneSessions(t *testing.T) {
	tb := newAgentTable()
	e, _ := parseAgentEvent(record("codex", "s1", "running", "PreToolUse", watchT0))
	if prev := tb.apply(e); prev != "" {
		t.Errorf("a new session has no previous state, got %q", prev)
	}
	e.State = "blocked"
	if prev := tb.apply(e); prev != "running" {
		t.Errorf("previous state %q", prev)
	}
	tb.notifyDue(e.key(), watchT0)
	e.State = "gone"
	if prev := tb.apply(e); prev != "blocked" || len(tb.rows) != 0 || len(tb.notified) != 0 {
		t.Errorf("gone: prev %q, rows %v, notified %v", prev, tb.rows, tb.notified)
	}
}

func TestNotifyDueDebouncesEachSession(t *testing.T) {
	tb := newAgentTable()
	steps := []struct {
		key  string
		at   time.Duration
		want bool
	}{
		{"a/1", 0, true},
		{"a/1", 29 * time.Second, false},
		{"b/2", 29 * time.Second, true},
		{"a/1", 30 * time.Second, true},
	}
	for _, s := range steps {
		if got := tb.notifyDue(s.key, watchT0.Add(s.at)); got != s.want {
			t.Errorf("%s at %v: %v, want %v", s.key, s.at, got, s.want)
		}
	}
}

func TestAgentDirsFollowTheHook(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", "/run/user/1")
	t.Setenv("TMPDIR", "/var/tmp")
	if got := agentRuntimeDir(); got != "/run/user/1/dot" {
		t.Errorf("XDG_RUNTIME_DIR: %q", got)
	}
	t.Setenv("XDG_RUNTIME_DIR", "")
	if got := agentRuntimeDir(); got != "/var/tmp/dot" {
		t.Errorf("TMPDIR (macOS): %q", got)
	}
	t.Setenv("TMPDIR", "")
	if got := agentRuntimeDir(); got != "" {
		t.Errorf("neither: %q", got)
	}
	t.Setenv("XDG_STATE_HOME", "/s")
	if got := agentStateDir(); got != "/s/dot/cli/agents" {
		t.Errorf("XDG_STATE_HOME: %q", got)
	}
	t.Setenv("XDG_STATE_HOME", "")
	t.Setenv("HOME", "/h")
	if got := agentStateDir(); got != "/h/.local/state/dot/cli/agents" {
		t.Errorf("HOME: %q", got)
	}
}

func TestLoadAgentStatesKeepsLiveRecentSessions(t *testing.T) {
	dir := t.TempDir()
	write := func(name string, b []byte) {
		p := filepath.Join(dir, name)
		_ = os.MkdirAll(filepath.Dir(p), 0o700)
		if err := os.WriteFile(p, b, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("codex/live.json", record("codex", "live", "running", "PreToolUse", watchT0.Add(-time.Hour)))
	write("codex/old.json", record("codex", "old", "idle", "Stop", watchT0.Add(-25*time.Hour)))
	write("codex/gone.json", record("codex", "gone", "gone", "SessionEnd", watchT0))
	write("codex/junk.json", []byte("not json"))
	write("codex/big.json", bytes.Repeat([]byte(" "), maxAgentRecord+1))
	_ = os.MkdirAll(filepath.Join(dir, "codex", "dir.json"), 0o700)
	got := loadAgentStates(dir, watchT0)
	if len(got) != 1 || got[0].Session != "live" {
		t.Fatalf("got %+v", got)
	}
}

func TestBlockedReasonNamesAPermissionPrompt(t *testing.T) {
	if blockedReason("PermissionRequest") != "waiting for permission" || blockedReason("Notification") != "waiting for you" {
		t.Error(blockedReason("PermissionRequest"), blockedReason("Notification"))
	}
}

// notifications swaps agentNotify for a recorder.
func notifications(t *testing.T) *[]string {
	t.Helper()
	var mu sync.Mutex
	got := &[]string{}
	orig := agentNotify
	agentNotify = func(title, body string) {
		mu.Lock()
		defer mu.Unlock()
		*got = append(*got, title+" | "+body)
	}
	t.Cleanup(func() { agentNotify = orig })
	return got
}

func TestHandlePrintsChangesAndNotifiesOnceWhenBlocked(t *testing.T) {
	got := notifications(t)
	var out bytes.Buffer
	w := &watcher{table: newAgentTable(), out: &out}
	w.handle(record("codex", "s1", "running", "PreToolUse", watchT0), watchT0)
	w.handle(record("codex", "s1", "running", "PostToolUse", watchT0), watchT0)
	w.handle(record("codex", "s1", "blocked", "PermissionRequest", watchT0), watchT0.Add(time.Second))
	w.handle(record("codex", "s1", "running", "PostToolUse", watchT0), watchT0.Add(2*time.Second))
	w.handle(record("codex", "s1", "blocked", "Notification", watchT0), watchT0.Add(3*time.Second))
	w.handle([]byte("garbage"), watchT0)
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) != 4 {
		t.Fatalf("one line per change of state, got %q", out.String())
	}
	if !strings.Contains(lines[1], "codex    blocked  shop  s1") {
		t.Errorf("line %q", lines[1])
	}
	if len(*got) != 1 || (*got)[0] != "dot ai: codex is blocked | shop: waiting for permission" {
		t.Errorf("notifications %q", *got)
	}
}

func TestHandleCleansTheProjectName(t *testing.T) {
	notifications(t)
	var out bytes.Buffer
	w := &watcher{table: newAgentTable(), out: &out}
	w.handle([]byte(strings.Replace(hookRecord, "/home/u/src/shop", `/x/\u001b]0;pwn\u0007`, 1)), watchT0)
	if strings.ContainsRune(out.String(), 0x1b) || strings.ContainsRune(out.String(), 0x07) {
		t.Errorf("control characters reached the terminal: %q", out.String())
	}
}

func TestAgentNotifyRunsTheNotifier(t *testing.T) {
	ran := make(chan []string, 1)
	orig := execCommand
	execCommand = func(name string, args ...string) *exec.Cmd {
		ran <- append([]string{name}, args...)
		return exec.Command("true")
	}
	defer func() { execCommand = orig }()
	agentNotify("T", "B")
	select {
	case got := <-ran:
		if got[len(got)-2] != "T" || got[len(got)-1] != "B" {
			t.Errorf("args %q", got)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the notifier never ran")
	}
}

func TestListenAgentsMakesAPrivateSocket(t *testing.T) {
	dir := filepath.Join(shortDir(t), "dot")
	conn, sock, err := listenAgents(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	st, _ := os.Stat(sock)
	dst, _ := os.Stat(dir)
	if st.Mode().Perm() != 0o600 || dst.Mode().Perm() != 0o700 || st.Mode()&os.ModeSocket == 0 {
		t.Errorf("socket %v, dir %v", st.Mode(), dst.Mode())
	}
	if !watcherLive(sock) {
		t.Error("the socket does not answer")
	}
	if _, _, err := listenAgents(dir); !errors.Is(err, errWatchRunning) {
		t.Errorf("a second watch: %v", err)
	}
}

func TestListenAgentsReplacesADeadSocket(t *testing.T) {
	dir := shortDir(t)
	conn, sock, err := listenAgents(dir)
	if err != nil {
		t.Fatal(err)
	}
	_ = conn.Close() // a dead watch leaves its socket file behind
	if _, err := os.Stat(sock); err != nil {
		t.Skip("this platform removes the socket on close")
	}
	if watcherLive(sock) {
		t.Fatal("a closed socket still answers")
	}
	conn, _, err = listenAgents(dir)
	if err != nil {
		t.Fatalf("a dead socket is replaced: %v", err)
	}
	_ = conn.Close()
}

func TestListenAgentsErrors(t *testing.T) {
	if _, _, err := listenAgents(""); err == nil || !strings.Contains(err.Error(), "XDG_RUNTIME_DIR") {
		t.Errorf("no runtime dir: %v", err)
	}
	file := filepath.Join(shortDir(t), "f")
	_ = os.WriteFile(file, nil, 0o600)
	if _, _, err := listenAgents(filepath.Join(file, "dot")); err == nil {
		t.Error("a runtime dir under a file")
	}
	long := filepath.Join(shortDir(t), strings.Repeat("d", 120))
	if _, _, err := listenAgents(long); err == nil {
		t.Error("a socket path longer than sun_path")
	}
	orig := chmodSock
	chmodSock = func(string, os.FileMode) error { return errors.New("chmod") }
	defer func() { chmodSock = orig }()
	if _, _, err := listenAgents(shortDir(t)); err == nil || err.Error() != "chmod" {
		t.Errorf("chmod failure: %v", err)
	}
}

func TestWatchSignalsCloseTheSocket(t *testing.T) {
	closed := make(chan struct{})
	watchSignals(closerFunc(func() error { close(closed); return nil }))
	_ = syscall.Kill(os.Getpid(), syscall.SIGTERM)
	select {
	case <-closed:
	case <-time.After(5 * time.Second):
		t.Fatal("SIGTERM did not close the socket")
	}
}

type closerFunc func() error

func (f closerFunc) Close() error { return f() }

// startWatch runs runWatch with the socket under a short runtime dir and
// the state files under state; it returns the socket, its output and a
// stop function that closes the socket and waits for runWatch.
func startWatch(t *testing.T, state string) (string, *syncBuffer, func() error) {
	t.Helper()
	rt := shortDir(t)
	t.Setenv("XDG_RUNTIME_DIR", rt)
	t.Setenv("XDG_STATE_HOME", state)
	notifications(t)
	got := make(chan io.Closer, 1)
	orig := watchSignals
	watchSignals = func(c io.Closer) { got <- c }
	t.Cleanup(func() { watchSignals = orig })
	out := &syncBuffer{}
	done := make(chan error, 1)
	go func() { done <- runWatch(out) }()
	var conn io.Closer
	select {
	case conn = <-got:
	case err := <-done:
		t.Fatalf("runWatch returned early: %v", err)
	}
	return filepath.Join(rt, "dot", "agent-events.sock"), out, func() error {
		_ = conn.Close()
		return <-done
	}
}

func TestRunWatchSeedsFromStateFilesAndFoldsDatagrams(t *testing.T) {
	state := t.TempDir()
	dir := filepath.Join(state, "dot", "cli", "agents", "codex")
	_ = os.MkdirAll(dir, 0o700)
	_ = os.WriteFile(filepath.Join(dir, "s1.json"), record("codex", "s1", "running", "PreToolUse", time.Now()), 0o600)
	sock, buf, stop := startWatch(t, state)
	c, err := net.Dial("unixgram", sock)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = c.Write(record("codex", "s1", "running", "PostToolUse", time.Now()))
	_, _ = c.Write(record("codex", "s1", "blocked", "PermissionRequest", time.Now()))
	_ = c.Close()
	for deadline := time.Now().Add(5 * time.Second); !strings.Contains(buf.String(), "blocked") && time.Now().Before(deadline); {
		time.Sleep(10 * time.Millisecond)
	}
	if err := stop(); err != nil {
		t.Fatal(err)
	}
	out := buf.String()
	if !strings.Contains(out, "dot ai watch: 1 session(s), listening on "+sock) {
		t.Errorf("seeded from the state file: %q", out)
	}
	if strings.Count(out, "\n") != 2 || !strings.Contains(out, "codex    blocked") {
		t.Errorf("one line for the one change of state: %q", out)
	}
	if _, err := os.Stat(sock); !os.IsNotExist(err) {
		t.Error("the socket is removed on exit")
	}
}

func TestRunWatchWhenOneIsAlreadyRunning(t *testing.T) {
	rt := shortDir(t)
	t.Setenv("XDG_RUNTIME_DIR", rt)
	conn, sock, err := listenAgents(filepath.Join(rt, "dot"))
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	var out bytes.Buffer
	if err := runWatch(&out); err != nil || out.String() != "dot ai watch: already running on "+sock+"\n" {
		t.Errorf("%q, %v", out.String(), err)
	}
}

func TestRunWatchWithoutARuntimeDir(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", "")
	t.Setenv("TMPDIR", "")
	if err := runWatch(io.Discard); err == nil {
		t.Error("no runtime dir is an error")
	}
}

func TestRunDispatchesWatch(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", "")
	t.Setenv("TMPDIR", "")
	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"dot-ai-tui", "watch"}
	if err := run(); err == nil || !strings.Contains(err.Error(), "runtime dir") {
		t.Errorf("run watch: %v", err)
	}
}

// syncBuffer is a bytes.Buffer safe to read while runWatch writes.
type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

// FuzzParseAgentEvent: a datagram is anyone's bytes on the socket. An
// accepted record names a session by plain ids, and handling it never puts
// a control character on the terminal.
func FuzzParseAgentEvent(f *testing.F) {
	f.Add([]byte(hookRecord))
	f.Add(record("gemini", "s.1", "running", "PreToolUse", watchT0))
	f.Add([]byte(strings.Replace(hookRecord, "/home/u/src/shop", `/x/\u001b[2J`, 1)))
	f.Add([]byte(`{"schema":"cli/agent-event.v1"}`))
	orig := agentNotify
	agentNotify = func(string, string) {}
	f.Cleanup(func() { agentNotify = orig })
	f.Fuzz(func(t *testing.T, b []byte) {
		e, err := parseAgentEvent(b)
		if err != nil {
			return
		}
		if strings.ContainsAny(e.Agent+e.Session, "/\\") || strings.HasPrefix(e.Session, ".") {
			t.Fatalf("accepted a path in an id: %q %q", e.Agent, e.Session)
		}
		var out bytes.Buffer
		(&watcher{table: newAgentTable(), out: &out}).handle(b, watchT0)
		if strings.ContainsFunc(out.String(), func(r rune) bool { return r < 0x20 && r != '\n' || r == 0x7f }) {
			t.Fatalf("control character in %q", out.String())
		}
	})
}

// BenchmarkWatchHandle: one datagram through the watcher, as each hook
// event costs it.
func BenchmarkWatchHandle(b *testing.B) {
	orig := agentNotify
	agentNotify = func(string, string) {}
	defer func() { agentNotify = orig }()
	w := &watcher{table: newAgentTable(), out: io.Discard}
	recs := [][]byte{
		record("codex", "s1", "running", "PreToolUse", watchT0),
		record("codex", "s1", "blocked", "PermissionRequest", watchT0),
	}
	for i := 0; b.Loop(); i++ {
		w.handle(recs[i%2], watchT0)
	}
}
