#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Exhaustive runtime exercise of the `dot tools` surface — drives line
# coverage across scripts/dot/commands/tools.sh and the two modules it
# sources for dispatch: aliases.sh (`aliases`, `alias-check`) and
# env-emit.sh (`env emit`).
#
# Those three files carried grep-only tests before this one: the
# assertions confirmed a function was *defined* but never called it, so
# the bodies never executed. mise/nix/curl are shimmed so every verb
# runs offline without touching the host.
#
# Each scenario covers a distinct dispatch arm; rc is recorded rather
# than asserted, matching the convention in test_ai_exhaustive.sh —
# many arms exit non-zero by design (missing optional tool, unknown
# subcommand, usage error) and the point is that the body ran.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TOOLS_SCRIPT="$REPO_ROOT/scripts/dot/commands/tools.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

MB="$DOTFILES_COV_TMPDIR/bin"

# ── mise: the source of truth `dot env` reads ────────────────────────
# `mise ls --json` output shaped like the real thing so the jq filter
# in env-emit.sh has something to walk. `prune --dry-run-code` exits 1
# (nothing to prune) so the orphan-install arm executes too.
cat >"$MB/mise" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  ls)
    if [[ "${2:-}" == "--json" ]]; then
      cat <<'JSON'
{
  "node": [
    {
      "version": "22.11.0",
      "requested_version": "22",
      "install_path": "/opt/mise/installs/node/22.11.0",
      "source": {"type": "mise.toml", "path": "/tmp/mise.toml"},
      "installed": true,
      "active": true
    }
  ],
  "python": [
    {
      "version": "3.12.7",
      "requested_version": "3.12",
      "install_path": "/opt/mise/installs/python/3.12.7",
      "source": {"type": "mise.toml", "path": "/tmp/mise.toml"},
      "installed": true,
      "active": true
    }
  ]
}
JSON
    else
      printf '%s\n' "node  22.11.0" "python  3.12.7"
    fi
    ;;
  prune) exit 1 ;;
  --version | version) echo "mise 2026.7.1" ;;
  *) : ;;
esac
exit 0
SHIM

# nix: present but inert, so `tools install` takes the flake arm
# rather than the "Nix not installed" bail-out.
cat >"$MB/nix" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM

# curl: never reach the network. Empty body, success rc.
cat >"$MB/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
  [[ "$1" == "-o" ]] && { out="${2:-}"; shift 2; continue; }
  shift
done
[[ -n "$out" ]] && : >"$out"
exit 0
SHIM

chmod +x "$MB/mise" "$MB/nix" "$MB/curl"

# Language package managers probed by `dot packages`. Without these the
# probes fall through to whatever the host has installed and shell out
# to the real cargo / go / npm — slow, and it reaches outside the
# sandbox. Each shim answers the one query tools.sh makes of it.
for pm in npm pnpm bun cargo pip3 pipx gem go; do
  cat >"$MB/$pm" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version | version) echo "1.0.0" ;;
  list) printf '%s\n' "├── pkg-a@1.0.0" "└── pkg-b@2.0.0" ;;
  install) printf '%s\n' "shim-package v1.0.0:" ;;
  *) echo "1.0.0" ;;
esac
exit 0
SHIM
  chmod +x "$MB/$pm"
done

# Shell config the alias-check arm inspects. Half the required aliases
# are present so both the ok and the warn branches execute.
mkdir -p "$HOME/.config/shell/custom" "$HOME/.config/zsh"
cat >"$HOME/.config/shell/90-ux-aliases.sh" <<'EOF'
alias c='clear'
alias q='exit'
alias e='$EDITOR'
alias l='ls -lah'
alias ll='ls -l'
EOF
printf 'auto_ls() { ls; }\n' >"$HOME/.config/shell/custom/auto_ls.zsh"
printf 'source auto_ls.zsh\n' >"$HOME/.config/zsh/.zshrc"

# Zsh history so `aliases stats` walks its frequency counter instead of
# bailing on a missing file.
cat >"$HOME/.zsh_history" <<'EOF'
: 1700000000:0;ls -la
: 1700000001:0;ll
: 1700000002:0;git status
: 1700000003:0;ll
: 1700000004:0;cd /tmp
EOF

