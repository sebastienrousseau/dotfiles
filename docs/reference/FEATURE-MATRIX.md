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

- a command routed by `lib/dot/data/routes.txt`, or listed in
  `docs/manual/command-index.md` (old names included), has no row here;
- a row names a command that is neither routed nor listed there;
- a row names a regression test function that no
  `tests/regression/test_feature_matrix_*.sh` file defines, or that its file
  never calls;
- a row names a benchmark id that
  `benches/dot_command_bench.sh --list-ids` does not produce, or a routed
  command has no `help:<cmd>` cold-start benchmark;
- a row names an example file that does not exist under `examples/`.

So a new subcommand cannot merge without coverage, and coverage cannot be
deleted without the matrix going red.

## Totals

The gate prints the current row and command counts. Two things hold for
every row:

- it names a benchmark and a runnable example;
- it is either `regression` (exercised end to end against the real CLI in a
  sandboxed `HOME`) or `smoke`.

A `smoke` row is one where the feature genuinely cannot be measured without
changing the developer's machine, spending money on a model, or holding a
terminal open. Its Coverage cell records the reason, and it still carries an
integration smoke test asserting that `dot <command> --help` exits 0 and
renders help for the right command without performing the command.

## How to run the coverage this table names

```bash
# The regression rows (all of them):
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
| Command | The `dot` command. A row still keyed by a name removed in 0.2.538 reads `` `dot old` → `dot new` ``: the old name now exits 127 and names its replacement, and the regression test runs the new spelling. The gate keeps these rows because `docs/manual/command-index.md` still lists the old names. Their Variant cell keeps the old subcommand wording. |
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
| `dot search` → `dot help` | <keyword> | `test_fm_search` | `run:search` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot search` → `dot help` | (no keyword, exit 1) | `test_fm_search_missing_keyword` | `run:search-usage` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot search` → `dot help` | <keyword> with no match | `test_fm_search_no_match` | `run:search-nomatch` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | unknown command (exit 1) | `test_fm_unknown_command` | `run:unknown-command` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | ~/.config/dotfiles/commands/<name>.sh user command (with DOT_ALLOW_PATH_PLUGINS=1) | `test_fm_user_custom_command` | `run:user-command` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot help` | DOTFILES_SHOW_LOGO=0 suppresses the product banner | `test_fm_env_dotfiles_show_logo` | `run:version-nologo` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot help` | NO_COLOR=1 strips ANSI from non-TTY output | `test_fm_env_no_color` | `help:version` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## core.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot sync` | (default, --check/--pull passthrough) | `test_fm_sync` | `run:sync-check` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot apply` | alias of sync | `test_fm_apply` | `run:apply-dry-run` | `examples/example-dot-core.sh` | `docs/manual/command-index.md` | regression |
| `dot update` | alias (chezmoi update) | `test_fm_update` | `run:update` | `examples/example-dot-core.sh` | `docs/manual/command-index.md` | regression |
| `dot add` → `dot config add` | <file> | `test_fm_add` | `run:add` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot add` → `dot config add` | (no file, exit 1) | `test_fm_add_usage` | `run:add-usage` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot diff` | (default) | `test_fm_diff` | `run:diff` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot status` | (clean tree) | `test_fm_status` | `run:status` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot status` | (drifted tree passthrough) | `test_fm_status_drift` | `help:config` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot cd` | (default) | `test_fm_cd` | `run:cd` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot edit` | (honours $EDITOR) | `test_fm_edit` | `run:edit` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot edit` | EDITOR env selects the editor | `test_fm_env_editor` | `help:config` | `examples/example-dot-core.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot commit` → `dot config save` | (no staged changes, exit 1) | `test_fm_commit` | `run:commit` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot uninstall` → `dot config uninstall` | (prompts unless --force; declining deletes nothing) | `test_fm_uninstall_declined` | `help:config` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot uninstall` → `dot config uninstall` | --force (removes every managed path, keeps the age key and unmanaged files) | `test_fm_uninstall_force` | `help:config` | `examples/example-dot-core.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## diagnostics.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot cli` | --help (domain commands) | `test_fm_domain_cli` | `help:cli` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot config` | --help (domain commands) | `test_fm_domain_config` | `help:config` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot secret` | --help (domain commands) | `test_fm_domain_secret` | `help:secret` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot security` | --help (domain commands) | `test_fm_domain_security` | `help:security` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot session` | --help (domain commands) | `test_fm_domain_session` | `help:session` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot shell` | --help (domain commands) | `test_fm_domain_shell` | `help:shell` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot system` | --help (domain commands) | `test_fm_domain_system` | `help:system` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot tool` | --help (domain commands) | `test_fm_domain_tool` | `help:tool` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot top` | --help (domain commands) | `test_fm_domain_top` | `help:top` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot ui` | --help (domain commands) | `test_fm_domain_ui` | `help:ui` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot doctor` | (default) | `test_fm_doctor` | `run:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --score / -s | `test_fm_doctor_score` | `run:doctor-score` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --smoke / -m | `test_fm_doctor_smoke` | `run:doctor-smoke` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --drift / -d | `test_fm_doctor_drift` | `run:doctor-drift` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --heal / -H | `test_fm_doctor_heal` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --audit / -a | `test_fm_doctor_audit` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --json / -j, --ai / -A passthrough | `test_fm_doctor_json` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot doctor` | --benchmark / -b | `test_fm_smoke_doctor_benchmark` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — runs tests/benchmark.sh (hyperfine over every shell, minutes) — covered by benches/bench.sh |
| `dot heal` → `dot doctor fix` | (default) | `test_fm_heal` | `run:heal` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot heal` → `dot doctor fix` | --dry-run / -n | `test_fm_heal_dry_run` | `run:heal-dry-run` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot health` → `dot doctor status` | (default) | `test_fm_health` | `run:health` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health` → `dot doctor status` | --json / -j | `test_fm_health_json` | `run:health-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health` → `dot doctor status` | --verbose / -v (accepted for old scripts; every check is always shown) | `test_fm_health_verbose` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health-check` (retired: exits 127 naming `dot doctor`) | alias of health | `test_fm_health_check_alias` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot health` → `dot doctor status` | --fix / -f, --force / -F | `test_fm_smoke_health_fix` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | **smoke** — --fix re-applies chezmoi and rewrites shell configs in $HOME |
| `dot security-score` → `dot security score show` | (default) | `test_fm_security_score` | `run:security-score` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot security-score` → `dot security score show` | --json / -j | `test_fm_security_score_json` | `run:security-score-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot security-score` → `dot security score show` | --quiet / -q, --verbose / -v | `test_fm_security_score_quiet` | `help:security` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot score` → `dot doctor score` | (default) | `test_fm_score` | `run:score` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot score` → `dot doctor score` | --json / -j | `test_fm_score_json` | `run:score-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot scorecard` → `dot doctor score show` | alias of score | `test_fm_scorecard` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot perf` → `dot doctor perf show` | --json / -j, --runs / -r | `test_fm_perf_json` | `run:perf` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot perf` → `dot doctor perf show` | --profile / -p, --target / -t, --shell / -s, --by-tool, --reset, --baseline, --no-baseline-check | `test_fm_perf_profile` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot conflicts` → `dot doctor conflict list` | (default) | `test_fm_conflicts` | `run:conflicts` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot locks` → `dot tool list --locked` | (default) | `test_fm_locks` | `run:locks` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot snapshot` → `dot doctor snapshot new` | (default) | `test_fm_snapshot` | `run:snapshot` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot snapshot` → `dot doctor snapshot new` | --baseline / -b, --force / -f | `test_fm_snapshot_baseline` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot snapshot` → `dot doctor snapshot new` | XDG_STATE_HOME controls where snapshots/attestations are written | `test_fm_env_xdg_state_home` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot attest` | (default) | `test_fm_attest` | `run:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attest` | --json / -j | `test_fm_attest_json` | `run:attest-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attest` | --write / -w | `test_fm_attest_write` | `help:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attest` | --fleet-store / -F <dir>, --fleet-id / -I <id> | `test_fm_attest_fleet_store` | `help:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot attestation` → `dot attest` | alias of attest | `test_fm_attestation` | `help:attest` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot rollback` → `dot doctor rollback` | status | `test_fm_rollback_status` | `run:rollback-status` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` → `dot doctor rollback` | backup | `test_fm_rollback_backup` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` → `dot doctor rollback` | clean | `test_fm_rollback_clean` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` → `dot doctor rollback` | <unknown> (usage, exit 1) | `test_fm_rollback_unknown` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` → `dot doctor rollback` | rollback / rollback-to N / restore FILE (--force, flags before or after the argument) | `test_fm_rollback_restore_paths` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot rollback` → `dot doctor rollback` | git-reset --force stashes all changes (untracked too) and keeps the old HEAD on rollback-backup/* | `test_fm_rollback_git_reset_keeps_work` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot drift` → `dot doctor drift show` | (default) | `test_fm_drift` | `run:drift` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot drift` → `dot doctor drift show` | --json / -j, --diff / -d | `test_fm_drift_json` | `run:drift-json` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot history` → `dot shell history list` | (default, reads $HISTFILE) | `test_fm_history` | `run:history` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot history` → `dot shell history list` | (no history file, exit 1) | `test_fm_history_missing` | `help:shell` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot history` → `dot shell history list` | HISTFILE selects the shell history analysed | `test_fm_env_histfile` | `help:shell` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot benchmark` → `dot doctor perf measure` | (default, --detailed, --profile, --compare, --waterfall) | `test_fm_benchmark` | `run:benchmark` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` → `dot doctor restore` | --list / -l | `test_fm_restore_list` | `run:restore-list` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` → `dot doctor restore` | --git / -g <ref> with --dry-run / -n | `test_fm_restore_git_dry_run` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` → `dot doctor restore` | --diff / -d <ref> | `test_fm_restore_diff` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` → `dot doctor restore` | --latest / -L | `test_fm_restore_latest` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` → `dot doctor restore` | (no option prints usage), --help / -h, unknown option (exit 1) | `test_fm_restore_usage` | `run:restore-usage` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot restore` → `dot doctor restore` | DOTFILES_DIR selects the git checkout restore reads | `test_fm_env_dotfiles_dir` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot load-bench` → `dot doctor perf --ready` | (default, runs count) | `test_fm_load_bench` | `run:load-bench` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot load-bench-pty` → `dot doctor perf --ready --pty` | (default) | `test_fm_smoke_load_bench_pty` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | **smoke** — needs the chezmoi-rendered dot-load-benchmark-pty template and a pseudo-terminal |
| `dot chaos` (retired: exits 127 naming `dot doctor`) | (refuses without --force) | `test_fm_chaos` | `run:chaos` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot chaos` (retired: exits 127 naming `dot doctor`) | --force (deletes its three targets, plants a broken symlink, spares the rest) | `test_fm_chaos_force` | `help:chaos` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot teleport` → `dot fleet push` | user@host | `test_fm_smoke_teleport` | `help:fleet` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | **smoke** — opens an SSH session to a remote host (network) |
| `dot teleport` → `dot fleet push` | (no host, exit 1) | `test_fm_teleport_usage` | `run:teleport-usage` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot bundle` → `dot config export` | [output-dir] | `test_fm_smoke_bundle` | `help:config` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — archives the checkout plus tool caches with zstd (hundreds of MB, minutes) |
| `dot secret-audit` → `dot secret check` | (default) | `test_fm_secret_audit` | `run:secret-audit` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot metrics` → `dot doctor metric list` | [count] | `test_fm_metrics` | `run:metrics` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot metrics` → `dot doctor metric list` | (no metrics recorded yet) | `test_fm_metrics_empty` | `help:doctor` | `examples/example-dot-diagnostics.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot smoke-test` (retired: exits 127 naming `dot doctor`) | (default) | `test_fm_smoke_test` | `run:smoke-test` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |
| `dot intelligence` → `dot top` | (default) | `test_fm_intelligence` | `run:intelligence` | `examples/example-dot-diagnostics.sh` | `docs/manual/command-index.md` | regression |

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
| `dot ai install` | (no terminal, no --yes) asks first, so an unattended bulk install installs nothing | `test_fm_ai_install_unattended_installs_nothing` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai install` | --yes / DOTFILES_YES=1 installs prerequisites and tools without asking | `test_fm_ai_install_yes_flag` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot ai serve` | (default) start + fleet routing with the generated token; gateway refuses a missing token and a foreign Host; stop | `test_fm_ai_serve_gateway` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai login` | (default) | `test_fm_smoke_ai_login` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — interactive OAuth / API-key prompts (TTY, network) |
| `dot ai` | dashboard / dash (deprecated cockpit alias) | `test_fm_smoke_ai_dashboard` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — launches the cockpit TUI (interactive TTY) |
| `dot ai` | proxy / local (deprecated alias of ai serve) | `test_fm_ai_proxy_deprecated` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ai-setup` → `dot ai install --interactive` | guided AI tool setup | `test_fm_smoke_ai_setup` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — interactive tool authentication (TTY, network) |
| `dot ai-query` → `dot ai ask` | deprecated alias of ai ask (usage without question) | `test_fm_ai_query_usage` | `run:ai-query-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot cl` → `dot ai run claude` | (usage without prompt; deprecated bridge) | `test_fm_ai_bridge_cl` | `run:cl-usage` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot claude` → `dot ai run claude` | alias of cl | `test_fm_ai_bridge_claude` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot codex` → `dot ai run codex` | (usage without prompt) | `test_fm_ai_bridge_codex` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot copilot` → `dot ai run copilot` | (usage without prompt) | `test_fm_ai_bridge_copilot` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot kimi` → `dot ai run kimi` | (usage without prompt) | `test_fm_ai_bridge_kimi` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agy` → `dot ai run agy` | (usage without prompt) | `test_fm_ai_bridge_agy` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot goose` → `dot ai run goose` | (usage without prompt) | `test_fm_ai_bridge_goose` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot kiro` → `dot ai run kiro` | (usage without prompt) | `test_fm_ai_bridge_kiro` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot sgpt` → `dot ai run sgpt` | (usage without prompt) | `test_fm_ai_bridge_sgpt` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ollama` → `dot ai run ollama` | (usage without prompt) | `test_fm_ai_bridge_ollama` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot opencode` → `dot ai run opencode` | (usage without prompt) | `test_fm_ai_bridge_opencode` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot aider` → `dot ai run aider` | (usage without prompt) | `test_fm_ai_bridge_aider` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot autohand` → `dot ai run autohand` | (usage without prompt) | `test_fm_ai_bridge_autohand` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot vibe` → `dot ai run vibe` | (usage without prompt) | `test_fm_ai_bridge_vibe` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot qwen` → `dot ai run qwen` | (usage without prompt) | `test_fm_ai_bridge_qwen` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot zai` → `dot ai run zai` | (usage without prompt) | `test_fm_ai_bridge_zai` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/command-index.md` | regression |
| `dot cl` → `dot ai run claude` | --style / --pattern / -p <name> (unknown pattern exits 1) | `test_fm_ai_bridge_style` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot cl` → `dot ai run claude` | "<prompt>" with an installed tool | `test_fm_smoke_ai_bridge_prompt` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — performs a paid LLM round-trip (network) |
| `dot cl` → `dot ai run claude` | DOT_AI_RAW=1 suppresses the banner and metadata preamble | `test_fm_env_dot_ai_raw` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## tools.sh / aliases.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot env` → `dot tool list` | list / ls (default; requires mise) | `test_fm_env_list` | `run:env-list` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool remove` | prune (dry-run; requires mise) | `test_fm_env_prune` | `help:tool` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool remove` | prune --yes / -y | `test_fm_smoke_env_prune_yes` | `help:tool` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — uninstalls orphan tool versions from the real mise store |
| `dot env` → `dot tool install` | install [tool@version] | `test_fm_smoke_env_install` | `help:tool` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — downloads and installs toolchains through mise (network) |
| `dot env` → `dot tool set` | use <tool@version> | `test_fm_smoke_env_use` | `help:tool` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — rewrites the user's mise config and installs tools (network) |
| `dot env` → `dot tool export` | emit (default json, --pretty) | `test_fm_env_emit` | `run:env-emit` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool export` | emit --compact | `test_fm_env_emit_compact` | `help:tool` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool export` | emit --format ndjson / --format=ndjson | `test_fm_env_emit_ndjson` | `help:tool` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool export` | emit --output / -o <file> (atomic write) | `test_fm_env_emit_output` | `help:tool` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool export` | emit --format <unsupported> (exit 1) | `test_fm_env_emit_bad_format` | `help:tool` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool export` | emit <unknown flag> (exit 1) | `test_fm_env_emit_bad_flag` | `help:tool` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot tool export` | emit --help / -h | `test_fm_env_emit_help` | `help:tool` | `examples/example-dot-env-emit.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` → `dot config profile show` | show (default) | `test_fm_profile_show` | `run:profile-show` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` → `dot config profile set` | set <name> (writes ~/.config/chezmoi/chezmoi.toml) | `test_fm_profile_set` | `help:config` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` → `dot config profile set` | set (no name, exit 1) | `test_fm_profile_set_usage` | `help:config` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` → `dot config profile` | <unknown> (exit 1) | `test_fm_profile_unknown` | `help:config` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot profile` → `dot config profile show` | .chezmoidata.toml `profile` + `[features]` keys | `test_fm_config_chezmoidata_profile` | `help:config` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot tools` → `dot tool list --nix` | (default overview) | `test_fm_tools` | `run:tools` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot tools` → `dot tool list --nix` | docs | `test_fm_tools_docs` | `run:tools-docs` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot tools` → `dot tool list --nix` | install (Nix develop shell) | `test_fm_smoke_tools_install` | `help:tool` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | **smoke** — enters an interactive `nix develop` shell (TTY, network) |
| `dot new` → `dot tool new` | <lang> <name> | `test_fm_new` | `help:tool` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot new` → `dot tool new` | (no args, exit 1) / unknown template (exit 1) | `test_fm_new_usage` | `run:new-usage` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |
| `dot packages` → `dot tool list --packages` | (default) | `test_fm_packages` | `run:packages` | `examples/example-dot-tools.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot aliases` → `dot shell alias list` | list (default) | `test_fm_aliases_list` | `run:aliases-list` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias list` | search <term> | `test_fm_aliases_search` | `run:aliases-search` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias list` | search <term> with no match (exit 1) / missing term (exit 1) | `test_fm_aliases_search_nomatch` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias show` | why <alias> | `test_fm_aliases_why` | `run:aliases-why` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias show` | why <unknown> (exit 1) | `test_fm_aliases_why_unknown` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias status` | stats (reads $HISTFILE) | `test_fm_aliases_stats` | `run:aliases-stats` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias status` | stats (no history file, exit 1) | `test_fm_aliases_stats_missing` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias export` | cheatsheet --output / -o <path> | `test_fm_aliases_cheatsheet` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias export` | cheatsheet --output - | `test_fm_aliases_cheatsheet_stdout` | `run:aliases-cheatsheet` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias export` | cheatsheet (writes docs/ALIASES_CHEATSHEET.md in the source tree) | `test_fm_aliases_cheatsheet_default` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias status --tiers` | tiers | `test_fm_aliases_tiers` | `run:aliases-tiers` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot aliases` → `dot shell alias status --tiers` | DOTFILES_ALIAS_PROFILE / DOTFILES_ALIAS_ECOSYSTEMS / DOTFILES_ALIAS_BUCKETS / DOTFILES_SECURITY_MODE / DOTFILES_ENABLE_DANGEROUS_ALIASES | `test_fm_env_dotfiles_alias_tiers` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot aliases` → `dot shell alias` | <unknown> (exit 1) | `test_fm_aliases_unknown` | `help:shell` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot alias-check` → `dot shell alias check` | (default) | `test_fm_alias_check` | `run:alias-check` | `examples/example-dot-aliases.sh` | `docs/manual/command-index.md` | regression |
| `dot setup` → `dot config init` | (interactive gum wizard) | `test_fm_smoke_setup` | `help:config` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | **smoke** — interactive gum selection wizard (TTY) |
| `dot log-rotate` → `dot system clean --logs` | (default) | `test_fm_log_rotate` | `run:log-rotate` | `examples/example-dot-tools.sh` | `docs/manual/command-index.md` | regression |

## lint.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot lint` → `dot config check` | (default: shellcheck + shfmt report) | `test_fm_lint` | `help:config` | `examples/example-dot-lint.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot lint` → `dot config check` | --check / -c (exit 1 on findings) | `test_fm_lint_check` | `help:config` | `examples/example-dot-lint.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot lint` → `dot config check` | --fix / -f (rewrites files with shfmt) | `test_fm_lint_fix` | `help:config` | `examples/example-dot-lint.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

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
| `dot wallpaper` → `dot theme wallpaper set` | (default = sync) | `test_fm_smoke_wallpaper` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — sets the desktop wallpaper through osascript / feh (system mutation) |
| `dot wallpaper` → `dot theme wallpaper set` | sync | `test_fm_smoke_wallpaper_sync` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — sets the desktop wallpaper (system mutation) |
| `dot wallpaper` → `dot theme wallpaper set` | rotate (--interval, --once, --light, --dark) | `test_fm_smoke_wallpaper_rotate` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — sets the desktop wallpaper (system mutation) |
| `dot fonts` → `dot theme font install` | (default = install) | `test_fm_smoke_fonts` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — downloads and installs Nerd Fonts into the user font directory (network) |
| `dot fonts` → `dot theme font install` | install [font] | `test_fm_smoke_fonts_install` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — downloads and installs Nerd Fonts (network) |
| `dot fonts` → `dot theme font install` | patch <font-file> [output-dir] | `test_fm_fonts_patch_usage` | `help:theme` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | regression |
| `dot tune` → `dot system settings apply` | (default) | `test_fm_smoke_tune` | `help:system` | `examples/example-dot-appearance.sh` | `docs/manual/command-index.md` | **smoke** — writes OS defaults / sysctl values (system mutation, sudo) |

## secrets.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot secrets-init` → `dot secret init` | (default; creates the age key) | `test_fm_secrets_init` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret edit` | edit (default) | `test_fm_secrets_edit` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret edit` | edit without an age key (exit 1) | `test_fm_secrets_edit_no_key` | `run:secrets-edit-nokey` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret set` | set <KEY> <VALUE> | `test_fm_secrets_set` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret set` | set (no key, exit 1) | `test_fm_secrets_set_usage` | `run:secrets-set-usage` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret set` | set with an invalid key name (path separator, leading `-` or `.`) is refused (exit 1) | `test_fm_secrets_set_invalid_key` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret set` | set <KEY> (prompts for the value) | `test_fm_smoke_secrets_set_prompt` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — reads the secret value from an interactive silent prompt (TTY) |
| `dot secrets` → `dot secret set` | get <KEY> (masked) | `test_fm_secrets_get` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret set` | get <KEY> --raw | `test_fm_secrets_get_raw` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret show` | get <unknown> (exit 1) / get without key (exit 1) | `test_fm_secrets_get_missing` | `run:secrets-get-missing` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret list` | list | `test_fm_secrets_list` | `run:secrets-list` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret export` | load [bucket] (posix export lines) | `test_fm_secrets_load` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret export` | load --shell fish | `test_fm_secrets_load_fish` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret export` | load --shell=nu / nushell | `test_fm_secrets_load_nu` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret export` | load <bucket> with nothing stored (exit 1) / unknown flag (exit 1) | `test_fm_secrets_load_empty` | `run:secrets-load-empty` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret provider show` | provider | `test_fm_secrets_provider` | `run:secrets-provider` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret provider show` | DOTFILES_SECRETS_PROVIDER / DOT_SECRETS_HOME select the backend and store | `test_fm_env_dotfiles_secrets_provider` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot secrets` → `dot secret provider show` | .chezmoidata.toml `[secrets.policy] provider` / `auto_load` defaults | `test_fm_config_secrets_policy` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot secrets` → `dot secret` | <unknown> (exit 1) | `test_fm_secrets_unknown` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot env` → `dot secret export` | load [bucket] (secrets.sh alias of secrets load) | `test_fm_secrets_env_load` | `help:tool` | `examples/example-dot-secrets.sh` | `docs/manual/command-index.md` | regression |
| `dot secrets-create` → `dot secret new` | [name] (needs the age key) | `test_fm_secrets_create` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets-create` → `dot secret new` | without an age key (exit 1) | `test_fm_secrets_create_no_key` | `run:secrets-create-nokey` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-key` → `dot secret key new` | [key-path] (encrypts ~/.ssh/id_ed25519 with age) | `test_fm_ssh_key_missing` | `run:ssh-key-missing` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-cert` → `dot secret cert` | (usage) / status / issue / revoke | `test_fm_ssh_cert_usage` | `run:ssh-cert-usage` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-cert` → `dot secret cert list` | status | `test_fm_ssh_cert_status` | `run:ssh-cert-status` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot ssh-cert` → `dot secret cert new` | issue [--ttl] [--principal] / revoke | `test_fm_smoke_ssh_cert_issue` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — contacts a step-ca server and rewrites ~/.ssh certificates (network) |

## security.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot backup` → `dot doctor backup` | (default; DOTFILES_BACKUP_DIR / DOTFILES_BACKUP_SRC) | `test_fm_backup` | `help:doctor` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |
| `dot encrypt-check` → `dot security disk show` | (default) | `test_fm_encrypt_check` | `run:encrypt-check` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |
| `dot firewall` → `dot security firewall apply` | (default) | `test_fm_smoke_firewall` | `help:security` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — enables the OS firewall with sudo (system mutation) |
| `dot telemetry` → `dot security telemetry apply` | (refuses unless DOTFILES_TELEMETRY=1) | `test_fm_telemetry` | `run:telemetry` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |
| `dot telemetry` → `dot security telemetry apply` | DOTFILES_TELEMETRY=1 | `test_fm_smoke_telemetry_apply` | `help:security` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — disables OS telemetry services with sudo (system mutation) |
| `dot dns-doh` → `dot security dns apply` | (default) | `test_fm_smoke_dns_doh` | `help:security` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — rewrites the system resolver configuration with sudo (system mutation) |
| `dot lock-screen` → `dot security lock apply` | (default) | `test_fm_smoke_lock_screen` | `help:security` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — writes screensaver / idle-lock OS settings (system mutation) |
| `dot usb-safety` → `dot security usb apply` | (default) | `test_fm_smoke_usb_safety` | `help:security` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | **smoke** — writes udev / automount policy with sudo (system mutation) |
| `dot policy` → `dot security policy show` | (default; needs opa + gitleaks) | `test_fm_policy` | `run:policy` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |

## meta.sh / agent.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot upgrade` → `dot system update` | (default) | `test_fm_smoke_upgrade` | `help:system` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — runs nix flake update, chezmoi update, mise install + upgrade, a headless Neovim plugin sync, and (asked first) a system-package upgrade (network, mutates $HOME) |
| `dot upgrade` → `dot system update` | --yes / DOTFILES_YES=1 answers yes to installing mise and upgrading system packages | `test_fm_smoke_upgrade_yes` | `help:system` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — the consented phases install and upgrade software (network, mutates the system) |
| `dot upgrade` → `dot system update` | DOTFILES_FONTS=1 adds the Nerd Font step to upgrade | `test_fm_smoke_env_dotfiles_fonts` | `help:system` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — only observable inside the real upgrade run (network) |
| `dot cache-refresh` → `dot shell update` | (default) | `test_fm_cache_refresh` | `run:cache-refresh` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot clean-cache` → `dot shell clean` | (default) | `test_fm_clean_cache` | `help:shell` | `examples/example-command-reference.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot prewarm` → `dot shell update --prewarm` | alias of cache-refresh | `test_fm_prewarm` | `help:shell` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot cache-refresh` → `dot shell update` | XDG_CACHE_HOME receives the regenerated shell caches | `test_fm_env_xdg_cache_home` | `help:shell` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot docs` → `dot help --readme` | (default) | `test_fm_docs` | `run:docs` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot learn` → `dot help tour` | (interactive tour) | `test_fm_learn` | `run:learn` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot keys` (retired: exits 127 naming `dot doctor`) | (default catalog) | `test_fm_keys` | `run:keys` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot keys` (retired: exits 127 naming `dot doctor`) | sign-check | `test_fm_keys_sign_check` | `run:keys-sign-check` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot keys` (retired: exits 127 naming `dot doctor`) | sign-check with an ssh signing key configured | `test_fm_keys_sign_check_ssh` | `help:keys` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | regression |
| `dot sandbox` → `dot config apply --sandbox` | (default) | `test_fm_smoke_sandbox` | `help:config` | `examples/example-dot-meta.sh` | `docs/manual/command-index.md` | **smoke** — builds and runs a Docker/Podman image interactively (network, TTY) |
| `dot mcp` | (default = doctor) | `test_fm_mcp` | `run:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp doctor` | (default) | `test_fm_mcp_doctor` | `run:mcp-doctor` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp doctor` | --json / -j, --strict / -s | `test_fm_mcp_doctor_json` | `run:mcp-doctor-json` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp registry` | (default table) | `test_fm_mcp_registry` | `run:mcp-registry` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp registry` | --json / -j | `test_fm_mcp_registry_json` | `run:mcp-registry-json` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp registry` | MCP_REGISTRY_CONFIG overrides the registry file | `test_fm_env_mcp_registry_config` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot mcp registry` | dot_config/dotfiles/mcp-registry.json `servers` map | `test_fm_config_mcp_registry_json` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot mcp serve` | stdio MCP server: JSON-RPC 2.0 on stdin/stdout, EOF shuts down | `test_fm_mcp_serve` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mcp` | <unknown> (usage, exit 1) | `test_fm_mcp_unknown` | `help:mcp` | `examples/example-dot-meta.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode` → `dot agent mode` | (default = current) | `test_fm_mode` | `run:mode` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode list` → `dot agent mode list` | (default) | `test_fm_mode_list` | `run:mode-list` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode current` → `dot agent status` | (default) | `test_fm_mode_current` | `run:mode-current` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode show` → `dot agent mode show` | <profile> | `test_fm_mode_show` | `run:mode-show` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode show` → `dot agent mode show` | <unknown> (exit 1) / missing name (exit 1) | `test_fm_mode_show_unknown` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode set` → `dot agent mode set` | <profile> (writes agent-mode.env) | `test_fm_mode_set` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode set` → `dot agent mode set` | <unknown> (exit 1) | `test_fm_mode_set_unknown` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode set` → `dot agent mode set` | refused by strict RBAC enforcement (exit 1) | `test_fm_mode_set_rbac_strict` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode run` → `dot agent mode run` | [profile] <command> (checkpointed) | `test_fm_mode_run` | `run:mode-run` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode run` → `dot agent mode run` | (no command, exit 1) | `test_fm_mode_run_usage` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode run` → `dot agent mode run` | propagates the wrapped command's exit code | `test_fm_mode_run_exit_code` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode doctor` → `dot agent check` | (default) | `test_fm_mode_doctor` | `run:mode-doctor` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode` → `dot agent mode` | <unknown> (usage, exit 1) | `test_fm_mode_unknown` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot mode` → `dot agent mode show` | AGENT_PROFILE_CONFIG / AGENT_STATE_FILE override the profiles file and state file | `test_fm_env_agent_profile_config` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot mode` → `dot agent mode` | dot_config/dotfiles/agent-profiles.json `defaultProfile` / `profiles` / `rbac` / `delegation` | `test_fm_config_agent_profiles_json` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot mode` → `dot agent mode set` | ~/.config/dotfiles/agent-mode.env state file (DOT_AGENT_PROFILE …) | `test_fm_config_agent_mode_env` | `help:agent` | `examples/example-dot-agent.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
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
| `dot agents list` → `dot agent context show` | (default) | `test_fm_agents_list` | `run:agents-list` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents check` → `dot agent context check` | (in sync, exit 0) | `test_fm_agents_check` | `run:agents-check` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents check` → `dot agent context check` | (AGENTS.md missing or drifted, exit 1) | `test_fm_agents_check_drift` | `help:agent` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents render` → `dot agent context apply` | (writes AGENTS.md + harness stubs) | `test_fm_agents_render` | `help:agent` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents` → `dot agent context` | --help / -h / help | `test_fm_agents_help` | `help:agent` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot agents` → `dot agent context` | <unknown> (exit 1) | `test_fm_agents_unknown` | `help:agent` | `examples/example-dot-agents.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

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
| `dot fleet apply` | (SSH fan-out: one ssh per host, `--` before the target, keep-alives) | `test_fm_fleet_apply_ssh_fanout` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | --jobs 0 / non-numeric (usage error, exit 2) | `test_fm_fleet_apply_jobs_invalid` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | an ssh target starting with `-` or a host name containing `/` aborts the fan-out | `test_fm_fleet_apply_rejects_option_target` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet push` | alias of fleet apply | `test_fm_fleet_push_alias` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot fleet apply` | DOTFILES_FLEET_HOSTS overrides the hosts file | `test_fm_env_dotfiles_fleet_hosts` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot fleet apply` | ~/.config/dotfiles/fleet.toml `[hosts.<name>]` ssh / profile | `test_fm_config_fleet_toml` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot fleet` | <unknown> (prints command list) | `test_fm_fleet_unknown` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## registry.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot registry list` → `dot cli list --available` | (default) | `test_fm_registry_list` | `run:registry-list` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry list` → `dot cli list --available` | (registry with no modules) | `test_fm_registry_list_empty` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry search` → `dot cli list --available` | <q> | `test_fm_registry_search` | `run:registry-search` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry search` → `dot cli list --available` | (no query, exit 1) | `test_fm_registry_search_usage` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry info` → `dot cli show` | <name> | `test_fm_registry_info` | `run:registry-info` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry info` → `dot cli show` | <unknown> (exit 1) / missing name (exit 1) | `test_fm_registry_info_unknown` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` → `dot cli install` | <name> (preview) / --dry-run / -n | `test_fm_registry_install_dry_run` | `run:registry-install-dry-run` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` → `dot cli install` | <name> --yes / -y (verifies sha256, applies) | `test_fm_registry_install_yes` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` → `dot cli install` | missing name (exit 1) / unknown module (exit 1) / unknown option (exit 2) | `test_fm_registry_install_errors` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry install` → `dot cli install` | rejects an archive whose sha256 does not match (exit 1) | `test_fm_registry_install_sha_mismatch` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry installed` → `dot cli list` | (default) | `test_fm_registry_installed` | `run:registry-installed` | `examples/example-dot-registry.sh` | `docs/manual/command-index.md` | regression |
| `dot registry url` → `dot cli registry show` | (default) | `test_fm_registry_url` | `run:registry-url` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry set-url` → `dot cli registry set` | <https-or-file url> (writes registry.toml) | `test_fm_registry_set_url` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry set-url` → `dot cli registry set` | rejects non-https (exit 1) / missing url (exit 1) | `test_fm_registry_set_url_invalid` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry url` → `dot cli registry show` | DOTFILES_REGISTRY_URL one-shot override | `test_fm_env_dotfiles_registry_url` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot registry url` → `dot cli registry show` | ~/.config/dotfiles/registry.toml `url` key | `test_fm_config_registry_toml` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/02-config-files.md` | regression |
| `dot registry` → `dot cli list --available` | --help / -h / help | `test_fm_registry_help` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot registry` → `dot cli` | <unknown> (exit 1) | `test_fm_registry_unknown` | `help:cli` | `examples/example-dot-registry.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |

## patterns.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot patterns list` → `dot ai pattern list` | (default) | `test_fm_patterns_list` | `run:patterns-list` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns view` → `dot ai pattern show` | <name> | `test_fm_patterns_view` | `run:patterns-view` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns view` → `dot ai pattern show` | (no name, exit 1) / unknown pattern | `test_fm_patterns_view_missing` | `help:ai` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns edit` → `dot ai pattern edit` | <name> (opens $EDITOR) | `test_fm_patterns_edit` | `help:ai` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns edit` → `dot ai pattern edit` | (no name, exit 1) | `test_fm_patterns_edit_missing` | `help:ai` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns` → `dot ai pattern` | <unknown> (usage, exit 1) | `test_fm_patterns_unknown` | `help:ai` | `examples/example-dot-patterns.sh` | `docs/manual/command-index.md` | regression |
| `dot patterns list` → `dot ai pattern list` | XDG_CONFIG_HOME/ai/patterns is the pattern directory | `test_fm_env_xdg_config_home` | `help:ai` | `examples/example-dot-patterns.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## completion.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot completion` → `dot cli completion show` | bash | `test_fm_completion_bash` | `run:completion-bash` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` → `dot cli completion show` | zsh | `test_fm_completion_zsh` | `run:completion-zsh` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` → `dot cli completion show` | fish | `test_fm_completion_fish` | `run:completion-fish` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` → `dot cli completion show` | nu / nushell | `test_fm_completion_nu` | `run:completion-nu` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` → `dot cli completion show` | (no shell prints usage) / --help | `test_fm_completion_usage` | `run:completion-usage` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot completion` → `dot cli completion show` | <unknown shell> (exit 1) | `test_fm_completion_unknown` | `help:cli` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |

## init.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot init` → `dot config init` | <user> --dry-run / -n | `test_fm_init_dry_run` | `run:init-dry-run` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` → `dot config init` | <owner/repo> shorthand | `test_fm_init_owner_repo` | `help:config` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` → `dot config init` | <https url> --no-apply | `test_fm_init_url_no_apply` | `help:config` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` → `dot config init` | rejects plain http:// (exit 2) / invalid characters (exit 2) | `test_fm_init_reject_http` | `help:config` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` → `dot config init` | missing target (exit 1) / unknown flag (exit 1) / too many args (exit 1) | `test_fm_init_usage` | `run:init-usage` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` → `dot config init` | --help / -h | `test_fm_init_help` | `help:config` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | regression |
| `dot init` → `dot config init` | <user> (clone + apply), --force / -f | `test_fm_smoke_init_apply` | `help:config` | `examples/example-dot-init.sh` | `docs/manual/command-index.md` | **smoke** — clones a remote repository and applies it over $HOME (network) |
| `dot init` → `dot config init` | DOTFILES_NONINTERACTIVE=1 skips the trust confirmation | `test_fm_smoke_env_dotfiles_noninteractive` | `help:config` | `examples/example-dot-init.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — the prompt only fires on a TTY before a real clone (network) |

## manual.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot manual` → `dot help --manual` | text --offline (pipes to $PAGER) | `test_fm_manual_text_offline` | `run:manual-text-offline` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` → `dot help --manual` | download <fmt> --offline | `test_fm_manual_download_offline` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` → `dot help --manual` | --offline with no offline copy (exit 1) / --local with no build (exit 1) | `test_fm_manual_offline_missing` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` → `dot help --manual` | --help / -h | `test_fm_manual_help` | `run:manual-help` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot manual` → `dot help --manual` | html / html-multi / pdf / epub / markdown (default open) | `test_fm_smoke_manual_open` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/01-dot-cli.md` | **smoke** — downloads the manual and opens it in the desktop browser / viewer (network, GUI) |
| `dot manual` → `dot help --manual` | DOTFILES_MANUAL_URL / --url= override the download base | `test_fm_smoke_env_dotfiles_manual_url` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/03-environment.md` | **smoke** — only exercised on the network download path |
| `dot manual` → `dot help --manual` | XDG_DATA_HOME/dotfiles/manual holds the offline copy | `test_fm_env_xdg_data_home` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/03-environment.md` | regression |
| `dot manual` → `dot help --manual` | PAGER receives the text manual | `test_fm_env_pager` | `help:manual` | `examples/example-dot-manual.sh` | `docs/manual/03-reference/03-environment.md` | regression |

## system.sh

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot system` | (default) status: OS, disk, schedule, last run | `test_fm_system_status` | `run:system-status` | `examples/example-dot-system.sh` | `docs/operations/MAINTENANCE.md` | regression |
| `dot system schedule` | (default) list | `test_fm_system_schedule_list` | `run:system-schedule-list` | `examples/example-dot-system.sh` | `docs/operations/MAINTENANCE.md` | regression |
| `dot system schedule set` | weekly / daily / off (bad word exits 1) | `test_fm_system_schedule_set` | `help:system` | `examples/example-dot-system.sh` | `docs/operations/MAINTENANCE.md` | regression |
| `dot system schedule run` | clears caches, rotates logs, records the exit code | `test_fm_system_schedule_run` | `help:system` | `examples/example-dot-system.sh` | `docs/operations/MAINTENANCE.md` | regression |

## cross-cutting invariants

| Command | Variant | Regression test | Benchmark | Example | Manual | Coverage |
|---------|---------|-----------------|-----------|---------|--------|----------|
| `dot ai` | every provider routed to ai.sh has a bridge row | `test_fm_ai_bridge_every_routed_provider_refuses` | `help:ai` | `examples/example-dot-ai.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot completion` → `dot cli completion show` | every dialect covers the command registry | `test_fm_completion_covers_the_registry` | `run:completion-bash` | `examples/example-dot-completion.sh` | `docs/manual/command-index.md` | regression |
| `dot fleet apply` | an injection-shaped ssh target aborts the fan-out | `test_fm_fleet_apply_rejects_injection_hostname` | `help:fleet` | `examples/example-dot-fleet.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot secrets` → `dot secret` | no default-mode command prints a stored value | `test_fm_secrets_never_leak_by_default` | `help:secret` | `examples/example-dot-secrets.sh` | `docs/manual/03-reference/01-dot-cli.md` | regression |
| `dot firewall` → `dot security` | no security --help invokes sudo | `test_fm_security_help_does_not_mutate` | `help:security` | `examples/example-dot-security.sh` | `docs/manual/command-index.md` | regression |

## Rows recorded as unmeasurable

Each of these has a `--help` smoke test, so none is fully uncovered. They are
listed together here so the reasons can be audited in one place rather than
hunted through the table.

| Command | Variant | Why it cannot be measured in CI |
|---------|---------|----------------------------------|
| `dot doctor` | --benchmark / -b | runs tests/benchmark.sh (hyperfine over every shell, minutes) — covered by benches/bench.sh |
| `dot health` → `dot doctor status` | --fix / -f, --force / -F | --fix re-applies chezmoi and rewrites shell configs in $HOME |
| `dot load-bench-pty` → `dot doctor perf --ready --pty` | (default) | needs the chezmoi-rendered dot-load-benchmark-pty template and a pseudo-terminal |
| `dot teleport` → `dot fleet push` | user@host | opens an SSH session to a remote host (network) |
| `dot bundle` → `dot config export` | [output-dir] | archives the checkout plus tool caches with zstd (hundreds of MB, minutes) |
| `dot ai` | (default cockpit TUI) | launches the Bubble Tea cockpit / gum launcher (interactive TTY) |
| `dot ai tools` | install (alias of ai install) | installs AI CLIs through mise/native installers (network, mutates $HOME) |
| `dot ai run` | "<prompt>" one-shot on Claude | performs a paid LLM round-trip (network) |
| `dot ai` | "<prompt>" / <tool> "<prompt>" one-shot | performs a paid LLM round-trip (network) |
| `dot ai delegate` | "<prompt>" [max-turns] [agent] [timeout] | delegates to a paid model under agent policy (network) |
| `dot ai ask` | "<question>" RAG query | embeds the repo and calls an LLM (network) |
| `dot ai chat` | [tool] | starts an interactive AI session (TTY) |
| `dot ai install` | [tool] | installs AI CLIs (network, mutates $HOME) |
| `dot ai login` | (default) | interactive OAuth / API-key prompts (TTY, network) |
| `dot ai` | dashboard / dash (deprecated cockpit alias) | launches the cockpit TUI (interactive TTY) |
| `dot ai-setup` → `dot ai install --interactive` | guided AI tool setup | interactive tool authentication (TTY, network) |
| `dot cl` → `dot ai run claude` | "<prompt>" with an installed tool | performs a paid LLM round-trip (network) |
| `dot env` → `dot tool remove` | prune --yes / -y | uninstalls orphan tool versions from the real mise store |
| `dot env` → `dot tool install` | install [tool@version] | downloads and installs toolchains through mise (network) |
| `dot env` → `dot tool set` | use <tool@version> | rewrites the user's mise config and installs tools (network) |
| `dot tools` → `dot tool list --nix` | install (Nix develop shell) | enters an interactive `nix develop` shell (TTY, network) |
| `dot setup` → `dot config init` | (interactive gum wizard) | interactive gum selection wizard (TTY) |
| `dot theme` | set <name> / light / dark | switches the OS appearance and rewrites terminal configs (osascript / gsettings) |
| `dot theme` | toggle | switches the OS appearance (system mutation) |
| `dot theme` | sync | rewrites terminal configs to follow the OS appearance (system mutation) |
| `dot theme` | family | cycles the theme family and applies it (system mutation) |
| `dot theme` | rebuild | regenerates every theme from wallpapers (minutes of image processing) |
| `dot wallpaper` → `dot theme wallpaper set` | (default = sync) | sets the desktop wallpaper through osascript / feh (system mutation) |
| `dot wallpaper` → `dot theme wallpaper set` | sync | sets the desktop wallpaper (system mutation) |
| `dot wallpaper` → `dot theme wallpaper set` | rotate (--interval, --once, --light, --dark) | sets the desktop wallpaper (system mutation) |
| `dot fonts` → `dot theme font install` | (default = install) | downloads and installs Nerd Fonts into the user font directory (network) |
| `dot fonts` → `dot theme font install` | install [font] | downloads and installs Nerd Fonts (network) |
| `dot tune` → `dot system settings apply` | (default) | writes OS defaults / sysctl values (system mutation, sudo) |
| `dot secrets` → `dot secret set` | set <KEY> (prompts for the value) | reads the secret value from an interactive silent prompt (TTY) |
| `dot ssh-cert` → `dot secret cert new` | issue [--ttl] [--principal] / revoke | contacts a step-ca server and rewrites ~/.ssh certificates (network) |
| `dot firewall` → `dot security firewall apply` | (default) | enables the OS firewall with sudo (system mutation) |
| `dot telemetry` → `dot security telemetry apply` | DOTFILES_TELEMETRY=1 | disables OS telemetry services with sudo (system mutation) |
| `dot dns-doh` → `dot security dns apply` | (default) | rewrites the system resolver configuration with sudo (system mutation) |
| `dot lock-screen` → `dot security lock apply` | (default) | writes screensaver / idle-lock OS settings (system mutation) |
| `dot usb-safety` → `dot security usb apply` | (default) | writes udev / automount policy with sudo (system mutation) |
| `dot upgrade` → `dot system update` | (default) | runs nix flake update, chezmoi update, mise install + upgrade, a headless Neovim plugin sync, and (asked first) a system-package upgrade (network, mutates $HOME) |
| `dot upgrade` → `dot system update` | --yes / DOTFILES_YES=1 answers yes to installing mise and upgrading system packages | the consented phases install and upgrade software (network, mutates the system) |
| `dot upgrade` → `dot system update` | DOTFILES_FONTS=1 adds the Nerd Font step to upgrade | only observable inside the real upgrade run (network) |
| `dot sandbox` → `dot config apply --sandbox` | (default) | builds and runs a Docker/Podman image interactively (network, TTY) |
| `dot init` → `dot config init` | <user> (clone + apply), --force / -f | clones a remote repository and applies it over $HOME (network) |
| `dot init` → `dot config init` | DOTFILES_NONINTERACTIVE=1 skips the trust confirmation | the prompt only fires on a TTY before a real clone (network) |
| `dot manual` → `dot help --manual` | html / html-multi / pdf / epub / markdown (default open) | downloads the manual and opens it in the desktop browser / viewer (network, GUI) |
| `dot manual` → `dot help --manual` | DOTFILES_MANUAL_URL / --url= override the download base | only exercised on the network download path |

## Findings this matrix produced

Building the coverage turned up defects in the CLI. Each was exercised by the
row that found it, commented at that row, and reported rather than silently
accommodated. Every one of them has since been fixed and pinned by a
regression test; what remains below is the one entry that is working as
designed.

| Severity | Where | What |
|----------|-------|------|
| Note | `plugins/tool/libexec/env-emit.sh` | The `-h\|--help` arm of `dot_env_emit` is unreachable through the CLI: the dispatcher's universal `--help` intercept fires first and renders `dot help env`. Working as designed, but the sub-handler's usage text can only be read in the source. |

### Commands that write into the checkout

These commands resolve their write target through `lib/dot/sdk.sh`'s
`resolve_source_dir`, which probes the location of the sourced library BEFORE
`$CHEZMOI_SOURCE_DIR` and `$HOME`. Running `./bin/dot` from a checkout
therefore writes into that checkout whatever `HOME` says, so a sandboxed
`HOME` does not protect a working tree from them. The regression rows for
these drive a throwaway copy of the repo instead, and then assert the checkout
is still clean:

- `dot fleet namespace set`: `defaults/.chezmoidata.toml`
- `dot fleet enforce set`: `defaults/dot_config/dotfiles/agent-profiles.json`
- `dot shell alias export` with no `--output` (was `dot aliases cheatsheet`): `docs/ALIASES_CHEATSHEET.md`

`dot theme set` is NOT one of them, contrary to an earlier note here.
scripts/theme/switch.sh and bin/dot-theme-sync resolve the data file from
`$CHEZMOI_SOURCE_DIR`, then `$HOME/.dotfiles`, then
`$HOME/.local/share/chezmoi`, and refuse with "Dotfiles source not found"
when none exists — measured by pointing `$HOME/.dotfiles` at a synthetic tree
while running the checkout's `bin/dot`: the synthetic tree was written and the
checkout was untouched. It writes the checkout under this harness only because
the harness points both `CHEZMOI_SOURCE_DIR` and `$HOME/.dotfiles` at it. It
also drives the real OS appearance, which is why it stays a smoke row.

## See also

- `docs/manual/command-index.md` — generated index of every routable command
- `docs/manual/03-reference/01-dot-cli.md` — the CLI reference
- `docs/manual/03-reference/02-config-files.md` — config file schemas
- `docs/manual/03-reference/03-environment.md` — environment variables
- `CONTRIBUTING.md` — the "Regression tests" trace-header convention

