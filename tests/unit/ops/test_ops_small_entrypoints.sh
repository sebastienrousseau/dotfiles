#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the remaining small entry points, each driven with
# sandbox fixtures and stubs so nothing on the host is tuned, warmed,
# deployed or committed:
#
#   scripts/diagnostics/version-locks.sh   — pin summary from a source tree
#   scripts/tuning/linux.sh                — opt-in sysctl tuning
#   scripts/ops/prewarm.sh                 — shell-init cache warming
#   scripts/ops/teleport.sh                — ephemeral remote deploy
#   scripts/ops/ai-setup.sh                — AI CLI authentication sweep
#   lib/dot/bento.sh                       — the intelligence card
#   scripts/git-hooks/prepare-commit-msg   — commit-message branding hook
#   scripts/ci/check-copyright-headers.sh  — compat shim for the moved script
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

LOCKS="$REPO_ROOT/scripts/diagnostics/version-locks.sh"
TUNING="$REPO_ROOT/scripts/tuning/linux.sh"
PREWARM="$REPO_ROOT/scripts/ops/prewarm.sh"
TELEPORT="$REPO_ROOT/scripts/ops/teleport.sh"
AI_SETUP="$REPO_ROOT/scripts/ops/ai-setup.sh"
BENTO="$REPO_ROOT/lib/dot/bento.sh"
HOOK="$REPO_ROOT/scripts/git-hooks/prepare-commit-msg"
COPYRIGHT_SHIM="$REPO_ROOT/scripts/ci/check-copyright-headers.sh"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"
export CALLS="$DOTFILES_COV_TMPDIR/calls.txt"

run() {
  : >"$CALLS"
  "$@" >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  assert_file_contains "$MERGED" "$1" "${2:-output contains $1}"
}
called() { assert_file_contains "$CALLS" "$1" "invoked $1"; }
record_stub() {
  cat >"$BIN/$1" <<STUB
#!$REAL_BASH
printf '$1 %s\\n' "\$*" >>"\$CALLS"
exit "\${${2:-STUB_RC}:-0}"
STUB
  chmod +x "$BIN/$1"
}

# ── version-locks ───────────────────────────────────────────────────────
SRC="$DOTFILES_COV_TMPDIR/source"
mkdir -p "$SRC/defaults/dot_config/mise/conf.d" "$SRC/defaults/dot_config/shell"
printf 'defaults\n' >"$SRC/.chezmoiroot"
cat >"$SRC/defaults/dot_config/mise/conf.d/00-dotfiles.toml" <<'TOML'
[settings]
idiomatic_version_file = true

[tools]
node = "24.15.0"
rust = "1.95.0"

[env]
FOO = "bar"
TOML
printf '24.15.0\n' >"$SRC/defaults/dot_node-version"
printf 'save-exact=true\n' >"$SRC/defaults/dot_noderc.tmpl"
printf 'brew "git"\n' >"$SRC/defaults/dot_config/shell/Brewfile"
printf 'brew "jq"\n' >"$SRC/defaults/dot_config/shell/Brewfile.cli"
printf '{"version":"0.2.0"}\n' >"$SRC/package.json"

test_start "version_locks_summarises_every_pin_from_the_source_tree"
run env CHEZMOI_SOURCE_DIR="$SRC" bash "$LOCKS"
assert_equals 0 "$RC" "rc"
out_has "Version Locks" "header"
out_has "mise toolchain" "section"
out_has "node" "tool row"
out_has "24.15.0" "tool version"
out_has "rust" "second tool row"
out_has "noderc" "noderc row"
out_has "brew" "Brewfile row"
out_has "brew-cli" "Brewfile.cli row"
out_has "package.json version pinned" "repo-root artefact"
out_has "Prefer LTS and explicit pins" "policy note"

test_start "version_locks_reports_a_source_tree_without_a_mise_config"
BARE="$DOTFILES_COV_TMPDIR/bare"
mkdir -p "$BARE"
run env CHEZMOI_SOURCE_DIR="$BARE" bash "$LOCKS"
assert_equals 0 "$RC" "rc"
out_has "config not found" "warning"
assert_true "! grep -q 'Brewfile present' '$MERGED'" "no package-manager rows"

