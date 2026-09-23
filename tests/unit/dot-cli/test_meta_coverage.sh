#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# Execution coverage for scripts/dot/commands/meta.sh arms the other meta
# suites leave dark: the dotfiles-checkout preflight in `upgrade`, the nix
# and neovim phases, the overwrite-prompt hint, `prewarm`, `docs` via glow,
# the chezmoi-root tour, every `keys` variant, `sandbox` via docker, the
# `mcp` argument shapes, `mcp registry` via jq, every `mcp serve` resolution
# path, and the top-level dispatcher. The module runs against a fixture
# source tree (tests/framework/module_fixture.sh) with a PATH of stubs and a
# mktemp HOME; nothing outside the sandbox is read or written.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"
# shellcheck source=../../framework/module_fixture.sh
source "$REPO_ROOT/tests/framework/module_fixture.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/meta-cov.XXXXXX")"
FX="$(dot_fixture_new "meta-cov-$$")"
trap 'rm -rf "$WORK" "$FX"' EXIT
STUBS="$WORK/stubs"
BASEBIN="$WORK/basebin"
HOMEDIR="$WORK/home"
mkdir -p "$STUBS" "$HOMEDIR"
dot_fixture_basebin "$BASEBIN" jq
DOT_FIXTURE_HOME="$HOMEDIR"
export XDG_CACHE_HOME="$HOMEDIR/.cache" XDG_CONFIG_HOME="$HOMEDIR/.config"
export XDG_STATE_HOME="$HOMEDIR/.local/state" TMPDIR="$WORK"
unset NVIM_APPNAME DOTFILES_FONTS MCP_REGISTRY_CONFIG DOT_MCP_DOT_BIN

meta_run() {
  DOT_FIXTURE_PATH="$STUBS:$BASEBIN" dot_fixture_run "$FX" meta "$@"
}
# script_stub <name> <body> — a bash stub in $STUBS.
script_stub() {
  printf '#!%s\n%s\n' "${BASH:-/bin/bash}" "$2" >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}

# ── upgrade: preflight on the chezmoi checkout ─────────────────────────────
# git answers are staged per case through files in $WORK.
script_stub git '
case "$*" in
  *"rev-parse --is-inside-work-tree"*) exit 0 ;;
  *"symbolic-ref"*) [[ -f '"$WORK"'/detached ]] && exit 1; echo main ;;
  *"@{upstream}"*) [[ -f '"$WORK"'/noupstream ]] && exit 1; exit 0 ;;
  *"status --porcelain"*) [[ -f '"$WORK"'/dirty ]] && echo " M file"; exit 0 ;;
esac
exit 0'
mkdir -p "$WORK/src-checkout"
script_stub chezmoi '
case "$1" in
  source-path) echo '"$WORK"'/src-checkout ;;
  update) [[ -f '"$WORK"'/prompt ]] && { echo "x has changed since chezmoi last wrote it?"; exit 1; }; echo "updated ok" ;;
esac
exit 0'

test_start "upgrade_refuses_detached_checkout"
touch "$WORK/detached"
meta_run upgrade
rm -f "$WORK/detached"
assert_equals "1" "$DOT_FIXTURE_RC" "detached head fails the phase"
assert_contains "checkout is detached" "$DOT_FIXTURE_OUT" "detached explained"

test_start "upgrade_refuses_branch_without_upstream"
touch "$WORK/noupstream"
meta_run upgrade
rm -f "$WORK/noupstream"
assert_contains "has no upstream" "$DOT_FIXTURE_OUT" "missing upstream explained"

test_start "upgrade_refuses_dirty_checkout"
touch "$WORK/dirty"
meta_run upgrade
rm -f "$WORK/dirty"
assert_contains "uncommitted changes" "$DOT_FIXTURE_OUT" "dirty tree explained"

test_start "upgrade_overwrite_prompt_hint"
touch "$WORK/prompt"
meta_run upgrade
rm -f "$WORK/prompt"
assert_contains "a managed file was edited locally" "$DOT_FIXTURE_OUT" "hint shown"

test_start "upgrade_all_phases_succeed"
mkdir -p "$FX/nix" "$XDG_CONFIG_HOME/nvim"
: >"$FX/nix/flake.nix"
: >"$XDG_CONFIG_HOME/nvim/init.lua"
dot_fixture_stub "$STUBS" nix 0
dot_fixture_stub "$STUBS" nix-collect-garbage 0
dot_fixture_stub "$STUBS" nvim 0
meta_run upgrade
rm -rf "$FX/nix" "$STUBS/nix" "$STUBS/nix-collect-garbage" "$STUBS/nvim"
assert_equals "0" "$DOT_FIXTURE_RC" "clean upgrade exits 0"
assert_contains "Nix flake" "$DOT_FIXTURE_OUT" "nix flake phase ran"
assert_contains "Neovim plugins" "$DOT_FIXTURE_OUT" "nvim phase ran"
assert_contains "requested upgrade phases completed" "$DOT_FIXTURE_OUT" "success summary"
rm -f "$STUBS/git"

