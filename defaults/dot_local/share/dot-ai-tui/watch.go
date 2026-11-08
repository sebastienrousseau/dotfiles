// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// watch.go — `dot-ai-tui watch` (dot ai watch): the agent-event listener.
//
// Each agent's hook (dot cli hook run) writes the session's last state to
// $XDG_STATE_HOME/dot/cli/agents/<agent>/<session>.json and, when a socket
// of this user's listens at <runtime>/dot/agent-events.sock, sends the same
// agent-event.v1 record there as a datagram. watch owns that socket: it
// keeps the live table (seeded from the state files), prints each change
// of state, and posts a desktop notification when a session becomes
// blocked, at most once per session every 30 s. The hook never starts it:
// with no listener, the state files alone carry the state.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"syscall"
	"time"
)

const (
	agentEventSchema = "cli/agent-event.v1"
	blockedDebounce  = 30 * time.Second
	agentWindow      = 24 * time.Hour
	maxAgentRecord   = 64 << 10
)

// agentEvent is one agent-event.v1 record
// (schemas/cli/agent-event.v1.schema.json).
type agentEvent struct {
	Schema  string `json:"schema"`
	Time    string `json:"time"`
	Agent   string `json:"agent"`
	Session string `json:"session"`
	State   string `json:"state"`
	Event   string `json:"event"`
	Cwd     string `json:"cwd"`
}

var (
	agentIDRe   = regexp.MustCompile(`^[a-z][a-z0-9-]{0,31}$`)
	sessionIDRe = regexp.MustCompile(`^[A-Za-z0-9._-]{1,128}$`)
	agentStates = map[string]bool{"running": true, "blocked": true, "idle": true, "error": true, "gone": true}
)

// parseAgentEvent: a record as the hook writes it, or why it is not one.
func parseAgentEvent(b []byte) (agentEvent, error) {
	var e agentEvent
	if err := json.Unmarshal(b, &e); err != nil {
		return e, err
	}
	switch {
	case e.Schema != agentEventSchema:
		return e, fmt.Errorf("schema %q", e.Schema)
	case !agentIDRe.MatchString(e.Agent):
		return e, fmt.Errorf("agent %q", e.Agent)
	case !sessionIDRe.MatchString(e.Session) || strings.HasPrefix(e.Session, "."):
		return e, fmt.Errorf("session %q", e.Session)
	case !agentStates[e.State]:
		return e, fmt.Errorf("state %q", e.State)
	}
	if _, err := time.Parse(time.RFC3339, e.Time); err != nil {
		return e, err
	}
	return e, nil
}

func (e agentEvent) key() string { return e.Agent + "/" + e.Session }

// agentTable is the live table: each session's last record, and when its
// last blocked notification went out.
type agentTable struct {
	rows     map[string]agentEvent
	notified map[string]time.Time
}

func newAgentTable() *agentTable {
	return &agentTable{rows: map[string]agentEvent{}, notified: map[string]time.Time{}}
}

// apply folds one record in and returns the session's previous state
// ("" when it is new). A gone session leaves the table.
func (t *agentTable) apply(e agentEvent) string {
	prev := t.rows[e.key()].State
	if e.State == "gone" {
		delete(t.rows, e.key())
		delete(t.notified, e.key())
		return prev
	}
	t.rows[e.key()] = e
	return prev
}

// notifyDue: whether a session that just became blocked gets a
// notification, at most one per blockedDebounce.
func (t *agentTable) notifyDue(key string, now time.Time) bool {
	if last, ok := t.notified[key]; ok && now.Sub(last) < blockedDebounce {
		return false
	}
	t.notified[key] = now
	return true
}

// agentRuntimeDir: <runtime>/dot, where the hook looks for the socket
// ($XDG_RUNTIME_DIR, else $TMPDIR as on macOS); "" when neither is set.
func agentRuntimeDir() string {
	d := os.Getenv("XDG_RUNTIME_DIR")
	if d == "" {
		d = os.Getenv("TMPDIR")
	}
	if d == "" {
		return ""
	}
	return filepath.Join(d, "dot")
}