test_start "version_locks_falls_back_to_the_home_dotfiles_checkout"
# No CHEZMOI_SOURCE_DIR: the sandbox HOME has ~/.dotfiles pointing at the repo.
run bash "$LOCKS"
assert_equals 0 "$RC" "rc"
out_has "Version Locks" "still reports"

test_start "version_locks_falls_back_to_the_xdg_chezmoi_checkout"
XDG_SRC="$DOTFILES_COV_TMPDIR/xdg-home"
mkdir -p "$XDG_SRC/.local/share/chezmoi"
run env HOME="$XDG_SRC" CHEZMOI_SOURCE_DIR="" bash "$LOCKS"
assert_equals 0 "$RC" "rc"
out_has "Version Locks" "reports against the XDG checkout"
out_has "config not found" "an empty checkout has no mise config"

# ── linux tuning ────────────────────────────────────────────────────────
test_start "tuning_is_opt_in"
run bash "$TUNING"
assert_equals 0 "$RC" "rc"
out_has "Re-run with DOTFILES_TUNING=1" "opt-in hint"

test_start "tuning_rejects_an_unknown_profile"
run env DOTFILES_TUNING=1 DOTFILES_PROFILE=toaster bash "$TUNING"
assert_equals 1 "$RC" "rc"
out_has "must be laptop, desktop, or server (got: toaster)" "error"

test_start "tuning_applies_the_profile_through_sudo"
# `sudo` is a sandbox no-op shim, so nothing is actually set.
for profile in laptop desktop server; do
  run env DOTFILES_TUNING=1 DOTFILES_PROFILE="$profile" bash "$TUNING"
  assert_equals 0 "$RC" "rc ($profile)"
  out_has "Applying tuning" "announcement ($profile)"
  out_has "Linux tuning complete" "completion ($profile)"
done
out_has "vm.swappiness" "memory settings applied"
out_has "net.ipv4.tcp_syncookies" "security settings applied"

test_start "tuning_skips_sysctl_without_sudo"
NOSUDO="$DOTFILES_COV_TMPDIR/nosudo"
mkdir -p "$NOSUDO"
ln -sf "$REAL_BASH" "$NOSUDO/bash"
for c in printf echo cat tty locale uname sed grep tr dirname basename mkdir rm mv cut date head wc chmod touch id sort ln; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOSUDO/$c"
done
run env PATH="$NOSUDO" DOTFILES_TUNING=1 "$REAL_BASH" "$TUNING"
assert_equals 0 "$RC" "rc"
out_has "not available; skipping sysctl tuning" "explanation"

# ── prewarm ─────────────────────────────────────────────────────────────
# prewarm.sh locks on $XDG_RUNTIME_DIR (falling back to /tmp), a path shared
# by every process on the machine. Point it inside the sandbox so a suite
# running in parallel can neither take our lock nor see us holding it.
export XDG_RUNTIME_DIR="$DOTFILES_COV_TMPDIR/run"
mkdir -p "$XDG_RUNTIME_DIR"

test_start "prewarm_caches_every_tool_it_finds"
record_stub starship
record_stub zoxide
record_stub atuin
record_stub direnv
run bash "$PREWARM"
assert_equals 0 "$RC" "rc"
out_has "Pre-warming Shell Caches" "header"
out_has "Cache Pre-warming Complete" "completion"
out_has "Zsh" "per-shell sections"
out_has "Nushell" "nushell section"
out_has "Shell completions" "completions section"
assert_dir_exists "$XDG_CACHE_HOME/zsh" "zsh cache dir created"

test_start "prewarm_reports_a_tool_whose_init_produces_nothing"
# The stubs print nothing, so every cache write is empty and reported as a
# failure rather than silently written.
out_has "Failed to cache" "empty init reported"
assert_true "! [[ -s '$XDG_CACHE_HOME/zsh/starship-init.zsh' ]]" "no empty cache file kept"

test_start "prewarm_writes_a_cache_when_the_tool_emits_something"
cat >"$BIN/starship" <<STUB
#!$REAL_BASH
printf 'starship %s\\n' "\$*" >>"\$CALLS"
echo "eval starship init"
STUB
chmod +x "$BIN/starship"
run bash "$PREWARM"
assert_equals 0 "$RC" "rc"
assert_file_contains "$XDG_CACHE_HOME/zsh/starship-init.zsh" "eval starship init" "cache written"
assert_file_contains "$XDG_CACHE_HOME/bash/starship-init.bash" "eval starship init" "per-shell cache"
called "starship init zsh"

