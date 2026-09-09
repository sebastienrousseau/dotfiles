// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// The tool surface. Every tool is a read-only `dot` subcommand: the server
// builds an argv, runs it without a shell, and returns what it printed. No
// tool writes configuration, and none takes a free-form command — the argv is
// assembled from a validated, closed schema, never from caller-supplied text.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"time"
)

// defaultToolTimeout bounds a single tool invocation. The slowest real tool is
// the attestation export, which shells out to chezmoi and git.
const defaultToolTimeout = 120 * time.Second

// profileNameRe constrains the one free-form argument any tool accepts. Argv is
// passed to exec without a shell, so this is defence in depth rather than the
// only barrier, but it also keeps a typo from reaching the CLI as a subcommand.
var profileNameRe = regexp.MustCompile(`^[a-z][a-z0-9-]{0,31}$`)

// property is one entry of a tool's input schema. The subset modelled here —
// type, enum, default, description — is all the tools need, and validating
// exactly what is declared keeps the published schema and the enforcement in
// one place.
type property struct {
	Type        string   `json:"type"`
	Description string   `json:"description"`
	Enum        []string `json:"enum,omitempty"`
	Default     any      `json:"default,omitempty"`
	Pattern     string   `json:"pattern,omitempty"`
	// re is Pattern, compiled once at registry construction. Unexported, so
	// it never reaches the wire; TestEveryPatternIsCompiled pins the pairing.
	re *regexp.Regexp
}

// inputSchema is the JSON Schema published for a tool. additionalProperties is
// always false: an unexpected key is a client bug and answering it silently
// would hide the mismatch.
type inputSchema struct {
	Type                 string              `json:"type"`
	Properties           map[string]property `json:"properties"`
	Required             []string            `json:"required,omitempty"`
	AdditionalProperties bool                `json:"additionalProperties"`
}

// annotations are the MCP behavioural hints a client uses to decide whether a
// call needs confirmation. Every tool here is read-only and closed-world.
type annotations struct {
	Title           string `json:"title"`
	ReadOnlyHint    bool   `json:"readOnlyHint"`
	DestructiveHint bool   `json:"destructiveHint"`
	IdempotentHint  bool   `json:"idempotentHint"`
	OpenWorldHint   bool   `json:"openWorldHint"`
}

// tool is one entry of the registry.
type tool struct {
	Name        string
	Title       string
	Description string
	Schema      inputSchema
	Annotations annotations
	// argv maps validated arguments to the `dot` argument vector to run.
	argv func(args map[string]any) []string
}

// toolDescriptor is the wire shape returned by tools/list.
type toolDescriptor struct {
	Name        string      `json:"name"`
	Title       string      `json:"title"`
	Description string      `json:"description"`
	InputSchema inputSchema `json:"inputSchema"`
	Annotations annotations `json:"annotations"`
}

// descriptor renders the tool for tools/list.
func (t tool) descriptor() toolDescriptor {
	return toolDescriptor{
		Name:        t.Name,
		Title:       t.Title,
		Description: t.Description,
		InputSchema: t.Schema,
		Annotations: t.Annotations,
	}
}

// readOnlyAnnotations builds the hint set shared by every tool in the
// registry: safe to call without confirmation, no side effects, local data.
func readOnlyAnnotations(title string) annotations {
	return annotations{
		Title:           title,
		ReadOnlyHint:    true,
		DestructiveHint: false,
		IdempotentHint:  true,
		OpenWorldHint:   false,
	}
}

// noArgsSchema is the schema for a tool that takes no input.
func noArgsSchema() inputSchema {
	return inputSchema{Type: "object", Properties: map[string]property{}, AdditionalProperties: false}
}