// agentStateDir: where the hook writes each session's state file.
func agentStateDir() string {
	d := os.Getenv("XDG_STATE_HOME")
	if d == "" {
		d = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	return filepath.Join(d, "dot", "cli", "agents")
}

// loadAgentStates: the records in the state files written within
// agentWindow of now, gone sessions and unreadable files left out.
func loadAgentStates(dir string, now time.Time) []agentEvent {
	files, _ := filepath.Glob(filepath.Join(dir, "*", "*.json"))
	var out []agentEvent
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil || len(b) > maxAgentRecord {
			continue
		}
		e, err := parseAgentEvent(b)
		if err != nil || e.State == "gone" || !recent(e, now) {
			continue
		}
		out = append(out, e)
	}
	return out
}

func recent(e agentEvent, now time.Time) bool {
	t, err := time.Parse(time.RFC3339, e.Time)
	return err == nil && now.Sub(t) < agentWindow
}

// watcherLive: whether something already listens on the socket.
func watcherLive(sock string) bool {
	c, err := net.Dial("unixgram", sock)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
}

// agentNotify posts a desktop notification without waiting for it, and
// reaps the notifier so a long-running watch leaves no zombies.
var agentNotify = func(title, body string) {
	cmd := notifyCmd(runtime.GOOS, title, body)
	go func() { _ = cmd.Run() }()
}

// blockedReason: what a blocked session waits on, from its event.
func blockedReason(event string) string {
	if event == "PermissionRequest" {
		return "waiting for permission"
	}
	return "waiting for you"
}

// watcher turns datagrams into table changes, lines and notifications.
type watcher struct {
	table *agentTable
	out   io.Writer
}

// handle folds one datagram in: a change of state prints a line, and a
// session becoming blocked notifies. Anything that is not a record is
// dropped.
func (w *watcher) handle(b []byte, now time.Time) {
	e, err := parseAgentEvent(b)
	if err != nil {
		return
	}
	prev := w.table.apply(e)
	if prev == e.State {
		return
	}
	project := clean(filepath.Base(e.Cwd))
	fmt.Fprintf(w.out, "%s %-8s %-8s %s  %s\n", now.Format("15:04:05"), e.Agent, e.State, project, e.Session)
	if e.State == "blocked" && w.table.notifyDue(e.key(), now) {
		agentNotify("dot ai: "+e.Agent+" is blocked", project+": "+blockedReason(e.Event))
	}
}

// listenAgents: the socket, made private, after checking no other watch
// holds it; a socket left by a dead watch is replaced.
func listenAgents(dir string) (*net.UnixConn, string, error) {
	if dir == "" {
		return nil, "", errors.New("no runtime dir: set XDG_RUNTIME_DIR or TMPDIR")
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, "", err
	}
	sock := filepath.Join(dir, "agent-events.sock")
	if watcherLive(sock) {
		return nil, sock, errWatchRunning
	}
	_ = os.Remove(sock)
	conn, err := net.ListenUnixgram("unixgram", &net.UnixAddr{Name: sock, Net: "unixgram"})
	if err != nil {
		return nil, sock, err
	}
	if err := chmodSock(sock, 0o600); err != nil {
		_ = conn.Close()
		return nil, sock, err
	}
	return conn, sock, nil
}

var (
	errWatchRunning = errors.New("already running")
	chmodSock       = os.Chmod
)

// watchSignals closes conn on SIGINT or SIGTERM, which ends the read loop.
var watchSignals = func(conn io.Closer) {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		_ = conn.Close()
	}()
}

// runWatch: dot ai watch. Seeds the table from the state files, then folds
// in each datagram until a signal closes the socket.
func runWatch(out io.Writer) error {
	conn, sock, err := listenAgents(agentRuntimeDir())
	if errors.Is(err, errWatchRunning) {
		fmt.Fprintln(out, "dot ai watch: already running on "+sock)
		return nil
	}
	if err != nil {
		return err
	}
	defer func() { _ = os.Remove(sock) }()
	w := &watcher{table: newAgentTable(), out: out}
	for _, e := range loadAgentStates(agentStateDir(), nowTime()) {
		w.table.apply(e)
	}
	fmt.Fprintf(out, "dot ai watch: %d session(s), listening on %s\n", len(w.table.rows), sock)
	watchSignals(conn)
	buf := make([]byte, maxAgentRecord)
	for {
		n, err := conn.Read(buf)
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}
			return err
		}
		w.handle(buf[:n], nowTime())
	}
}

var nowTime = time.Now
