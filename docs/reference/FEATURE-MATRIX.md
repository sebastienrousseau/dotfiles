---
render_with_liquid: false
---

# Feature Matrix

Every user-facing feature of the `dot` CLI, with the regression test,
benchmark, example and manual section that cover it. One row per feature:
a command, or a distinct variant, flag, environment variable or config key
of one.

This file is a **contract, not a summary**. `scripts/qa/check-feature-matrix.sh`
parses it on every push and fails when:

- a subcommand exists in `scripts/dot/commands/` or in
  `docs/manual/command-index.md` and has no row here;
- a row names a regression test function that no
  `tests/regression/test_feature_matrix_*.sh` file defines;
- a row names a benchmark id that
  `benches/dot_command_bench.sh --list-ids` does not produce;
- a row names an example file that does not exist.

So a new subcommand cannot merge without coverage, and coverage cannot be
deleted without the matrix going red.

## Totals

| Measure | Count |
|---------|-------|
| Feature rows | 371 |
| Covered by a regression test | 318 (85%) |
| Unmeasurable, with a recorded reason + `--help` smoke test | 53 (14%) |
| Benchmarked | 371 (100%) |
| With a runnable example | 371 (100%) |
| Distinct commands covered | 103 |

Every row is covered: a row is either exercised end to end against the real
CLI in a sandboxed `HOME`, or — where the feature genuinely cannot be
measured without changing the developer's machine, spending money on a model,
or holding a terminal open — it is marked `smoke` with the reason recorded in
its Coverage cell, and still carries an integration smoke test asserting that
`dot <command> --help` exits 0 and renders help for the right command without
performing the command.

## How to run the coverage this table names

```bash
# The regression rows (all of them, ~700 assertions):
./tests/framework/test_runner.sh --jobs auto

# One group:
bash tests/regression/test_feature_matrix_fleet_registry.sh

# The benchmarks (help cold-start for every command; --full adds the
# read-only invocations):
bash benches/dot_command_bench.sh --full --output bench.json

# The examples:
bash scripts/qa/validate-examples.sh

# This file's own drift gate:
bash scripts/qa/check-feature-matrix.sh
```

## Reading a row

| Column | Meaning |
|--------|---------|
| Command | The `dot` subcommand. |
| Variant | The specific flag, subcommand, environment variable or config key this row pins. |
| Regression test | A shell function in `tests/regression/test_feature_matrix_*.sh`. |
| Benchmark | An id from `benches/dot_command_bench.sh`. `help:<cmd>` is that command's cold-start; `run:<id>` is a real read-only invocation. |
| Example | A runnable script under `examples/`, executed by `scripts/qa/validate-examples.sh`. |
| Manual | Where the feature is documented. |
| Coverage | `regression`, or `smoke` plus the reason the feature is unmeasurable in CI. |


