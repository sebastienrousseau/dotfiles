#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural contracts for install.sh's per-host chezmoi config rewrite and
# the profile selection that runs on the local-source and legacy-source
# apply paths. Each was a surviving mutant of tools/ci/mutation-test.py:
#   - the atomic rewrite must FAIL when it cannot create its temp file
#     (`mktemp ... || return 1`): the install aborts instead of applying
#     against a config that still points at a stale source dir.
#   - the atomic rewrite must FAIL when the awk program fails: the partial
#     temp file is discarded, the config is untouched, and the install
#     aborts (the `return 1` of the awk-failure branch).
#   - on the local-source path, `--minimal` selects the minimal profile
#     and a default run leaves the profile unselected (`-eq 1`).
#   - on the legacy-source path (~/.local/share/chezmoi is moved to
#     ~/.dotfiles), the same two outcomes hold (`-eq 1`).
#
# install.sh runs as a subprocess against a throwaway HOME with chezmoi,
# git, curl, mktemp and awk stubbed first on PATH, so nothing reaches the
# real home, the network or a package manager. mktemp and awk pass through
# to the real tools unless a case asks for a fault on the chezmoi config.

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"
WORK="$(mktemp -d -t dotfiles-install-config.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
# chezmoi: logs every call; `managed` lists nothing so no backup happens.
cat >"$WORK/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf 'chezmoi %s\n' "$*" >>"$TMP_LOG"
case "${1:-}" in
  --version) echo "chezmoi version stub" ;;
esac
exit 0
STUB
# git: logs every call; `config --global` answers nothing, so no identity
# is seeded and the config keeps exactly what the case wrote.
cat >"$WORK/bin/git" <<'STUB'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$TMP_LOG"
exit 0
STUB
printf '#!/usr/bin/env bash\nexit 1\n' >"$WORK/bin/curl"
# mktemp: with FAIL_CONFIG_MKTEMP=1, refuse a temp file for the chezmoi
# config (as a full or read-only config dir would); otherwise real mktemp.
cat >"$WORK/bin/mktemp" <<'STUB'
#!/usr/bin/env bash
if [[ "${FAIL_CONFIG_MKTEMP:-0}" == "1" ]]; then
  for a in "$@"; do
    if [[ "$a" == */chezmoi.toml.XXXXXX ]]; then
      echo "mktemp: stub refused $a" >&2
      exit 1
    fi
  done
fi
PATH=/usr/bin:/bin exec mktemp "$@"
STUB
# awk: with FAIL_CONFIG_AWK=1, an awk run over the chezmoi config emits a
# partial line and fails (as an I/O error mid-rewrite would); otherwise
# real awk.
cat >"$WORK/bin/awk" <<'STUB'
#!/usr/bin/env bash
if [[ "${FAIL_CONFIG_AWK:-0}" == "1" ]]; then
  for a in "$@"; do
    if [[ "$a" == */chezmoi.toml ]]; then
      printf 'PARTIAL-REWRITE'
      echo "awk: stub failed on $a" >&2
      exit 2
    fi
  done
fi
PATH=/usr/bin:/bin exec awk "$@"
STUB
chmod +x "$WORK/bin/chezmoi" "$WORK/bin/git" "$WORK/bin/curl" \
  "$WORK/bin/mktemp" "$WORK/bin/awk"

OUT=""
RC=0
# run_install <home> [VAR=value ...] [-- args...]: run install.sh
# non-interactively with <home> as HOME. Leading VAR=value words are extra
# environment (fault injection); words after `--` are install.sh
# arguments. Combined output lands in OUT, the exit status in RC, and
# every stub call in <home>/install.log.
run_install() {
  local home="$1"
  shift
  local -a extra_env=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    extra_env+=("$1")
    shift
  done
  [[ $# -gt 0 ]] && shift
  RC=0
  OUT="$(env -u SOURCE_DIR -u DOTFILES_PROVISION -u DOTFILES_MINIMAL \
    -u CODESPACES -u REMOTE_CONTAINERS \
    HOME="$home" TMP_LOG="$home/install.log" PATH="$WORK/bin:/usr/bin:/bin" \
    DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 \
    ${extra_env[@]+"${extra_env[@]}"} \
    "$BASH" "$INSTALL_SCRIPT" "$@" 2>&1)" || RC=$?
}

# new_home <name> <local|legacy>: a fresh HOME. `local` adds
# $HOME/.dotfiles/.git (apply-from-local-source path); `legacy` adds
# $HOME/.local/share/chezmoi/.git and no ~/.dotfiles (migration path).
new_home() {
  local h="$WORK/home-$1"
  mkdir -p "$h"
  case "$2" in
    local) mkdir -p "$h/.dotfiles/.git" ;;
    legacy) mkdir -p "$h/.local/share/chezmoi/.git" ;;
  esac
  printf '%s\n' "$h"
}

# write_config <home> <content...>: seed the per-host chezmoi config.
write_config() {
  local h="$1"
  shift
  mkdir -p "$h/.config/chezmoi"
  printf '%s\n' "$@" >"$h/.config/chezmoi/chezmoi.toml"
}

# apply_calls <home>: how many `chezmoi apply` invocations were logged.
apply_calls() {
  local n
  n="$(grep -c '^chezmoi apply' "$1/install.log" 2>/dev/null || true)"
  printf '%s\n' "${n:-0}"
}

# profile_lines <file>: the `profile = ...` lines of a config.
profile_lines() {
  grep '^profile[[:space:]]*=' "$1" 2>/dev/null || true
}