// defaultTools is the registry. It is the single source of truth for both
// tools/list and the `tools[]` array in .well-known/mcp/server-card.json; the
// two are pinned together by TestServerCardMatchesRegistry.
func defaultTools() []tool {
	return []tool{
		{
			Name:        "mcp-doctor",
			Title:       "MCP Doctor",
			Description: "Validate MCP configuration, policy, and supply chain. Runs the same audit as `dot mcp doctor --json` and returns its machine-readable summary: launcher allowlist, filesystem scope, argument policy, required tokens, and registry agreement. Read-only.",
			Schema: inputSchema{
				Type: "object",
				Properties: map[string]property{
					"strict": {
						Type:        "boolean",
						Description: "Treat policy warnings as errors, as CI does.",
						Default:     false,
					},
				},
				AdditionalProperties: false,
			},
			Annotations: readOnlyAnnotations("MCP Doctor"),
			argv: func(args map[string]any) []string {
				argv := []string{"mcp", "doctor", "--json"}
				if b, ok := args["strict"].(bool); ok && b {
					argv = append(argv, "--strict")
				}
				return argv
			},
		},
		{
			Name:        "agent-mode",
			Title:       "Agent Mode",
			Description: "Inspect the agent operating profiles (ask/plan/apply/audit): the active profile with its approval, filesystem, network and MCP posture, the full list, or one profile in detail. Inspection only — this server never switches the profile; the only write is the audit-log line `dot mode` appends for every invocation.",
			Schema: inputSchema{
				Type: "object",
				Properties: map[string]property{
					"action": {
						Type:        "string",
						Description: "current: the active profile; list: every profile; show: one profile in detail.",
						Enum:        []string{"current", "list", "show"},
						Default:     "current",
					},
					"profile": {
						Type:        "string",
						Description: "Profile name, required when action is \"show\".",
						Pattern:     profileNameRe.String(),
						re:          profileNameRe,
					},
				},
				AdditionalProperties: false,
			},
			Annotations: readOnlyAnnotations("Agent Mode"),
			argv: func(args map[string]any) []string {
				action, _ := args["action"].(string)
				if action == "" {
					action = "current"
				}
				argv := []string{"mode", action}
				if action == "show" {
					if p, ok := args["profile"].(string); ok {
						argv = append(argv, p)
					}
				}
				return argv
			},
		},
		{
			Name:        "workstation-attestation",
			Title:       "Workstation Attestation",
			Description: "Export workstation attestation evidence as JSON: dotfiles version, platform, commit signing posture, MCP posture and agent mode. Runs `dot attest --json`; the mutating `--write` and fleet-store paths are deliberately not exposed. Read-only.",
			Schema:      noArgsSchema(),
			Annotations: readOnlyAnnotations("Workstation Attestation"),
			argv:        func(map[string]any) []string { return []string{"attest", "--json"} },
		},
		{
			Name:        "fleet-status",
			Title:       "Fleet Status",
			Description: "Show this node's fleet status and configuration drift: node id, namespace, version, OS, kernel, shell, drift state and last apply. Runs `dot fleet status --json`. Read-only.",
			Schema:      noArgsSchema(),
			Annotations: readOnlyAnnotations("Fleet Status"),
			argv:        func(map[string]any) []string { return []string{"fleet", "status", "--json"} },
		},
	}
}

// validateArgs checks a tools/call argument object against the tool's declared
// schema and returns the coerced arguments with defaults applied. The returned
// error is already a JSON-RPC error object so the caller can pass it through.
func validateArgs(s inputSchema, raw map[string]any) (map[string]any, *rpcError) {
	out := map[string]any{}
	names := make([]string, 0, len(raw))
	for k := range raw {
		names = append(names, k)
	}
	sort.Strings(names) // deterministic message when several keys are unknown
	for _, k := range names {
		prop, ok := s.Properties[k]
		if !ok {
			return nil, newRPCError(codeInvalidParams, "invalid params",
				fmt.Sprintf("unknown argument %q", k))
		}
		v, err := coerce(k, prop, raw[k])
		if err != nil {
			return nil, err
		}
		out[k] = v
	}
	for _, req := range s.Required {
		if _, ok := out[req]; !ok {
			return nil, newRPCError(codeInvalidParams, "invalid params",
				fmt.Sprintf("missing required argument %q", req))
		}
	}
	for name, prop := range s.Properties {
		if _, ok := out[name]; !ok && prop.Default != nil {
			out[name] = prop.Default
		}
	}
	return out, nil
}