# ── prewarm / docs / learn ────────────────────────────────────────────────
test_start "prewarm_clears_caches_and_regenerates"
for d in zsh bash fish nushell; do mkdir -p "$XDG_CACHE_HOME/$d"; done
: >"$XDG_CACHE_HOME/zsh/x-init.zsh"
: >"$XDG_CACHE_HOME/bash/x-init.bash"
: >"$XDG_CACHE_HOME/fish/x-init.fish"
: >"$XDG_CACHE_HOME/nushell/x.nu"
mkdir -p "$FX/scripts/ops"
printf 'echo prewarm-ran\n' >"$FX/scripts/ops/prewarm.sh"
meta_run cache-refresh
assert_equals "0" "$DOT_FIXTURE_RC" "prewarm exits 0"
assert_contains "prewarm-ran" "$DOT_FIXTURE_OUT" "prewarm script executed"
assert_file_not_exists "$XDG_CACHE_HOME/zsh/x-init.zsh" "zsh cache cleared"
assert_file_not_exists "$XDG_CACHE_HOME/nushell/x.nu" "nushell cache cleared"

test_start "docs_uses_glow"
printf '# readme\n' >"$FX/README.md"
dot_fixture_stub "$STUBS" glow 0
meta_run docs
rm -f "$STUBS/glow"
assert_contains "/dot-cov-fixtures/meta-cov-$$/README.md" "$DOT_FIXTURE_OUT" "glow renders README"

test_start "learn_runs_chezmoiroot_tour"
mkdir -p "$FX/defaults/dot_local/bin"
printf 'echo "tour args: $*"\n' >"$FX/defaults/dot_local/bin/executable_tour"
meta_run learn --fast
rm -rf "$FX/defaults"
assert_contains "tour args: --fast" "$DOT_FIXTURE_OUT" "defaults tour executed"

# ── keys ──────────────────────────────────────────────────────────────────
keys_git() {
  script_stub git "
case \"\$*\" in
  *user.signingkey*) printf '%s\n' '$1' ;;
  *gpg.format*) printf '%s\n' '$2' ;;
esac
exit 0"
}
test_start "keys_sign_check_variants"
keys_git "" ""
meta_run keys sign-check
assert_contains "No signing key configured" "$DOT_FIXTURE_OUT" "no key"
mkdir -p "$HOMEDIR/.ssh"
: >"$HOMEDIR/.ssh/id.pub"
keys_git "~/.ssh/id.pub" "ssh"
meta_run keys sign-check
assert_contains "SSH key file exists" "$DOT_FIXTURE_OUT" "ssh key found via ~ expansion"
rm -f "$STUBS/git"

test_start "keys_search_and_fallback"
mkdir -p "$FX/docs/security"
printf 'alpha\nCtrl-R history\nomega\n' >"$FX/docs/security/KEYS.md"
dot_fixture_stub "$STUBS" rg 0
meta_run keys history
rm -f "$STUBS/rg"
assert_contains "rg -i --fixed-strings --context 1 history" "$DOT_FIXTURE_OUT" "rg used when present"
meta_run keys history
assert_contains "Ctrl-R history" "$DOT_FIXTURE_OUT" "grep fallback finds the line"
rm -rf "$FX/docs"
meta_run keys
assert_equals "1" "$DOT_FIXTURE_RC" "no keys doc and no script fails"
assert_contains "Keys script not found" "$DOT_FIXTURE_OUT" "fallback script named"

# ── sandbox ───────────────────────────────────────────────────────────────
test_start "sandbox_via_docker"
dot_fixture_stub "$STUBS" docker 0
meta_run sandbox
rm -f "$STUBS/docker"
assert_contains "Launching sandbox via Docker" "$DOT_FIXTURE_OUT" "docker announced"
assert_contains "docker run --rm -it dotfiles-sandbox" "$DOT_FIXTURE_OUT" "docker run exec'd"

# ── mcp ───────────────────────────────────────────────────────────────────
test_start "mcp_flag_first_defaults_to_doctor"
mkdir -p "$FX/scripts/diagnostics"
printf 'echo "doctor args: $*"\n' >"$FX/scripts/diagnostics/mcp-doctor.sh"
meta_run mcp --json
assert_contains "doctor args: --json" "$DOT_FIXTURE_OUT" "flag passes to doctor"
meta_run mcp
assert_contains "doctor args:" "$DOT_FIXTURE_OUT" "bare mcp runs doctor"