## dispatcher: bin/dot

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot version` | (default) | `test_fm_version` | `run:version` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot version` | --version | `test_fm_version_long_flag` | `run:version-flag` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot version` | -v | `test_fm_version_short_flag` | `help:version` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | (default overview) | `test_fm_help_overview` | `run:help` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | dot (no arguments) | `test_fm_help_no_args` | `run:help-noargs` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | --help | `test_fm_help_long_flag` | `run:help-flag` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | -h | `test_fm_help_short_flag` | `help:help` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | all | `test_fm_help_all` | `run:help-all` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | <command> | `test_fm_help_topic` | `run:help-topic` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | <unknown> (exit 1) | `test_fm_help_unknown_topic` | `run:help-unknown` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | <cmd> --help / -h intercept (never dispatches) | `test_fm_help_universal_intercept` | `run:help-intercept` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot search` | <keyword> | `test_fm_search` | `run:search` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot search` | (no keyword, exit 1) | `test_fm_search_missing_keyword` | `run:search-usage` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot search` | <keyword> with no match | `test_fm_search_no_match` | `run:search-nomatch` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | unknown command (exit 1) | `test_fm_unknown_command` | `run:unknown-command` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | ~/.config/dotfiles/commands/<name>.sh user command | `test_fm_user_custom_command` | `run:user-command` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | DOTFILES_SHOW_LOGO=0 suppresses the product banner | `test_fm_env_dotfiles_show_logo` | `run:version-nologo` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot help` | NO_COLOR=1 strips ANSI from non-TTY output | `test_fm_env_no_color` | `help:version` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## core.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot sync` | (default, --check/--pull passthrough) | `test_fm_sync` | `run:sync-check` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot apply` | alias of sync | `test_fm_apply` | `run:apply-dry-run` | `examples/example-dot-core.sh` | `docs/manual/command-index.md` | regression |
| `dot update` | alias (chezmoi update) | `test_fm_update` | `run:update` | `examples/example-dot-core.sh` | `docs/manual/command-index.md` | regression |
| `dot add` | <file> | `test_fm_add` | `run:add` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot add` | (no file, exit 1) | `test_fm_add_usage` | `run:add-usage` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot diff` | (default) | `test_fm_diff` | `run:diff` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot status` | (clean tree) | `test_fm_status` | `run:status` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot status` | (drifted tree passthrough) | `test_fm_status_drift` | `help:status` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot cd` | (default) | `test_fm_cd` | `run:cd` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot edit` | (honours $EDITOR) | `test_fm_edit` | `run:edit` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot edit` | EDITOR env selects the editor | `test_fm_env_editor` | `help:edit` | `examples/example-dot-core.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot commit` | (no staged changes, exit 1) | `test_fm_commit` | `run:commit` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot uninstall` | (prompts unless --force) | `test_fm_smoke_uninstall` | `help:uninstall` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — destructive — removes the managed environment from $HOME; only --help is exercised |
| `dot uninstall` | --force | `test_fm_smoke_uninstall_force` | `help:uninstall` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — destructive — --force skips the confirmation and purges real files |

## diagnostics.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot doctor` | (default) | `test_fm_doctor` | `run:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --score / -s | `test_fm_doctor_score` | `run:doctor-score` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --smoke / -m | `test_fm_doctor_smoke` | `run:doctor-smoke` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --drift / -d | `test_fm_doctor_drift` | `run:doctor-drift` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --heal / -H | `test_fm_doctor_heal` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --audit / -a | `test_fm_doctor_audit` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --json / -j, --ai / -A passthrough | `test_fm_doctor_json` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --benchmark / -b | `test_fm_smoke_doctor_benchmark` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — runs tests/benchmark.sh (hyperfine over every shell, minutes) — covered by benches/bench.sh |
| `dot heal` | (default) | `test_fm_heal` | `run:heal` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot heal` | --dry-run / -n | `test_fm_heal_dry_run` | `run:heal-dry-run` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot health` | (default) | `test_fm_health` | `run:health` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health` | --json / -j | `test_fm_health_json` | `run:health-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health` | --verbose / -v | `test_fm_health_verbose` | `help:health` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health-check` | alias of health | `test_fm_health_check_alias` | `help:health-check` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health` | --fix / -f, --force / -F | `test_fm_smoke_health_fix` | `help:health` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | **smoke** — --fix re-applies chezmoi and rewrites shell configs in $HOME |
| `dot security-score` | (default) | `test_fm_security_score` | `run:security-score` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot security-score` | --json / -j | `test_fm_security_score_json` | `run:security-score-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot security-score` | --quiet / -q, --verbose / -v | `test_fm_security_score_quiet` | `help:security-score` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot score` | (default) | `test_fm_score` | `run:score` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot score` | --json / -j | `test_fm_score_json` | `run:score-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot scorecard` | alias of score | `test_fm_scorecard` | `help:scorecard` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot perf` | --json / -j, --runs / -r | `test_fm_perf_json` | `run:perf` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot perf` | --profile / -p, --target / -t, --shell / -s, --by-tool, --reset, --baseline, --no-baseline-check | `test_fm_perf_profile` | `help:perf` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot conflicts` | (default) | `test_fm_conflicts` | `run:conflicts` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot locks` | (default) | `test_fm_locks` | `run:locks` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot snapshot` | (default) | `test_fm_snapshot` | `run:snapshot` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot snapshot` | --baseline / -b, --force / -f | `test_fm_snapshot_baseline` | `help:snapshot` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot snapshot` | XDG_STATE_HOME controls where snapshots/attestations are written | `test_fm_env_xdg_state_home` | `help:snapshot` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot attest` | (default) | `test_fm_attest` | `run:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attest` | --json / -j | `test_fm_attest_json` | `run:attest-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attest` | --write / -w | `test_fm_attest_write` | `help:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attest` | --fleet-store / -F <dir>, --fleet-id / -I <id> | `test_fm_attest_fleet_store` | `help:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attestation` | alias of attest | `test_fm_attestation` | `help:attestation` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot rollback` | status | `test_fm_rollback_status` | `run:rollback-status` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` | backup | `test_fm_rollback_backup` | `help:rollback` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` | clean | `test_fm_rollback_clean` | `help:rollback` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` | <unknown> (usage, exit 1) | `test_fm_rollback_unknown` | `help:rollback` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` | rollback / rollback-to N / git-reset / restore FILE (--force, --dry-run, --verbose) | `test_fm_smoke_rollback_restore` | `help:rollback` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — rewrites $HOME dotfiles from a backup and resets the git checkout |
| `dot drift` | (default) | `test_fm_drift` | `run:drift` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot drift` | --json / -j, --diff / -d | `test_fm_drift_json` | `run:drift-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot history` | (default, reads $HISTFILE) | `test_fm_history` | `run:history` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot history` | (no history file, exit 1) | `test_fm_history_missing` | `help:history` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot history` | HISTFILE selects the shell history analysed | `test_fm_env_histfile` | `help:history` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot benchmark` | (default, --detailed, --profile, --compare, --waterfall) | `test_fm_benchmark` | `run:benchmark` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` | --list / -l | `test_fm_restore_list` | `run:restore-list` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` | --git / -g <ref> with --dry-run / -n | `test_fm_restore_git_dry_run` | `help:restore` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` | --diff / -d <ref> | `test_fm_restore_diff` | `help:restore` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` | --latest / -L | `test_fm_restore_latest` | `help:restore` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` | (no option prints usage), --help / -h, unknown option (exit 1) | `test_fm_restore_usage` | `run:restore-usage` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` | DOTFILES_DIR selects the git checkout restore reads | `test_fm_env_dotfiles_dir` | `help:restore` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot load-bench` | (default, runs count) | `test_fm_load_bench` | `run:load-bench` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot load-bench-pty` | (default) | `test_fm_smoke_load_bench_pty` | `help:load-bench-pty` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | **smoke** — needs the chezmoi-rendered dot-load-benchmark-pty template and a pseudo-terminal |
| `dot chaos` | (refuses without --force) | `test_fm_chaos` | `run:chaos` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot chaos` | --force | `test_fm_smoke_chaos_force` | `help:chaos` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — deliberately deletes ~/.zshrc and terminal configs |
| `dot teleport` | user@host | `test_fm_smoke_teleport` | `help:teleport` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | **smoke** — opens an SSH session to a remote host (network) |
| `dot teleport` | (no host, exit 1) | `test_fm_teleport_usage` | `run:teleport-usage` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot bundle` | [output-dir] | `test_fm_smoke_bundle` | `help:bundle` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — archives ~/.dotfiles plus tool caches with zstd (hundreds of MB, minutes) |
| `dot secret-audit` | (default) | `test_fm_secret_audit` | `run:secret-audit` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot metrics` | [count] | `test_fm_metrics` | `run:metrics` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot metrics` | (no metrics recorded yet) | `test_fm_metrics_empty` | `help:metrics` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot smoke-test` | (default) | `test_fm_smoke_test` | `run:smoke-test` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot intelligence` | (default) | `test_fm_intelligence` | `run:intelligence` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |

## ai.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot ai` | (default cockpit TUI) | `test_fm_smoke_ai_cockpit` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — launches the Bubble Tea cockpit / gum launcher (interactive TTY) |
| `dot ai tools` | (status table, cached probes) | `test_fm_ai_tools` | `run:ai-tools` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai tools` | install (alias of ai install) | `test_fm_smoke_ai_tools_install` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — installs AI CLIs through mise/native installers (network, mutates $HOME) |
| `dot ai` | status (deprecated alias of ai tools) | `test_fm_ai_status_deprecated` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai tools` | DOTFILES_AI_STATUS_TTL / DOTFILES_AI_PROBE_JOBS control the probe cache | `test_fm_env_dotfiles_ai_status_ttl` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot ai cost` | (default, --since N) | `test_fm_ai_cost` | `run:ai-cost` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai doctor` | (default) | `test_fm_ai_doctor` | `run:ai-doctor` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai run` | "<prompt>" (usage without prompt) | `test_fm_ai_run_usage` | `run:ai-run-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai run` | "<prompt>" one-shot on Claude | `test_fm_smoke_ai_run_prompt` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — performs a paid LLM round-trip (network) |
| `dot ai` | "<prompt>" / <tool> "<prompt>" one-shot | `test_fm_smoke_ai_oneshot_bare` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — performs a paid LLM round-trip (network) |
| `dot ai delegate` | "<prompt>" (usage without prompt) | `test_fm_ai_delegate_usage` | `run:ai-delegate-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai delegate` | "<prompt>" [max-turns] [agent] [timeout] | `test_fm_smoke_ai_delegate_prompt` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — delegates to a paid model under agent policy (network) |
| `dot ai ask` | "<question>" (usage without question) | `test_fm_ai_ask_usage` | `run:ai-ask-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai ask` | "<question>" RAG query | `test_fm_smoke_ai_ask_query` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — embeds the repo and calls an LLM (network) |
| `dot ai chat` | [tool] | `test_fm_smoke_ai_chat` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — starts an interactive AI session (TTY) |
| `dot ai install` | [tool] | `test_fm_smoke_ai_install` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — installs AI CLIs (network, mutates $HOME) |
| `dot ai serve` | (default) | `test_fm_smoke_ai_serve` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — starts a long-running local gateway process bound to a port |
| `dot ai login` | (default) | `test_fm_smoke_ai_login` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — interactive OAuth / API-key prompts (TTY, network) |
| `dot ai` | dashboard / dash (deprecated cockpit alias) | `test_fm_smoke_ai_dashboard` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — launches the cockpit TUI (interactive TTY) |
| `dot ai` | proxy / local (deprecated alias of ai serve) | `test_fm_ai_proxy_deprecated` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai-setup` | deprecated alias of ai login | `test_fm_smoke_ai_setup` | `help:ai-setup` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — interactive tool authentication (TTY, network) |
| `dot ai-query` | deprecated alias of ai ask (usage without question) | `test_fm_ai_query_usage` | `run:ai-query-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot cl` | (usage without prompt; deprecated bridge) | `test_fm_ai_bridge_cl` | `run:cl-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot claude` | alias of cl | `test_fm_ai_bridge_claude` | `help:claude` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot codex` | (usage without prompt) | `test_fm_ai_bridge_codex` | `help:codex` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot copilot` | (usage without prompt) | `test_fm_ai_bridge_copilot` | `help:copilot` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot kimi` | (usage without prompt) | `test_fm_ai_bridge_kimi` | `help:kimi` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agy` | (usage without prompt) | `test_fm_ai_bridge_agy` | `help:agy` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot goose` | (usage without prompt) | `test_fm_ai_bridge_goose` | `help:goose` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot kiro` | (usage without prompt) | `test_fm_ai_bridge_kiro` | `help:kiro` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot sgpt` | (usage without prompt) | `test_fm_ai_bridge_sgpt` | `help:sgpt` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ollama` | (usage without prompt) | `test_fm_ai_bridge_ollama` | `help:ollama` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot opencode` | (usage without prompt) | `test_fm_ai_bridge_opencode` | `help:opencode` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot aider` | (usage without prompt) | `test_fm_ai_bridge_aider` | `help:aider` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot autohand` | (usage without prompt) | `test_fm_ai_bridge_autohand` | `help:autohand` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot vibe` | (usage without prompt) | `test_fm_ai_bridge_vibe` | `help:vibe` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot qwen` | (usage without prompt) | `test_fm_ai_bridge_qwen` | `help:qwen` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot zai` | (usage without prompt) | `test_fm_ai_bridge_zai` | `help:zai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot cl` | --style / --pattern / -p <name> (unknown pattern exits 1) | `test_fm_ai_bridge_style` | `help:cl` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot cl` | "<prompt>" with an installed tool | `test_fm_smoke_ai_bridge_prompt` | `help:cl` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — performs a paid LLM round-trip (network) |
| `dot cl` | DOT_AI_RAW=1 suppresses the banner and metadata preamble | `test_fm_env_dot_ai_raw` | `help:cl` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## tools.sh / aliases.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot env` | list / ls (default; requires mise) | `test_fm_env_list` | `run:env-list` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | prune (dry-run; requires mise) | `test_fm_env_prune` | `help:env` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | prune --yes / -y | `test_fm_smoke_env_prune_yes` | `help:env` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — uninstalls orphan tool versions from the real mise store |
| `dot env` | install [tool@version] | `test_fm_smoke_env_install` | `help:env` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — downloads and installs toolchains through mise (network) |
| `dot env` | use <tool@version> | `test_fm_smoke_env_use` | `help:env` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — rewrites the user's mise config and installs tools (network) |
| `dot env` | emit (default json, --pretty) | `test_fm_env_emit` | `run:env-emit` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | emit --compact | `test_fm_env_emit_compact` | `help:env` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | emit --format ndjson / --format=ndjson | `test_fm_env_emit_ndjson` | `help:env` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | emit --output / -o <file> (atomic write) | `test_fm_env_emit_output` | `help:env` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | emit --format <unsupported> (exit 1) | `test_fm_env_emit_bad_format` | `help:env` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | emit <unknown flag> (exit 1) | `test_fm_env_emit_bad_flag` | `help:env` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | emit --help / -h | `test_fm_env_emit_help` | `help:env` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` | show (default) | `test_fm_profile_show` | `run:profile-show` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` | set <name> (writes .chezmoidata.toml) | `test_fm_profile_set` | `help:profile` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` | set (no name, exit 1) | `test_fm_profile_set_usage` | `help:profile` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` | <unknown> (exit 1) | `test_fm_profile_unknown` | `help:profile` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` | .chezmoidata.toml `profile` + `[features]` keys | `test_fm_config_chezmoidata_profile` | `help:profile` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot tools` | (default overview) | `test_fm_tools` | `run:tools` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot tools` | docs | `test_fm_tools_docs` | `run:tools-docs` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot tools` | install (Nix develop shell) | `test_fm_smoke_tools_install` | `help:tools` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | **smoke** — enters an interactive `nix develop` shell (TTY, network) |
| `dot new` | <lang> <name> | `test_fm_new` | `help:new` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot new` | (no args, exit 1) / unknown template (exit 1) | `test_fm_new_usage` | `run:new-usage` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot packages` | (default) | `test_fm_packages` | `run:packages` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot aliases` | list (default) | `test_fm_aliases_list` | `run:aliases-list` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | search <term> | `test_fm_aliases_search` | `run:aliases-search` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | search <term> with no match (exit 1) / missing term (exit 1) | `test_fm_aliases_search_nomatch` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | why <alias> | `test_fm_aliases_why` | `run:aliases-why` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | why <unknown> (exit 1) | `test_fm_aliases_why_unknown` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | stats (reads $HISTFILE) | `test_fm_aliases_stats` | `run:aliases-stats` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | stats (no history file, exit 1) | `test_fm_aliases_stats_missing` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | cheatsheet --output / -o <path> | `test_fm_aliases_cheatsheet` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | cheatsheet --output - | `test_fm_aliases_cheatsheet_stdout` | `run:aliases-cheatsheet` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | cheatsheet (writes docs/ALIASES_CHEATSHEET.md in the source tree) | `test_fm_aliases_cheatsheet_default` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | tiers | `test_fm_aliases_tiers` | `run:aliases-tiers` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` | DOTFILES_ALIAS_PROFILE / DOTFILES_ALIAS_ECOSYSTEMS / DOTFILES_ALIAS_BUCKETS / DOTFILES_SECURITY_MODE / DOTFILES_ENABLE_DANGEROUS_ALIASES | `test_fm_env_dotfiles_alias_tiers` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot aliases` | <unknown> (exit 1) | `test_fm_aliases_unknown` | `help:aliases` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot alias-check` | (default) | `test_fm_alias_check` | `run:alias-check` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot setup` | (interactive gum wizard) | `test_fm_smoke_setup` | `help:setup` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | **smoke** — interactive gum selection wizard (TTY) |
| `dot log-rotate` | (default) | `test_fm_log_rotate` | `run:log-rotate` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |

## lint.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot lint` | (default: shellcheck + shfmt report) | `test_fm_lint` | `help:lint` | `examples/example-dot-lint.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot lint` | --check / -c (exit 1 on findings) | `test_fm_lint_check` | `help:lint` | `examples/example-dot-lint.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot lint` | --fix / -f (rewrites files with shfmt) | `test_fm_lint_fix` | `help:lint` | `examples/example-dot-lint.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## appearance.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot theme` | (default) | `test_fm_theme` | `run:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot theme` | list | `test_fm_theme_list` | `run:theme-list` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot theme` | current | `test_fm_theme_current` | `run:theme-current` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot theme` | set with no name: reports a diagnostic and leaves the theme unchanged | `test_fm_theme_set_missing` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot theme` | set <name> / light / dark | `test_fm_smoke_theme_set` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — switches the OS appearance and rewrites terminal configs (osascript / gsettings) |
| `dot theme` | toggle | `test_fm_smoke_theme_toggle` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — switches the OS appearance (system mutation) |
| `dot theme` | sync | `test_fm_smoke_theme_sync` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — rewrites terminal configs to follow the OS appearance (system mutation) |
| `dot theme` | family | `test_fm_smoke_theme_family` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — cycles the theme family and applies it (system mutation) |
| `dot theme` | rebuild | `test_fm_smoke_theme_rebuild` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — regenerates every theme from wallpapers (minutes of image processing) |
| `dot wallpaper` | (default = sync) | `test_fm_smoke_wallpaper` | `help:wallpaper` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — sets the desktop wallpaper through osascript / feh (system mutation) |
| `dot wallpaper` | sync | `test_fm_smoke_wallpaper_sync` | `help:wallpaper` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — sets the desktop wallpaper (system mutation) |
| `dot wallpaper` | rotate (--interval, --once, --light, --dark) | `test_fm_smoke_wallpaper_rotate` | `help:wallpaper` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — sets the desktop wallpaper (system mutation) |
| `dot fonts` | (default = install) | `test_fm_smoke_fonts` | `help:fonts` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — downloads and installs Nerd Fonts into the user font directory (network) |
| `dot fonts` | install [font] | `test_fm_smoke_fonts_install` | `help:fonts` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — downloads and installs Nerd Fonts (network) |
| `dot fonts` | patch <font-file> [output-dir] | `test_fm_fonts_patch_usage` | `help:fonts` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | regression |
| `dot tune` | (default) | `test_fm_smoke_tune` | `help:tune` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — writes OS defaults / sysctl values (system mutation, sudo) |

## secrets.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot secrets-init` | (default; creates the age key) | `test_fm_secrets_init` | `help:secrets-init` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | edit (default) | `test_fm_secrets_edit` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | edit without an age key (exit 1) | `test_fm_secrets_edit_no_key` | `run:secrets-edit-nokey` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | set <KEY> <VALUE> | `test_fm_secrets_set` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | set (no key, exit 1) | `test_fm_secrets_set_usage` | `run:secrets-set-usage` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | set <KEY> (prompts for the value) | `test_fm_smoke_secrets_set_prompt` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — reads the secret value from an interactive silent prompt (TTY) |
| `dot secrets` | get <KEY> (masked) | `test_fm_secrets_get` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | get <KEY> --raw | `test_fm_secrets_get_raw` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | get <unknown> (exit 1) / get without key (exit 1) | `test_fm_secrets_get_missing` | `run:secrets-get-missing` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | list | `test_fm_secrets_list` | `run:secrets-list` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | load [bucket] (posix export lines) | `test_fm_secrets_load` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | load --shell fish | `test_fm_secrets_load_fish` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | load --shell=nu / nushell | `test_fm_secrets_load_nu` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | load <bucket> with nothing stored (exit 1) / unknown flag (exit 1) | `test_fm_secrets_load_empty` | `run:secrets-load-empty` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | provider | `test_fm_secrets_provider` | `run:secrets-provider` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | DOTFILES_SECRETS_PROVIDER / DOT_SECRETS_HOME select the backend and store | `test_fm_env_dotfiles_secrets_provider` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot secrets` | .chezmoidata.toml `[secrets.policy] provider` / `auto_load` defaults | `test_fm_config_secrets_policy` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot secrets` | <unknown> (exit 1) | `test_fm_secrets_unknown` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` | load [bucket] (secrets.sh alias of secrets load) | `test_fm_secrets_env_load` | `help:env` | `examples/example-dot-secrets.sh` | `docs/manual/command-index.md` | regression |
| `dot secrets-create` | [name] (needs the age key) | `test_fm_secrets_create` | `help:secrets-create` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets-create` | without an age key (exit 1) | `test_fm_secrets_create_no_key` | `run:secrets-create-nokey` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-key` | [key-path] (encrypts ~/.ssh/id_ed25519 with age) | `test_fm_ssh_key_missing` | `run:ssh-key-missing` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-cert` | (usage) / status / issue / revoke | `test_fm_ssh_cert_usage` | `run:ssh-cert-usage` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-cert` | status | `test_fm_ssh_cert_status` | `run:ssh-cert-status` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-cert` | issue [--ttl] [--principal] / revoke | `test_fm_smoke_ssh_cert_issue` | `help:ssh-cert` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — contacts a step-ca server and rewrites ~/.ssh certificates (network) |

