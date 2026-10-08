#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# The provisioning run_* templates install exact versions from
# .chezmoidata.toml: go install at @vX.Y.Z, cargo install --locked
# --version, TPM at a pinned and verified commit, AI CLIs at their [ai_tools]
# versions. Each template is rendered with chezmoi and run against stubs
# (go, cargo, rustup, git, mise) that record what they were asked to do.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

PROV="$REPO_ROOT/install/provision"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi is needed to render the templates"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d -t provision-pins.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
STUBS="$WORK/stubs"
CALLS="$WORK/calls.log"
mkdir -p "$STUBS" "$WORK/cz" "$WORK/home"
dot_fixture_basebin "$WORK/base"
: >"$WORK/cz/chezmoi.toml"

# stub <name> [body]: records "<name> <args>" in $CALLS, then runs <body>.
stub() {
  printf '#!/bin/sh\necho "%s $*" >>"%s"\n%s\n' "$1" "$CALLS" "${2:-exit 0}" >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}

# render <template> <out>: chezmoi execute-template with the repo's data and
# the stubs on PATH (templates gate on lookPath).
render() {
  env -i HOME="$WORK/cz" PATH="$STUBS:$PATH" chezmoi --config "$WORK/cz/chezmoi.toml" \
    --source "$REPO_ROOT/defaults" --persistent-state "$WORK/cz/state" \
    execute-template <"$1" >"$2"
}

# run_rendered <script>: prints the exit status; output in $WORK/out.txt.
run_rendered() {
  local rc=0
  : >"$CALLS"
  env -i HOME="$WORK/home" PATH="$STUBS:$WORK/base" DOTFILES_SOURCE_DIR="$REPO_ROOT" FAKE_HEAD="${FAKE_HEAD:-}" \
    bash "$1" >"$WORK/out.txt" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}

# ── go tools ────────────────────────────────────────────────────────────────
stub go
render "$PROV/run_onchange_27-go-tools.sh.tmpl" "$WORK/go.sh"
rc="$(run_rendered "$WORK/go.sh")"

test_start "go_tools_install_exact_versions"
assert_equals "0|9|0" \
  "$rc|$(grep -c '^go install ' "$CALLS")|$(grep '^go install ' "$CALLS" | grep -cvE '@v[0-9]+\.[0-9]+\.[0-9]+$')" \
  "nine go tools, each at an exact @vX.Y.Z"

test_start "go_tools_use_the_data_versions"
assert_contains "go install golang.org/x/tools/gopls@v0.23.0" "$(cat "$CALLS")" "gopls comes from [go_tools]"

# ── rust tools ──────────────────────────────────────────────────────────────
stub rustup 'case "$1 $2" in "component list") echo "clippy rustfmt rust-src rust-analyzer" | tr " " "\n" ;; esac'
stub cargo
render "$PROV/run_onchange_26-rust-tools.sh.tmpl" "$WORK/rust.sh"
rc="$(run_rendered "$WORK/rust.sh")"

test_start "rust_tools_locked_exact_versions"
assert_equals "0|8|0" \
  "$rc|$(grep -c '^cargo install ' "$CALLS")|$(grep '^cargo install ' "$CALLS" | grep -cvE '^cargo install --locked --version [0-9]+\.[0-9]+\.[0-9]+ [a-z-]+$')" \
  "eight crates, each --locked at an exact --version"

test_start "rust_tools_use_the_data_versions"
assert_contains "cargo install --locked --version 0.13.13 cargo-edit" "$(cat "$CALLS")" "cargo-edit comes from [rust_tools]"

# ── tmux plugin manager ─────────────────────────────────────────────────────
PIN="7bdb7ca33c9cc6440a600202b50142f401b6fe21"
stub git 'case "$1" in
  clone) mkdir -p "$(eval echo "\${$#}")" ;;
  -C) if [ "$3" = rev-parse ]; then echo "$FAKE_HEAD"; fi ;;
esac'
render "$PROV/run_onchange_12-tmux-plugins.sh.tmpl" "$WORK/tpm.sh"

rc="$(FAKE_HEAD="$PIN" run_rendered "$WORK/tpm.sh")"
test_start "tpm_checked_out_at_pinned_commit"
assert_equals "0|yes|yes" \
  "$rc|$(grep -q -- "clone --quiet --no-checkout https://github.com/tmux-plugins/tpm" "$CALLS" && echo yes || echo no)|$([[ -d "$WORK/home/.tmux/plugins/tpm" ]] && echo yes || echo no)" \
  "TPM is cloned without a checkout, then kept at the pinned commit"

test_start "tpm_checkout_names_the_pin"
assert_contains "checkout --quiet --detach $PIN" "$(cat "$CALLS")" "the pinned commit is what is checked out"

rm -rf "$WORK/home/.tmux"
rc="$(FAKE_HEAD="0000000000000000000000000000000000000000" run_rendered "$WORK/tpm.sh")"
test_start "tpm_wrong_head_removed"
assert_equals "1|no" "$rc|$([[ -d "$WORK/home/.tmux/plugins/tpm" ]] && echo yes || echo no)" \
  "a checkout that is not the pinned commit is removed and the run fails"

# ── AI CLIs ─────────────────────────────────────────────────────────────────
# Native installers are skipped (their tools are "present"); mise and npm
# record what they are asked for.
for t in claude kimi goose agy node npm corepack; do stub "$t"; done
stub mise
render "$PROV/run_onchange_15-ai-cli-tools.sh.tmpl" "$WORK/ai.sh"
rc="$(run_rendered "$WORK/ai.sh")"

test_start "ai_clis_installed_at_pinned_versions"
assert_equals "0|10|0" \
  "$rc|$(grep -c '^mise use -g ' "$CALLS")|$(grep '^mise use -g ' "$CALLS" | grep -cvE '@[0-9]+\.[0-9]+\.[0-9]+$')" \
  "ten AI CLIs through mise, each at an exact version"

test_start "ai_clis_use_the_data_versions"
assert_contains "mise use -g npm:@openai/codex@0.159.3" "$(cat "$CALLS")" "codex comes from [ai_tools]"

test_start "ai_clis_skip_quarantined_vibe"
assert_equals "0" "$(grep -c 'mistral-vibe' "$CALLS")" "mistral-vibe is not installed"

print_summary