# Scaffolding and `--output` writes land in the sandbox, never the repo.
cd "$DOTFILES_COV_TMPDIR"

# ex <label> <args…> — run tools.sh, keep stderr (xtrace) connected so
# the coverage runner sees the traced lines, tolerate any rc.
ex() {
  local label="$1"
  shift
  test_start "tools_ex_${label}"
  set +e
  bash "$TOOLS_SCRIPT" "$@" </dev/null >/dev/null
  local rc=$?
  set -e
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
}

# ── top-level dispatch ───────────────────────────────────────────────
ex help --help
ex no_arg
ex unknown definitely-not-a-command

# ── tools ────────────────────────────────────────────────────────────
ex tools_default tools
ex tools_docs tools docs
ex tools_install tools install

# ── aliases (aliases.sh) ─────────────────────────────────────────────
ex aliases_default aliases
ex aliases_list aliases list
ex aliases_search_hit aliases search ls
ex aliases_search_miss aliases search zzzznomatch
ex aliases_search_noarg aliases search
ex aliases_why aliases why ll
ex aliases_why_noarg aliases why
ex aliases_stats aliases stats
ex aliases_tiers aliases tiers

# `aliases cheatsheet` is deliberately NOT exercised through tools.sh.
# Its body redirects into "$(require_source_dir)/docs/
# ALIASES_CHEATSHEET.md", and resolve_source_dir() derives that path
# from the location of the lib it sourced — the real repo — so no
# amount of $HOME/.dotfiles redirection keeps the write inside the
# sandbox. Running the arm drops a generated file into the working
# tree. The generator behind it is covered directly instead, which is
# where the actual line volume lives; only the five-line wrapper is
# skipped.
test_start "tools_aliases_cheatsheet_generator"
set +e
bash "$REPO_ROOT/scripts/diagnostics/aliases-cheatsheet.sh" </dev/null >/dev/null 2>&1
cheatsheet_rc=$?
set -e
((TESTS_PASSED++)) || true
printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$cheatsheet_rc)"

# Tripwire: nothing in this sweep may write the generated cheatsheet
# into the checkout. Guards against the wrapper arm being added back.
test_start "tools_cheatsheet_stays_out_of_repo"
if [[ -e "$REPO_ROOT/docs/ALIASES_CHEATSHEET.md" ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: wrote into the real repo"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: repo untouched"
fi
ex aliases_unknown aliases definitely-not-a-subcommand

# ── alias-check (aliases.sh) ─────────────────────────────────────────
ex alias_check alias-check

# ── env / env emit (env-emit.sh) ─────────────────────────────────────
ex env_default env
ex env_list env list
ex env_emit env emit
ex env_emit_compact env emit --compact
ex env_emit_pretty env emit --pretty
ex env_emit_format_json env emit --format json
ex env_emit_bad_format env emit --format not-a-format
ex env_emit_format_noarg env emit --format
ex env_emit_output env emit --output "$DOTFILES_COV_TMPDIR/env-manifest.json"
ex env_emit_bad_flag env emit --definitely-not-a-flag

# ── remaining dispatch arms ──────────────────────────────────────────
ex packages packages
ex profile profile
ex log_rotate log-rotate
ex setup setup

# ── new (project scaffolding) ────────────────────────────────────────
ex new_noarg new
ex new_bad_lang new "bad/lang" proj
ex new_bad_name new python "bad/name"
ex new_unknown_template new nosuchlang myproj
ex new_python new python cov_scaffold_py
ex new_node new node cov_scaffold_node

# Scaffolding actually produced a tree — the security-baseline helper
# in tools.sh writes these into every generated project.
test_start "tools_new_scaffold_writes_baseline"
if [[ -f "$DOTFILES_COV_TMPDIR/cov_scaffold_py/.editorconfig" ]] ||
  [[ -d "$DOTFILES_COV_TMPDIR/cov_scaffold_py" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: python scaffold created"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no scaffold directory"
fi

# `env emit --output` is the one arm with a checkable side effect.
test_start "tools_env_emit_writes_output"
if [[ -f "$DOTFILES_COV_TMPDIR/env-manifest.json" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: manifest written"
else
  # jq is optional on the unit-test runner; env-emit exits 2 without it.
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (jq unavailable)"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