// coerce validates one value against one property.
func coerce(name string, prop property, v any) (any, *rpcError) {
	switch prop.Type {
	case "boolean":
		b, ok := v.(bool)
		if !ok {
			return nil, typeError(name, "boolean", v)
		}
		return b, nil
	case "string":
		s, ok := v.(string)
		if !ok {
			return nil, typeError(name, "string", v)
		}
		if len(prop.Enum) > 0 && !containsString(prop.Enum, s) {
			return nil, newRPCError(codeInvalidParams, "invalid params",
				fmt.Sprintf("argument %q must be one of [%s]", name, strings.Join(prop.Enum, ", ")))
		}
		if prop.re != nil && !prop.re.MatchString(s) {
			return nil, newRPCError(codeInvalidParams, "invalid params",
				fmt.Sprintf("argument %q must match %s", name, prop.Pattern))
		}
		return s, nil
	default:
		// Unreachable for the shipped registry; a future property type must
		// arrive with its validation rather than being waved through.
		return nil, newRPCError(codeInternalError, "internal error",
			fmt.Sprintf("argument %q has unsupported schema type %q", name, prop.Type))
	}
}

// typeError reports a value of the wrong JSON type.
func typeError(name, want string, got any) *rpcError {
	return newRPCError(codeInvalidParams, "invalid params",
		fmt.Sprintf("argument %q must be a %s, got %T", name, want, got))
}

// containsString reports membership in a small slice.
func containsString(hay []string, needle string) bool {
	for _, s := range hay {
		if s == needle {
			return true
		}
	}
	return false
}

// conditionalRequirements enforces the cross-field rules a flat JSON Schema
// cannot express without allOf/if-then, kept explicit so the failure message
// names the actual rule.
func conditionalRequirements(name string, args map[string]any) *rpcError {
	if name != "agent-mode" {
		return nil
	}
	if action, _ := args["action"].(string); action == "show" {
		if p, _ := args["profile"].(string); p == "" {
			return newRPCError(codeInvalidParams, "invalid params",
				`argument "profile" is required when "action" is "show"`)
		}
	}
	return nil
}

// commandResult is the outcome of one shelled-out command.
type commandResult struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

// runner executes a command and reports what it printed. It is a seam: tests
// substitute a deterministic implementation so no test depends on a `dot`
// binary being installed.
type runner func(ctx context.Context, name string, args []string, env []string) (commandResult, error)

// execRunner is the production runner. The child inherits nothing on stdin and
// writes to buffers, so a tool can never consume or corrupt the protocol
// stream on stdio.
func execRunner(ctx context.Context, name string, args []string, env []string) (commandResult, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = env
	cmd.Stdin = nil
	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	res := commandResult{Stdout: stdout.String(), Stderr: stderr.String()}
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			res.ExitCode = ee.ExitCode()
			return res, nil // a non-zero exit is data, not a transport failure
		}
		return res, err
	}
	return res, nil
}

// textContent is one MCP content block.
type textContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// callResult is the tools/call result payload.
type callResult struct {
	Content           []textContent `json:"content"`
	StructuredContent any           `json:"structuredContent,omitempty"`
	IsError           bool          `json:"isError"`
}

// buildCallResult turns a command outcome into an MCP tool result.
//
// A non-zero exit code is not automatically an error: `dot mcp doctor --json`
// exits 1 when it finds policy problems and still prints the report the caller
// asked for. The rule is therefore: if the command printed a JSON object, that
// is the answer (with the exit code attached); otherwise a non-zero exit means
// the tool could not do its job and the result is flagged.
func buildCallResult(res commandResult) callResult {
	out := callResult{}
	if obj, ok := decodeJSONObject(res.Stdout); ok {
		obj["exitCode"] = res.ExitCode
		out.StructuredContent = obj
		out.Content = []textContent{{Type: "text", Text: strings.TrimRight(res.Stdout, "\n")}}
		return out
	}
	text := strings.TrimRight(res.Stdout, "\n")
	if res.ExitCode != 0 {
		out.IsError = true
		text = strings.TrimSpace(strings.Join([]string{text, strings.TrimRight(res.Stderr, "\n")}, "\n"))
		if text == "" {
			text = fmt.Sprintf("command failed with exit code %d and no output", res.ExitCode)
		}
	}
	if text == "" {
		text = "(no output)"
	}
	out.Content = []textContent{{Type: "text", Text: text}}
	return out
}

// decodeJSONObject reports whether s is a single JSON object and returns it.
// Anything else — an array, a scalar, decorated CLI text — is not structured
// content.
func decodeJSONObject(s string) (map[string]any, bool) {
	trimmed := strings.TrimSpace(s)
	if !strings.HasPrefix(trimmed, "{") {
		return nil, false
	}
	var obj map[string]any
	if err := json.Unmarshal([]byte(trimmed), &obj); err != nil {
		return nil, false
	}
	return obj, true
}