# The assert_* helpers return 1 on failure: tally every case, don't abort.
set +e

# ── config rewrite: temp file cannot be created ─────────────────────────
test_start "install_aborts_when_config_temp_file_cannot_be_created"
H="$(new_home mktemp-fail local)"
write_config "$H" 'sourceDir = "/stale/source"' '[data]' 'name = "n"'
run_install "$H" FAIL_CONFIG_MKTEMP=1
assert_not_equals 0 "$RC" "install exits non-zero when the config rewrite has no temp file"
assert_contains "stub refused $H/.config/chezmoi/chezmoi.toml.XXXXXX" "$OUT" \
  "the refused temp file is the chezmoi config's"
assert_equals 'sourceDir = "/stale/source"' "$(grep '^sourceDir' "$H/.config/chezmoi/chezmoi.toml")" \
  "the stale sourceDir is left as it was (nothing half-written)"
assert_equals 0 "$(apply_calls "$H")" "chezmoi apply never runs against the stale config"

# ── config rewrite: the awk program fails mid-way ───────────────────────
test_start "install_aborts_when_config_rewrite_program_fails"
H="$(new_home awk-fail local)"
write_config "$H" 'sourceDir = "/stale/source"' '[data]' 'name = "n"'
run_install "$H" FAIL_CONFIG_AWK=1
assert_not_equals 0 "$RC" "install exits non-zero when the rewrite program fails"
assert_contains "stub failed on $H/.config/chezmoi/chezmoi.toml" "$OUT" \
  "the failing program was the chezmoi config rewrite"
assert_equals 'sourceDir = "/stale/source"' "$(grep '^sourceDir' "$H/.config/chezmoi/chezmoi.toml")" \
  "the config keeps its original sourceDir"
assert_file_contains "$H/.config/chezmoi/chezmoi.toml" 'name = "n"' "the config keeps its [data]"
leftovers=("$H"/.config/chezmoi/chezmoi.toml.*)
assert_equals 0 "${#leftovers[@]}" "the partial temp file is removed"
assert_equals 0 "$(apply_calls "$H")" "chezmoi apply never runs after a failed rewrite"

# ── local-source path: profile selection ────────────────────────────────
test_start "install_default_run_leaves_profile_unselected_on_local_source"
H="$(new_home local-default local)"
write_config "$H" '[data]' 'name = "n"'
run_install "$H"
assert_equals 0 "$RC" "default local-source install exits 0"
assert_equals "" "$(profile_lines "$H/.config/chezmoi/chezmoi.toml")" \
  "a default run writes no profile key"
assert_equals "sourceDir = \"$H/.dotfiles\"" "$(grep '^sourceDir' "$H/.config/chezmoi/chezmoi.toml")" \
  "sourceDir points at the local source"
assert_equals 1 "$(apply_calls "$H")" "chezmoi apply runs once"

test_start "install_minimal_selects_profile_on_local_source"
H="$(new_home local-minimal local)"
write_config "$H" '[data]' 'name = "n"'
run_install "$H" -- --minimal
assert_equals 0 "$RC" "--minimal local-source install exits 0"
assert_equals 'profile = "minimal"' "$(profile_lines "$H/.config/chezmoi/chezmoi.toml")" \
  "--minimal writes exactly one profile key selecting minimal"
assert_file_contains "$H/.config/chezmoi/chezmoi.toml" 'name = "n"' "other [data] keys kept"
assert_equals 1 "$(apply_calls "$H")" "chezmoi apply runs once"

# ── legacy-source path: migration, then profile selection ───────────────
test_start "install_default_run_leaves_profile_unselected_on_legacy_source"
H="$(new_home legacy-default legacy)"
write_config "$H" '[data]' 'name = "n"'
run_install "$H"
assert_equals 0 "$RC" "default legacy-source install exits 0"
assert_contains "Migrating from legacy source: $H/.local/share/chezmoi" "$OUT" \
  "the legacy source is announced"
assert_dir_exists "$H/.dotfiles/.git" "the legacy source was moved to ~/.dotfiles"
assert_dir_not_exists "$H/.local/share/chezmoi" "the legacy location is gone"
assert_equals "sourceDir = \"$H/.dotfiles\"" "$(grep '^sourceDir' "$H/.config/chezmoi/chezmoi.toml")" \
  "sourceDir points at the migrated source"
assert_equals "" "$(profile_lines "$H/.config/chezmoi/chezmoi.toml")" \
  "a default run writes no profile key"
assert_equals 1 "$(apply_calls "$H")" "chezmoi apply runs once"

test_start "install_minimal_selects_profile_on_legacy_source"
H="$(new_home legacy-minimal legacy)"
write_config "$H" '[data]' 'name = "n"'
run_install "$H" -- --minimal
assert_equals 0 "$RC" "--minimal legacy-source install exits 0"
assert_contains "Migrating from legacy source: $H/.local/share/chezmoi" "$OUT" \
  "the legacy source is announced"
assert_dir_exists "$H/.dotfiles/.git" "the legacy source was moved to ~/.dotfiles"
assert_equals 'profile = "minimal"' "$(profile_lines "$H/.config/chezmoi/chezmoi.toml")" \
  "--minimal writes exactly one profile key selecting minimal"
assert_file_contains "$H/.config/chezmoi/chezmoi.toml" 'name = "n"' "other [data] keys kept"
assert_equals 1 "$(apply_calls "$H")" "chezmoi apply runs once"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
