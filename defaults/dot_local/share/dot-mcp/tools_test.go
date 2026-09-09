// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"context"
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

// TestDefaultToolsAreReadOnly pins the safety property the whole design rests
// on: every shipped tool is annotated read-only, non-destructive and
// closed-world, and none of them can be handed a free-form command.
func TestDefaultToolsAreReadOnly(t *testing.T) {
	for _, tl := range defaultTools() {
		if !tl.Annotations.ReadOnlyHint || tl.Annotations.DestructiveHint || tl.Annotations.OpenWorldHint {
			t.Errorf("%s: annotations are not read-only/closed-world: %+v", tl.Name, tl.Annotations)
		}
		if tl.Schema.Type != "object" || tl.Schema.AdditionalProperties {
			t.Errorf("%s: schema must be a closed object", tl.Name)
		}
		if tl.Title == "" || tl.Description == "" {
			t.Errorf("%s: needs a title and description", tl.Name)
		}
		for name, prop := range tl.Schema.Properties {
			if prop.Type == "" || prop.Description == "" {
				t.Errorf("%s.%s: needs a type and description", tl.Name, name)
			}
		}
	}
}

// TestEveryPatternIsCompiled guards the pairing between the published
// `pattern` and the regexp actually enforced: a schema that advertises a
// constraint it does not apply is the same class of lie as an overstated card.
func TestEveryPatternIsCompiled(t *testing.T) {
	for _, tl := range defaultTools() {
		for name, prop := range tl.Schema.Properties {
			if prop.Pattern == "" {
				if prop.re != nil {
					t.Errorf("%s.%s: compiles a pattern it does not publish", tl.Name, name)
				}
				continue
			}
			if prop.re == nil {
				t.Fatalf("%s.%s: publishes pattern %q but compiles nothing", tl.Name, name, prop.Pattern)
			}
			if prop.re.String() != prop.Pattern {
				t.Errorf("%s.%s: enforces %q but publishes %q", tl.Name, name, prop.re.String(), prop.Pattern)
			}
		}
	}
}

// TestToolArgv pins the exact argument vector each tool runs, which is the
// only place the server decides what to execute.
func TestToolArgv(t *testing.T) {
	tests := []struct {
		tool string
		args map[string]any
		want []string
	}{
		{tool: "mcp-doctor", args: map[string]any{"strict": false}, want: []string{"mcp", "doctor", "--json"}},
		{tool: "mcp-doctor", args: map[string]any{"strict": true}, want: []string{"mcp", "doctor", "--json", "--strict"}},
		{tool: "mcp-doctor", args: map[string]any{}, want: []string{"mcp", "doctor", "--json"}},
		{tool: "mcp-doctor", args: map[string]any{"strict": "yes"}, want: []string{"mcp", "doctor", "--json"}},
		{tool: "agent-mode", args: map[string]any{"action": "current"}, want: []string{"mode", "current"}},
		{tool: "agent-mode", args: map[string]any{"action": "list"}, want: []string{"mode", "list"}},
		{tool: "agent-mode", args: map[string]any{"action": "show", "profile": "audit"}, want: []string{"mode", "show", "audit"}},
		{tool: "agent-mode", args: map[string]any{"action": "show"}, want: []string{"mode", "show"}},
		{tool: "agent-mode", args: map[string]any{}, want: []string{"mode", "current"}},
		{tool: "workstation-attestation", args: nil, want: []string{"attest", "--json"}},
		{tool: "fleet-status", args: nil, want: []string{"fleet", "status", "--json"}},
	}
	byName := map[string]tool{}
	for _, tl := range defaultTools() {
		byName[tl.Name] = tl
	}
	for _, tc := range tests {
		t.Run(tc.tool+"/"+describeArgs(tc.args), func(t *testing.T) {
			tl, ok := byName[tc.tool]
			if !ok {
				t.Fatalf("no such tool: %s", tc.tool)
			}
			if got := tl.argv(tc.args); !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("argv = %v, want %v", got, tc.want)
			}
		})
	}
}

// describeArgs renders an argument map as a stable subtest name.
func describeArgs(args map[string]any) string {
	if len(args) == 0 {
		return "defaults"
	}
	b, _ := json.Marshal(args)
	return strings.NewReplacer("/", "_", " ", "").Replace(string(b))
}