test_start "prewarm_generates_the_zsh_completions_it_can"
cat >"$BIN/gh" <<STUB
#!$REAL_BASH
printf 'gh %s\\n' "\$*" >>"\$CALLS"
echo "#compdef gh"
STUB
chmod +x "$BIN/gh"
run bash "$PREWARM"
assert_equals 0 "$RC" "rc"
called "gh completion -s zsh"
assert_file_contains "$XDG_DATA_HOME/zsh/completions/_gh" "#compdef gh" "completion written"

test_start "prewarm_refuses_to_run_twice_at_once"
LOCK="$XDG_RUNTIME_DIR/dotfiles-prewarm.lock"
NOFLOCK="$DOTFILES_COV_TMPDIR/noflock"
mkdir -p "$NOFLOCK" "${LOCK}.d"
ln -sf "$REAL_BASH" "$NOFLOCK/bash"
for c in printf echo cat tty locale uname sed grep tr dirname basename mkdir rm mv cut date head wc chmod touch id sort ln rmdir; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOFLOCK/$c"
done
run env PATH="$NOFLOCK" "$REAL_BASH" "$PREWARM"
assert_equals 0 "$RC" "rc"
out_has "Another instance is active" "lock respected"
rmdir "${LOCK}.d"

# ── teleport ────────────────────────────────────────────────────────────
test_start "teleport_requires_a_target"
run bash "$TELEPORT"
assert_equals 1 "$RC" "rc"
out_has "Usage: dot teleport user@host" "usage"

test_start "teleport_rejects_an_unsafe_target"
run bash "$TELEPORT" 'user@host; rm -rf /'
assert_equals 1 "$RC" "rc"
out_has "Invalid SSH target" "error"
out_has "Expected format: user@hostname" "hint"

test_start "teleport_pipes_the_chezmoi_archive_over_ssh"
# The ssh stub must *drain* the archive: teleport pipes `chezmoi archive`
# into it under `set -o pipefail`, so a stub that exits without reading
# gives the writer SIGPIPE and the script exits 141 (seen on Linux, where
# the timing differs from macOS).
cat >"$BIN/ssh" <<STUB
#!$REAL_BASH
printf 'ssh %s\n' "\$*" >>"\$CALLS"
cat >/dev/null
exit 0
STUB
chmod +x "$BIN/ssh"
cat >"$BIN/chezmoi" <<STUB
#!$REAL_BASH
printf 'chezmoi %s\\n' "\$*" >>"\$CALLS"
printf 'archive-bytes\\n'
STUB
chmod +x "$BIN/chezmoi"
run bash "$TELEPORT" deploy@example.com
assert_equals 0 "$RC" "rc"
out_has "Teleporting dotfiles to deploy@example.com" "announcement"
out_has "Teleport successful" "completion"
called "chezmoi archive"
called "ssh deploy@example.com tar xz -C"

# ── ai-setup ────────────────────────────────────────────────────────────
test_start "ai_setup_walks_the_whole_fleet"
for t in claude agy codex copilot goose kiro-cli kimi aider autohand vibe qwen zai; do
  record_stub "$t"
done
run bash "$AI_SETUP"
assert_equals 0 "$RC" "rc"
out_has "Universal AI Toolchain Setup" "header"
out_has "AI Setup Complete" "completion"
out_has "Setting up Claude CLI" "per-tool section"
called "claude --version"
called "codex --version"

test_start "ai_setup_skips_a_login_flow_when_stdin_is_not_a_terminal"
out_has "non-interactive shell; skipping login" "kiro login deferred"
assert_true "! grep -q 'kiro-cli login' '$CALLS'" "login not attempted"

test_start "ai_setup_reports_a_tool_that_is_not_installed"
NOAI="$DOTFILES_COV_TMPDIR/noai"
mkdir -p "$NOAI"
ln -sf "$REAL_BASH" "$NOAI/bash"
for c in printf echo cat tty locale uname sed grep tr dirname basename mkdir rm mv cut date head wc chmod touch id sort ln; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOAI/$c"
done
run env PATH="$NOAI" "$REAL_BASH" "$AI_SETUP"
assert_equals 0 "$RC" "rc"
out_has "Binary not found" "missing tool reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
