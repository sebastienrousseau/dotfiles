# dot-policy

The AI policy evaluator ([ADR-025](../../../../docs/adr/ADR-025-enforced-ai-policy.md)).
`dot cli hook check`, the pre-tool hook of Claude Code, Codex and Gemini CLI,
runs it with the tool call on stdin; it decides the call by the active mode's
rules in `~/.config/dotfiles/ai-policy.toml` and prints a denial in the form
that agent reads. Policy format: [docs/AI.md](../../../../docs/AI.md#enforced-policy).

chezmoi builds it to `~/.local/bin/dot-policy` when Go is installed
(`run_onchange_27-build-dot-policy.sh.tmpl`).

```sh
go test -race ./...                                   # 100% of statements
go test -run '^$' -fuzz '^FuzzDecide$' -fuzztime 30s  # also FuzzParsePolicy, FuzzGlob
go test -run '^$' -bench . -benchtime 2000x           # one hook call, in process
echo '{"tool_name":"Write","tool_input":{"file_path":"a"},"cwd":"/w"}' |
  go run . check --agent claude --mode ask --policy /path/to/ai-policy.toml
```

| File | What |
| --- | --- |
| `main.go` | `check` and `validate`; the active mode; each agent's output form |
| `policy.go` | `ai-policy.v1`: parsing, validation, per-agent overrides |
| `eval.go` | tool classes; the paths, commands and hosts a call touches |
| `glob.go` | the one glob syntax every list uses |