// TestValidateArgs covers acceptance, default injection, and every rejection
// the validator can produce.
func TestValidateArgs(t *testing.T) {
	schema := inputSchema{
		Type: "object",
		Properties: map[string]property{
			"flag":   {Type: "boolean", Description: "a flag", Default: false},
			"choice": {Type: "string", Description: "a choice", Enum: []string{"a", "b"}, Default: "a"},
			"name":   {Type: "string", Description: "a name", Pattern: profileNameRe.String(), re: profileNameRe},
			"free":   {Type: "string", Description: "unconstrained"},
		},
		Required:             []string{"free"},
		AdditionalProperties: false,
	}
	tests := []struct {
		name     string
		raw      map[string]any
		want     map[string]any
		wantCode int
		wantMsg  string
	}{
		{
			name: "defaults are injected",
			raw:  map[string]any{"free": "x"},
			want: map[string]any{"free": "x", "flag": false, "choice": "a"},
		},
		{
			name: "explicit values win over defaults",
			raw:  map[string]any{"free": "x", "flag": true, "choice": "b", "name": "audit"},
			want: map[string]any{"free": "x", "flag": true, "choice": "b", "name": "audit"},
		},
		{name: "unknown argument", raw: map[string]any{"free": "x", "nope": 1}, wantCode: codeInvalidParams, wantMsg: `unknown argument "nope"`},
		{name: "missing required", raw: map[string]any{}, wantCode: codeInvalidParams, wantMsg: `missing required argument "free"`},
		{name: "wrong type for boolean", raw: map[string]any{"free": "x", "flag": "true"}, wantCode: codeInvalidParams, wantMsg: `must be a boolean`},
		{name: "wrong type for string", raw: map[string]any{"free": 3}, wantCode: codeInvalidParams, wantMsg: `must be a string`},
		{name: "value outside the enum", raw: map[string]any{"free": "x", "choice": "z"}, wantCode: codeInvalidParams, wantMsg: `must be one of [a, b]`},
		{name: "value failing the pattern", raw: map[string]any{"free": "x", "name": "Bad Name"}, wantCode: codeInvalidParams, wantMsg: `must match`},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, rerr := validateArgs(schema, tc.raw)
			if tc.wantCode != 0 {
				if rerr == nil {
					t.Fatalf("expected code %d, got %v", tc.wantCode, got)
				}
				if rerr.Code != tc.wantCode {
					t.Fatalf("code = %d, want %d", rerr.Code, tc.wantCode)
				}
				if data, _ := rerr.Data.(string); !strings.Contains(data, tc.wantMsg) {
					t.Fatalf("data = %q, want it to contain %q", data, tc.wantMsg)
				}
				return
			}
			if rerr != nil {
				t.Fatalf("unexpected error: %v (%v)", rerr, rerr.Data)
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("args = %v, want %v", got, tc.want)
			}
		})
	}
}

// TestValidateArgsReportsUnknownKeysDeterministically pins the sort that keeps
// the message stable when a client sends several unknown keys at once.
func TestValidateArgsReportsUnknownKeysDeterministically(t *testing.T) {
	schema := noArgsSchema()
	for i := 0; i < 20; i++ {
		_, rerr := validateArgs(schema, map[string]any{"zeta": 1, "alpha": 2, "mu": 3})
		if rerr == nil {
			t.Fatal("expected a rejection")
		}
		if data, _ := rerr.Data.(string); data != `unknown argument "alpha"` {
			t.Fatalf("data = %q", data)
		}
	}
}

// TestCoerceRejectsUnsupportedSchemaType covers the guard that stops a future
// property type from being waved through unvalidated.
func TestCoerceRejectsUnsupportedSchemaType(t *testing.T) {
	_, rerr := coerce("n", property{Type: "integer", Description: "d"}, 1.0)
	if rerr == nil || rerr.Code != codeInternalError {
		t.Fatalf("rerr = %v, want an internal error", rerr)
	}
}

// TestConditionalRequirements covers the cross-field rule a flat schema cannot
// express, plus the tools it does not apply to.
func TestConditionalRequirements(t *testing.T) {
	tests := []struct {
		name    string
		tool    string
		args    map[string]any
		wantErr bool
	}{
		{name: "show without a profile", tool: "agent-mode", args: map[string]any{"action": "show"}, wantErr: true},
		{name: "show with an empty profile", tool: "agent-mode", args: map[string]any{"action": "show", "profile": ""}, wantErr: true},
		{name: "show with a profile", tool: "agent-mode", args: map[string]any{"action": "show", "profile": "ask"}},
		{name: "current needs nothing", tool: "agent-mode", args: map[string]any{"action": "current"}},
		{name: "other tools are unaffected", tool: "fleet-status", args: map[string]any{}},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rerr := conditionalRequirements(tc.tool, tc.args)
			if tc.wantErr != (rerr != nil) {
				t.Fatalf("rerr = %v, wantErr = %v", rerr, tc.wantErr)
			}
		})
	}
}