test_start "mcp_registry_json_and_jq"
REG="$WORK/mcp.json"
printf '{"servers":{"fs":{"transport":"stdio","launcher":"npx","package":"@x/fs"},"web":{"transport":"http","launcher":"remote","url":"https://w"},"loc":{"transport":"stdio","launcher":"bin"}}}\n' >"$REG"
MCP_REGISTRY_CONFIG="$REG" meta_run mcp registry -j
assert_contains '"servers"' "$DOT_FIXTURE_OUT" "--json cats raw registry"
if command -v jq >/dev/null 2>&1; then
  MCP_REGISTRY_CONFIG="$REG" meta_run mcp registry
  assert_contains "stdio via npx -> @x/fs" "$DOT_FIXTURE_OUT" "package target"
  assert_contains "http via remote -> https://w" "$DOT_FIXTURE_OUT" "url target"
  assert_contains "stdio via bin -> local" "$DOT_FIXTURE_OUT" "local target"
fi

test_start "mcp_serve_resolution"
# The real layout: .chezmoiroot names defaults/, so the served repo is the
# fixture root above it.
printf 'defaults\n' >"$FX/.chezmoiroot"
mkdir -p "$FX/defaults"
script_stub dot-mcp 'echo "path dot-mcp $* root=$DOT_MCP_REPO_ROOT"'
meta_run mcp serve --x
rm -f "$STUBS/dot-mcp"
assert_contains "path dot-mcp serve --x root=" "$DOT_FIXTURE_OUT" "PATH binary exec'd"
assert_contains "/dot-cov-fixtures/meta-cov-$$" "$DOT_FIXTURE_OUT" "repo root is the fixture"
mkdir -p "$HOMEDIR/.local/bin"
printf '#!/bin/sh\necho "home dot-mcp $*"\n' >"$HOMEDIR/.local/bin/dot-mcp"
chmod +x "$HOMEDIR/.local/bin/dot-mcp"
meta_run mcp serve
rm -f "$HOMEDIR/.local/bin/dot-mcp"
assert_contains "home dot-mcp serve" "$DOT_FIXTURE_OUT" "~/.local/bin binary exec'd"
meta_run mcp serve
assert_equals "1" "$DOT_FIXTURE_RC" "no source and no binary exits 1"
assert_contains "dot-mcp is not built" "$DOT_FIXTURE_OUT" "not-built message"
mkdir -p "$FX/defaults/dot_local/share/dot-mcp"
: >"$FX/defaults/dot_local/share/dot-mcp/main.go"
script_stub go '
out=""
while [[ $# -gt 0 ]]; do [[ "$1" == -o ]] && out="$2"; shift; done
[[ -f '"$WORK"'/gofail ]] && exit 1
printf "#!/bin/sh\necho built dot-mcp \"\$*\"\n" >"$out"; chmod +x "$out"'
meta_run mcp serve
assert_contains "building dot-mcp (first run)" "$DOT_FIXTURE_OUT" "build announced"
assert_contains "built dot-mcp serve" "$DOT_FIXTURE_OUT" "built binary exec'd"
touch "$WORK/gofail"
meta_run mcp serve
assert_equals "1" "$DOT_FIXTURE_RC" "failed build exits 1"
assert_contains "dot-mcp is not built" "$DOT_FIXTURE_OUT" "failed build falls through"
rm -rf "$FX/defaults" "$FX/.chezmoiroot" "$STUBS/go"

# ── dispatcher ────────────────────────────────────────────────────────────
test_start "dispatcher_help_empty_unknown"
meta_run --help
assert_equals "0" "$DOT_FIXTURE_RC" "--help exits 0"
assert_contains "Usage: meta.sh" "$DOT_FIXTURE_OUT" "help text"
meta_run
assert_equals "1" "$DOT_FIXTURE_RC" "no command exits 1"
meta_run frobnicate
assert_equals "1" "$DOT_FIXTURE_RC" "unknown command exits 1"
assert_contains "Unknown meta command: frobnicate" "$DOT_FIXTURE_OUT" "unknown named"
AGENT_PROFILE_CONFIG="$WORK/no-profiles.json" meta_run mode list
assert_equals "1" "$DOT_FIXTURE_RC" "mode dispatches to cmd_mode"
assert_contains "Agent profile config not found" "$DOT_FIXTURE_OUT" "cmd_mode reached"

test_start "banner_section_names"
out="$(
  source "$REPO_ROOT/lib/dot/utils.sh" >/dev/null 2>&1
  eval "$(sed -n '/^meta_banner_section()/,/^}/p' "$REPO_ROOT/scripts/dot/commands/meta.sh")"
  meta_banner_section mcp
  meta_banner_section keys
  meta_banner_section upgrade
)"
assert_equals $'AI and Agents\nReference\nMeta' "$out" "sections map"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