## security.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot backup` | (default; DOTFILES_BACKUP_DIR / DOTFILES_BACKUP_SRC) | `test_fm_backup` | `help:backup` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |
| `dot encrypt-check` | (default) | `test_fm_encrypt_check` | `run:encrypt-check` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |
| `dot firewall` | (default) | `test_fm_smoke_firewall` | `help:firewall` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — enables the OS firewall with sudo (system mutation) |
| `dot telemetry` | (refuses unless DOTFILES_TELEMETRY=1) | `test_fm_telemetry` | `run:telemetry` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |
| `dot telemetry` | DOTFILES_TELEMETRY=1 | `test_fm_smoke_telemetry_apply` | `help:telemetry` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — disables OS telemetry services with sudo (system mutation) |
| `dot dns-doh` | (default) | `test_fm_smoke_dns_doh` | `help:dns-doh` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — rewrites the system resolver configuration with sudo (system mutation) |
| `dot lock-screen` | (default) | `test_fm_smoke_lock_screen` | `help:lock-screen` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — writes screensaver / idle-lock OS settings (system mutation) |
| `dot usb-safety` | (default) | `test_fm_smoke_usb_safety` | `help:usb-safety` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — writes udev / automount policy with sudo (system mutation) |
| `dot policy` | (default; needs opa + gitleaks) | `test_fm_policy` | `run:policy` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |

## meta.sh / agent.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot upgrade` | (default) | `test_fm_smoke_upgrade` | `help:upgrade` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — runs nix flake update, chezmoi update, and a headless Neovim plugin sync (network, mutates $HOME) |
| `dot upgrade` | DOTFILES_FONTS=1 adds the Nerd Font step to upgrade | `test_fm_smoke_env_dotfiles_fonts` | `help:upgrade` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — only observable inside the real upgrade run (network) |
| `dot cache-refresh` | (default) | `test_fm_cache_refresh` | `run:cache-refresh` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot prewarm` | alias of cache-refresh | `test_fm_prewarm` | `help:prewarm` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot cache-refresh` | XDG_CACHE_HOME receives the regenerated shell caches | `test_fm_env_xdg_cache_home` | `help:cache-refresh` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot docs` | (default) | `test_fm_docs` | `run:docs` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot learn` | (interactive tour) | `test_fm_learn` | `run:learn` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot keys` | (default catalog) | `test_fm_keys` | `run:keys` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot keys` | sign-check | `test_fm_keys_sign_check` | `run:keys-sign-check` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot keys` | sign-check with an ssh signing key configured | `test_fm_keys_sign_check_ssh` | `help:keys` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot sandbox` | (default) | `test_fm_smoke_sandbox` | `help:sandbox` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | **smoke** — builds and runs a Docker/Podman image interactively (network, TTY) |
| `dot mcp` | (default = doctor) | `test_fm_mcp` | `run:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp doctor` | (default) | `test_fm_mcp_doctor` | `run:mcp-doctor` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp doctor` | --json / -j, --strict / -s | `test_fm_mcp_doctor_json` | `run:mcp-doctor-json` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp registry` | (default table) | `test_fm_mcp_registry` | `run:mcp-registry` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp registry` | --json / -j | `test_fm_mcp_registry_json` | `run:mcp-registry-json` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp registry` | MCP_REGISTRY_CONFIG overrides the registry file | `test_fm_env_mcp_registry_config` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot mcp registry` | dot_config/dotfiles/mcp-registry.json `servers` map | `test_fm_config_mcp_registry_json` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot mcp` | <unknown> (usage, exit 1) | `test_fm_mcp_unknown` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode` | (default = current) | `test_fm_mode` | `run:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode list` | (default) | `test_fm_mode_list` | `run:mode-list` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode current` | (default) | `test_fm_mode_current` | `run:mode-current` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode show` | <profile> | `test_fm_mode_show` | `run:mode-show` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode show` | <unknown> (exit 1) / missing name (exit 1) | `test_fm_mode_show_unknown` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode set` | <profile> (writes agent-mode.env) | `test_fm_mode_set` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode set` | <unknown> (exit 1) | `test_fm_mode_set_unknown` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode set` | refused by strict RBAC enforcement (exit 1) | `test_fm_mode_set_rbac_strict` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode run` | [profile] <command> (checkpointed) | `test_fm_mode_run` | `run:mode-run` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode run` | (no command, exit 1) | `test_fm_mode_run_usage` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode run` | propagates the wrapped command's exit code | `test_fm_mode_run_exit_code` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode doctor` | (default) | `test_fm_mode_doctor` | `run:mode-doctor` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode` | <unknown> (usage, exit 1) | `test_fm_mode_unknown` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode` | AGENT_PROFILE_CONFIG / AGENT_STATE_FILE override the profiles file and state file | `test_fm_env_agent_profile_config` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot mode` | dot_config/dotfiles/agent-profiles.json `defaultProfile` / `profiles` / `rbac` / `delegation` | `test_fm_config_agent_profiles_json` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot mode` | ~/.config/dotfiles/agent-mode.env state file (DOT_AGENT_PROFILE …) | `test_fm_config_agent_mode_env` | `help:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot agent` | (default = current profile) | `test_fm_agent` | `run:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent card` | (default table) | `test_fm_agent_card` | `run:agent-card` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent card` | --json | `test_fm_agent_card_json` | `run:agent-card-json` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent card` | AGENT_CARD_CONFIG overrides the card file | `test_fm_env_agent_card_config` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot agent card` | dot_config/dotfiles/agent-card.json `name` / `version` / `protocols` / `platforms` | `test_fm_config_agent_card_json` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot agent log` | [count] | `test_fm_agent_log` | `run:agent-log` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | list (default) [count] | `test_fm_agent_checkpoint_list` | `run:agent-checkpoint-list` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | save [profile] <command> | `test_fm_agent_checkpoint_save` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | save (no command, exit 1) | `test_fm_agent_checkpoint_save_usage` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | show <id> [--json / -j] | `test_fm_agent_checkpoint_show` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | show <unknown> (exit 1) / missing id (exit 1) | `test_fm_agent_checkpoint_show_unknown` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | replay <id> | `test_fm_agent_checkpoint_replay` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent checkpoint` | replay (no id, exit 1) / <unknown action> (exit 1) | `test_fm_agent_checkpoint_replay_usage` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent delegate` | <name> <command> (delegation enabled) | `test_fm_agent_delegate` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent delegate` | refused when delegation is disabled (exit 1) / unknown delegate (exit 1) | `test_fm_agent_delegate_disabled` | `run:agent-delegate-usage` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent delegate` | (no name or command, exit 1) | `test_fm_agent_delegate_usage` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent a2a-card` | (default) | `test_fm_agent_a2a_card` | `run:agent-a2a-card` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent a2a-card` | --json / -j | `test_fm_agent_a2a_card_json` | `run:agent-a2a-card-json` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent a2a-card` | --validate / --strict / -s | `test_fm_agent_a2a_card_validate` | `run:agent-a2a-card-validate` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent conformance` | (default) | `test_fm_agent_conformance` | `run:agent-conformance` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent conformance` | --json / -j, --strict / -s | `test_fm_agent_conformance_json` | `run:agent-conformance-json` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agent` | <unknown> (usage, exit 1) | `test_fm_agent_unknown` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## agents.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot agents list` | (default) | `test_fm_agents_list` | `run:agents-list` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents check` | (in sync, exit 0) | `test_fm_agents_check` | `run:agents-check` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents check` | (AGENTS.md missing or drifted, exit 1) | `test_fm_agents_check_drift` | `help:agents` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents render` | (writes AGENTS.md + harness stubs) | `test_fm_agents_render` | `help:agents` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents` | --help / -h / help | `test_fm_agents_help` | `help:agents` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents` | <unknown> (exit 1) | `test_fm_agents_unknown` | `help:agents` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## fleet.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot fleet` | (default = status) | `test_fm_fleet` | `run:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet` | --json / -j | `test_fm_fleet_json` | `run:fleet-json` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet status` | (default) | `test_fm_fleet_status` | `run:fleet-status` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet status` | --json / -j | `test_fm_fleet_status_json` | `run:fleet-status-json` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet status` | .chezmoidata.toml `node_id` / `namespace` fleet keys | `test_fm_config_fleet_node_id` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot fleet drift` | check (default) | `test_fm_fleet_drift` | `run:fleet-drift` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet drift` | history [count] | `test_fm_fleet_drift_history` | `run:fleet-drift-history` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet drift` | predict | `test_fm_fleet_drift_predict` | `run:fleet-drift-predict` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet drift` | <unknown> (exit 1) | `test_fm_fleet_drift_unknown` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet events` | [count] | `test_fm_fleet_events` | `run:fleet-events` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet events` | (no events recorded yet) | `test_fm_fleet_events_empty` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet namespace` | show (default) | `test_fm_fleet_namespace` | `run:fleet-namespace` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet ns` | alias of fleet namespace | `test_fm_fleet_ns_alias` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet namespace` | set <name> (writes .chezmoidata.toml) | `test_fm_fleet_namespace_set` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet namespace` | set <invalid> (exit 1) / set (no name, exit 1) / <unknown> (exit 1) | `test_fm_fleet_namespace_set_invalid` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet enforce` | status (default) | `test_fm_fleet_enforce` | `run:fleet-enforce` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet enforce` | set advisory\|strict (writes agent-profiles.json) | `test_fm_fleet_enforce_set` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet enforce` | set <invalid> (exit 1) / set (no mode, exit 1) / <unknown> (exit 1) | `test_fm_fleet_enforce_set_invalid` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | --dry-run / -n | `test_fm_fleet_apply_dry_run` | `run:fleet-apply-dry-run` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | --host <name>, --cmd <shell>, --jobs / -j <n> | `test_fm_fleet_apply_host_cmd` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | --host <unknown> (exit 1) / unknown flag (exit 1) | `test_fm_fleet_apply_host_unknown` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | --verify-hosts | `test_fm_fleet_apply_verify_hosts` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | (no fleet.toml, exit 1) | `test_fm_fleet_apply_no_hosts` | `run:fleet-apply-nohosts` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | --help / -h | `test_fm_fleet_apply_help` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | (real SSH fan-out) | `test_fm_smoke_fleet_apply_ssh` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — opens SSH connections to every registered host (network) |
| `dot fleet push` | alias of fleet apply | `test_fm_fleet_push_alias` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | DOTFILES_FLEET_HOSTS overrides the hosts file | `test_fm_env_dotfiles_fleet_hosts` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot fleet apply` | ~/.config/dotfiles/fleet.toml `[hosts.<name>]` ssh / profile | `test_fm_config_fleet_toml` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot fleet` | <unknown> (prints command list) | `test_fm_fleet_unknown` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## registry.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot registry list` | (default) | `test_fm_registry_list` | `run:registry-list` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry list` | (registry with no modules) | `test_fm_registry_list_empty` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry search` | <q> | `test_fm_registry_search` | `run:registry-search` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry search` | (no query, exit 1) | `test_fm_registry_search_usage` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry info` | <name> | `test_fm_registry_info` | `run:registry-info` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry info` | <unknown> (exit 1) / missing name (exit 1) | `test_fm_registry_info_unknown` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` | <name> (preview) / --dry-run / -n | `test_fm_registry_install_dry_run` | `run:registry-install-dry-run` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` | <name> --yes / -y (verifies sha256, applies) | `test_fm_registry_install_yes` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` | missing name (exit 1) / unknown module (exit 1) / unknown option (exit 2) | `test_fm_registry_install_errors` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` | rejects an archive whose sha256 does not match (exit 1) | `test_fm_registry_install_sha_mismatch` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry installed` | (default) | `test_fm_registry_installed` | `run:registry-installed` | `examples/example-dot-registry.sh` | `docs/manual/command-index.md` | regression |
| `dot registry url` | (default) | `test_fm_registry_url` | `run:registry-url` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry set-url` | <https-or-file url> (writes registry.toml) | `test_fm_registry_set_url` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry set-url` | rejects non-https (exit 1) / missing url (exit 1) | `test_fm_registry_set_url_invalid` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry url` | DOTFILES_REGISTRY_URL one-shot override | `test_fm_env_dotfiles_registry_url` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot registry url` | ~/.config/dotfiles/registry.toml `url` key | `test_fm_config_registry_toml` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot registry` | --help / -h / help | `test_fm_registry_help` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry` | <unknown> (exit 1) | `test_fm_registry_unknown` | `help:registry` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## patterns.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot patterns list` | (default) | `test_fm_patterns_list` | `run:patterns-list` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns view` | <name> | `test_fm_patterns_view` | `run:patterns-view` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns view` | (no name, exit 1) / unknown pattern | `test_fm_patterns_view_missing` | `help:patterns` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns edit` | <name> (opens $EDITOR) | `test_fm_patterns_edit` | `help:patterns` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns edit` | (no name, exit 1) | `test_fm_patterns_edit_missing` | `help:patterns` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns` | <unknown> (usage, exit 1) | `test_fm_patterns_unknown` | `help:patterns` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns list` | XDG_CONFIG_HOME/ai/patterns is the pattern directory | `test_fm_env_xdg_config_home` | `help:patterns` | `examples/example-dot-patterns.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## completion.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot completion` | bash | `test_fm_completion_bash` | `run:completion-bash` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` | zsh | `test_fm_completion_zsh` | `run:completion-zsh` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` | fish | `test_fm_completion_fish` | `run:completion-fish` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` | nu / nushell | `test_fm_completion_nu` | `run:completion-nu` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` | (no shell prints usage) / --help | `test_fm_completion_usage` | `run:completion-usage` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` | <unknown shell> (exit 1) | `test_fm_completion_unknown` | `help:completion` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |

## init.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot init` | <user> --dry-run / -n | `test_fm_init_dry_run` | `run:init-dry-run` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` | <owner/repo> shorthand | `test_fm_init_owner_repo` | `help:init` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` | <https url> --no-apply | `test_fm_init_url_no_apply` | `help:init` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` | rejects plain http:// (exit 2) / invalid characters (exit 2) | `test_fm_init_reject_http` | `help:init` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` | missing target (exit 1) / unknown flag (exit 1) / too many args (exit 1) | `test_fm_init_usage` | `run:init-usage` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` | --help / -h | `test_fm_init_help` | `help:init` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` | <user> (clone + apply), --force / -f | `test_fm_smoke_init_apply` | `help:init` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | **smoke** — clones a remote repository and applies it over $HOME (network) |
| `dot init` | DOTFILES_NONINTERACTIVE=1 skips the trust confirmation | `test_fm_smoke_env_dotfiles_noninteractive` | `help:init` | `examples/example-dot-init.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — the prompt only fires on a TTY before a real clone (network) |

## manual.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot manual` | text --offline (pipes to $PAGER) | `test_fm_manual_text_offline` | `run:manual-text-offline` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` | download <fmt> --offline | `test_fm_manual_download_offline` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` | --offline with no offline copy (exit 1) / --local with no build (exit 1) | `test_fm_manual_offline_missing` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` | --help / -h | `test_fm_manual_help` | `run:manual-help` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` | html / html-multi / pdf / epub / markdown (default open) | `test_fm_smoke_manual_open` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — downloads the manual and opens it in the desktop browser / viewer (network, GUI) |
| `dot manual` | DOTFILES_MANUAL_URL / --url= override the download base | `test_fm_smoke_env_dotfiles_manual_url` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — only exercised on the network download path |
| `dot manual` | XDG_DATA_HOME/dotfiles/manual holds the offline copy | `test_fm_env_xdg_data_home` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot manual` | PAGER receives the text manual | `test_fm_env_pager` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## cross-cutting invariants

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot ai` | every provider routed to ai.sh has a bridge row | `test_fm_ai_bridge_every_routed_provider_refuses` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot completion` | every dialect covers the command registry | `test_fm_completion_covers_the_registry` | `run:completion-bash` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot fleet apply` | an injection-shaped ssh target aborts the fan-out | `test_fm_fleet_apply_rejects_injection_hostname` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` | no default-mode command prints a stored value | `test_fm_secrets_never_leak_by_default` | `help:secrets` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot firewall` | no security --help invokes sudo | `test_fm_security_help_does_not_mutate` | `help:firewall` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |

## Rows recorded as unmeasurable

Each of these has a `--help` smoke test, so none is fully uncovered. They are
listed together here so the reasons can be audited in one place rather than
hunted through the table.

| Command | Variant | Why it cannot be measured in CI |
|---------|---------|----------------------------------|
| `dot uninstall` | (prompts unless --force) | destructive — removes the managed environment from $HOME; only --help is exercised |
| `dot uninstall` | --force | destructive — --force skips the confirmation and purges real files |
| `dot doctor` | --benchmark / -b | runs tests/benchmark.sh (hyperfine over every shell, minutes) — covered by benches/bench.sh |
| `dot health` | --fix / -f, --force / -F | --fix re-applies chezmoi and rewrites shell configs in $HOME |
| `dot rollback` | rollback / rollback-to N / git-reset / restore FILE (--force, --dry-run, --verbose) | rewrites $HOME dotfiles from a backup and resets the git checkout |
| `dot load-bench-pty` | (default) | needs the chezmoi-rendered dot-load-benchmark-pty template and a pseudo-terminal |
| `dot chaos` | --force | deliberately deletes ~/.zshrc and terminal configs |
| `dot teleport` | user@host | opens an SSH session to a remote host (network) |
| `dot bundle` | [output-dir] | archives ~/.dotfiles plus tool caches with zstd (hundreds of MB, minutes) |
| `dot ai` | (default cockpit TUI) | launches the Bubble Tea cockpit / gum launcher (interactive TTY) |
| `dot ai tools` | install (alias of ai install) | installs AI CLIs through mise/native installers (network, mutates $HOME) |
| `dot ai run` | "<prompt>" one-shot on Claude | performs a paid LLM round-trip (network) |
| `dot ai` | "<prompt>" / <tool> "<prompt>" one-shot | performs a paid LLM round-trip (network) |
| `dot ai delegate` | "<prompt>" [max-turns] [agent] [timeout] | delegates to a paid model under agent policy (network) |
| `dot ai ask` | "<question>" RAG query | embeds the repo and calls an LLM (network) |
| `dot ai chat` | [tool] | starts an interactive AI session (TTY) |
| `dot ai install` | [tool] | installs AI CLIs (network, mutates $HOME) |
| `dot ai serve` | (default) | starts a long-running local gateway process bound to a port |
| `dot ai login` | (default) | interactive OAuth / API-key prompts (TTY, network) |
| `dot ai` | dashboard / dash (deprecated cockpit alias) | launches the cockpit TUI (interactive TTY) |
| `dot ai-setup` | deprecated alias of ai login | interactive tool authentication (TTY, network) |
| `dot cl` | "<prompt>" with an installed tool | performs a paid LLM round-trip (network) |
| `dot env` | prune --yes / -y | uninstalls orphan tool versions from the real mise store |
| `dot env` | install [tool@version] | downloads and installs toolchains through mise (network) |
| `dot env` | use <tool@version> | rewrites the user's mise config and installs tools (network) |
| `dot tools` | install (Nix develop shell) | enters an interactive `nix develop` shell (TTY, network) |
| `dot setup` | (interactive gum wizard) | interactive gum selection wizard (TTY) |
| `dot theme` | set <name> / light / dark | switches the OS appearance and rewrites terminal configs (osascript / gsettings) |
| `dot theme` | toggle | switches the OS appearance (system mutation) |
| `dot theme` | sync | rewrites terminal configs to follow the OS appearance (system mutation) |
| `dot theme` | family | cycles the theme family and applies it (system mutation) |
| `dot theme` | rebuild | regenerates every theme from wallpapers (minutes of image processing) |
| `dot wallpaper` | (default = sync) | sets the desktop wallpaper through osascript / feh (system mutation) |
| `dot wallpaper` | sync | sets the desktop wallpaper (system mutation) |
| `dot wallpaper` | rotate (--interval, --once, --light, --dark) | sets the desktop wallpaper (system mutation) |
| `dot fonts` | (default = install) | downloads and installs Nerd Fonts into the user font directory (network) |
| `dot fonts` | install [font] | downloads and installs Nerd Fonts (network) |
| `dot tune` | (default) | writes OS defaults / sysctl values (system mutation, sudo) |
| `dot secrets` | set <KEY> (prompts for the value) | reads the secret value from an interactive silent prompt (TTY) |
| `dot ssh-cert` | issue [--ttl] [--principal] / revoke | contacts a step-ca server and rewrites ~/.ssh certificates (network) |
| `dot firewall` | (default) | enables the OS firewall with sudo (system mutation) |
| `dot telemetry` | DOTFILES_TELEMETRY=1 | disables OS telemetry services with sudo (system mutation) |
| `dot dns-doh` | (default) | rewrites the system resolver configuration with sudo (system mutation) |
| `dot lock-screen` | (default) | writes screensaver / idle-lock OS settings (system mutation) |
| `dot usb-safety` | (default) | writes udev / automount policy with sudo (system mutation) |
| `dot upgrade` | (default) | runs nix flake update, chezmoi update, and a headless Neovim plugin sync (network, mutates $HOME) |
| `dot upgrade` | DOTFILES_FONTS=1 adds the Nerd Font step to upgrade | only observable inside the real upgrade run (network) |
| `dot sandbox` | (default) | builds and runs a Docker/Podman image interactively (network, TTY) |
| `dot fleet apply` | (real SSH fan-out) | opens SSH connections to every registered host (network) |
| `dot init` | <user> (clone + apply), --force / -f | clones a remote repository and applies it over $HOME (network) |
| `dot init` | DOTFILES_NONINTERACTIVE=1 skips the trust confirmation | the prompt only fires on a TTY before a real clone (network) |
| `dot manual` | html / html-multi / pdf / epub / markdown (default open) | downloads the manual and opens it in the desktop browser / viewer (network, GUI) |
| `dot manual` | DOTFILES_MANUAL_URL / --url= override the download base | only exercised on the network download path |