// TestBuildCallResult covers each classification: structured JSON, plain text,
// a failing command with output, a failing command without, and silence.
func TestBuildCallResult(t *testing.T) {
	tests := []struct {
		name           string
		res            commandResult
		wantErr        bool
		wantText       string
		wantStructured bool
		wantExit       int
	}{
		{
			name:           "json object becomes structured content",
			res:            commandResult{Stdout: "{\"status\":\"healthy\"}\n"},
			wantText:       `{"status":"healthy"}`,
			wantStructured: true,
		},
		{
			name:           "a non-zero exit with a report is still the report",
			res:            commandResult{Stdout: `{"status":"failed"}`, ExitCode: 1},
			wantText:       `{"status":"failed"}`,
			wantStructured: true,
			wantExit:       1,
		},
		{name: "plain text passes through", res: commandResult{Stdout: "Profile  ask\n"}, wantText: "Profile  ask"},
		{name: "a json array is not structured content", res: commandResult{Stdout: "[1,2]"}, wantText: "[1,2]"},
		{name: "malformed json is not structured content", res: commandResult{Stdout: "{oops"}, wantText: "{oops"},
		{
			name:     "failure merges stderr",
			res:      commandResult{Stdout: "partial", Stderr: "boom\n", ExitCode: 2},
			wantErr:  true,
			wantText: "partial\nboom",
		},
		{
			name:     "silent failure is described",
			res:      commandResult{ExitCode: 127},
			wantErr:  true,
			wantText: "command failed with exit code 127 and no output",
		},
		{name: "silent success is described", res: commandResult{}, wantText: "(no output)"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := buildCallResult(tc.res)
			if got.IsError != tc.wantErr {
				t.Fatalf("isError = %v, want %v", got.IsError, tc.wantErr)
			}
			if len(got.Content) != 1 || got.Content[0].Type != "text" {
				t.Fatalf("content = %+v", got.Content)
			}
			if got.Content[0].Text != tc.wantText {
				t.Fatalf("text = %q, want %q", got.Content[0].Text, tc.wantText)
			}
			if tc.wantStructured {
				obj, ok := got.StructuredContent.(map[string]any)
				if !ok {
					t.Fatalf("structuredContent = %T, want a JSON object", got.StructuredContent)
				}
				if obj["exitCode"] != tc.wantExit {
					t.Fatalf("exitCode = %v, want %v", obj["exitCode"], tc.wantExit)
				}
			} else if got.StructuredContent != nil {
				t.Fatalf("structuredContent = %v, want none", got.StructuredContent)
			}
		})
	}
}

// TestBuildCallResultExitCodeIsAnInt pins that the injected exit code survives
// marshalling as a number rather than a string.
func TestBuildCallResultExitCodeIsAnInt(t *testing.T) {
	b, err := json.Marshal(buildCallResult(commandResult{Stdout: `{"a":1}`, ExitCode: 3}))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), `"exitCode":3`) {
		t.Fatalf("marshalled result = %s", b)
	}
}

// TestDecodeJSONObject covers the classifier directly, including the
// whitespace and non-object cases.
func TestDecodeJSONObject(t *testing.T) {
	tests := []struct {
		in   string
		want bool
	}{
		{`{"a":1}`, true}, {"  \n{\"a\":1}\n ", true}, {`{}`, true},
		{`[]`, false}, {`"s"`, false}, {``, false}, {`{`, false}, {`{"a":1}{"b":2}`, false},
	}
	for _, tc := range tests {
		if _, ok := decodeJSONObject(tc.in); ok != tc.want {
			t.Errorf("decodeJSONObject(%q) = %v, want %v", tc.in, ok, tc.want)
		}
	}
}

// TestExecRunner exercises the production runner against real processes: a
// success, a non-zero exit (data, not a transport failure), and a binary that
// does not exist (a genuine failure).
func TestExecRunner(t *testing.T) {
	ctx := context.Background()
	res, err := execRunner(ctx, "sh", []string{"-c", "printf out; printf err >&2"}, nil)
	if err != nil {
		t.Fatalf("execRunner: %v", err)
	}
	if res.Stdout != "out" || res.Stderr != "err" || res.ExitCode != 0 {
		t.Fatalf("res = %+v", res)
	}

	res, err = execRunner(ctx, "sh", []string{"-c", "exit 3"}, nil)
	if err != nil {
		t.Fatalf("a non-zero exit must not be an error: %v", err)
	}
	if res.ExitCode != 3 {
		t.Fatalf("exit code = %d, want 3", res.ExitCode)
	}

	if _, err := execRunner(ctx, "dot-mcp-no-such-binary", nil, nil); err == nil {
		t.Fatal("expected an error for a missing binary")
	}
}

// TestExecRunnerHonoursTheContextDeadline pins the timeout that keeps a wedged
// tool from stalling the session forever.
func TestExecRunnerHonoursTheContextDeadline(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := execRunner(ctx, "sh", []string{"-c", "sleep 30"}, nil); err == nil {
		t.Fatal("expected a cancellation error")
	}
}

// TestContainsString covers the small membership helper at both edges.
func TestContainsString(t *testing.T) {
	if !containsString([]string{"a", "b"}, "b") {
		t.Error("member reported absent")
	}
	if containsString(nil, "a") {
		t.Error("empty slice reported a member")
	}
}