## Findings this matrix produced

Building the coverage turned up defects in the CLI. Each is exercised by the
row that found it, commented at that row, and reported rather than silently
accommodated. None is fixed here — `bin/dot`'s command modules and
`scripts/diagnostics/` belong to other work.

| Severity | Where | What |
|----------|-------|------|
| Medium | `scripts/dot/commands/registry.sh` | The registry index cache lives at one fixed path and is treated as fresh for six hours regardless of which URL produced it, so changing `DOTFILES_REGISTRY_URL` keeps serving the previous registry's index. |
| Medium | `scripts/diagnostics/doctor-unified.sh` | `dot doctor --audit` routes to `scripts/ops/health-check.sh`, which is not in the tree; the flag dies with "Script not found". |
| Medium | `scripts/dot/commands/tools.sh` | `dot tools docs` looks for `docs/TOOLS.md` / `docs/UTILS.md`; both live under `docs/reference/`, so the subcommand reports "TOOLS.md not found" on a complete checkout. |
| Low | `scripts/dot/commands/meta.sh` | A bare `dot keys` falls back to `scripts/diagnostics/keys.sh`, which does not exist, when `docs/KEYS.md` is absent — and `docs/KEYS.md` is not in the tree. |
| Low | `scripts/lib/secrets_provider.sh` | The `plain-enc` store aborts with `tmp_rec: unbound variable` under `set -u` *after* writing the encrypted file, so `dot secrets set` exits non-zero on a write that in fact succeeded. |
| Note | `scripts/dot/commands/env-emit.sh` | The `-h\|--help` arm of `dot_env_emit` is unreachable through the CLI: the dispatcher's universal `--help` intercept fires first and renders `dot help env`. Working as designed, but the sub-handler's usage text can only be read in the source. |

### Commands that write into the checkout

Three commands resolve their write target from the location of the sourced
library rather than from `$HOME`, so a sandboxed `HOME` does not protect a
working tree from them. The regression rows for these drive a throwaway copy
of the repo instead, and then assert the checkout is still clean:

- `dot profile set` → `defaults/.chezmoidata.toml`
- `dot fleet namespace set` → `defaults/.chezmoidata.toml`
- `dot fleet enforce set` → `defaults/dot_config/dotfiles/agent-profiles.json`
- `dot aliases cheatsheet` (no `--output`) → `docs/ALIASES_CHEATSHEET.md`
- `dot theme set` → `defaults/.chezmoidata.toml`, **and** the OS appearance

## See also

- `docs/manual/command-index.md` — generated index of every routable command
- `docs/manual/03-reference/01-dot-cli.md` — the CLI reference
- `docs/manual/03-reference/02-config-files.md` — config file schemas
- `docs/manual/03-reference/03-environment.md` — environment variables
- `CONTRIBUTING.md` — the "Regression tests" trace-header convention

