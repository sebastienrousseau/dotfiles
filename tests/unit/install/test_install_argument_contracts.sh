#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural contracts for install.sh's argument handling and the steps it
# gates. Each was a surviving mutant of tools/ci/mutation-test.py, i.e. a
# deliberate bug no behavioural test caught:
#   - I2: a positional version is a WHOLE semver. Text before the number
#         (`x1.2.3`) is rejected up front instead of being cloned as a ref
#         (regex anchor `^`; the `$` anchor gets a companion case).
#   - I4: `--minimal` over a host config that already selects a profile
#         must leave profile = "minimal" — the rewrite of an existing key
#         is checked by value, not merely by count.
#   - I5: the backup step reports exactly ONE backed-up file and keeps the
#         backup dir; only a count of zero is reported as nothing and
#         dropped (boundary `-gt 0`).
#
# install.sh runs as a subprocess against a throwaway HOME with chezmoi,
# git and curl stubbed first on PATH, so nothing reaches the real home,
# the network or a package manager.

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"
WORK="$(mktemp -d -t dotfiles-install-args.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
# chezmoi: logs every call. `managed` names two candidate files; a case
# pre-creates none or one of them to pin the backup count exactly.
cat >"$WORK/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf 'chezmoi %s\n' "$*" >>"$TMP_LOG"
case "${1:-}" in
  --version) echo "chezmoi version stub" ;;
  managed) printf '%s\n' "$HOME/.zshrc" "$HOME/.bashrc" ;;
esac
exit 0
STUB
# git: logs every call; `clone` fabricates the destination so the
# from-GitHub path completes without a network.
cat >"$WORK/bin/git" <<'STUB'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$TMP_LOG"
if [[ "${1:-}" == "clone" ]]; then
  mkdir -p "${@: -1}/.git"
fi
exit 0
STUB
printf '#!/usr/bin/env bash\nexit 1\n' >"$WORK/bin/curl"
chmod +x "$WORK/bin/chezmoi" "$WORK/bin/git" "$WORK/bin/curl"

OUT=""
RC=0
# run_install <home> [args...]: run install.sh non-interactively with
# <home> as HOME. Combined output lands in OUT, the exit status in RC, and
# every stub call in <home>/install.log.
run_install() {
  local home="$1"
  shift
  RC=0
  OUT="$(env -u SOURCE_DIR -u DOTFILES_PROVISION -u DOTFILES_MINIMAL \
    -u CODESPACES -u REMOTE_CONTAINERS \
    HOME="$home" TMP_LOG="$home/install.log" PATH="$WORK/bin:/usr/bin:/bin" \
    DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 \
    "$BASH" "$INSTALL_SCRIPT" "$@" 2>&1)" || RC=$?
}

# new_home <name> [local]: a fresh HOME; `local` adds $HOME/.dotfiles/.git
# so install.sh takes the apply-from-local-source path.
new_home() {
  local h="$WORK/home-$1"
  mkdir -p "$h"
  [[ "${2:-}" == "local" ]] && mkdir -p "$h/.dotfiles/.git"
  printf '%s\n' "$h"
}

# The assert_* helpers return 1 on failure: tally every case, don't abort.
set +e

# ── I2: a positional version is a whole semver ──────────────────────────
test_start "install_accepts_whole_semver_positional"
H="$(new_home accept)"
run_install "$H" 1.2.3
assert_equals 0 "$RC" "whole version is accepted"
assert_contains "git clone --depth 1 --branch 1.2.3 " "$(cat "$H/install.log")" \
  "accepted version is the ref that gets cloned"

test_start "install_rejects_text_before_version"
H="$(new_home prefix)"
run_install "$H" x1.2.3
assert_equals 1 "$RC" "junk-prefixed version exits 1"
assert_contains "Unrecognized positional argument 'x1.2.3'" "$OUT" "prefix rejected by name"
assert_file_not_exists "$H/install.log" "rejected before any tool ran"

test_start "install_rejects_text_after_version"
H="$(new_home suffix)"
run_install "$H" 1.2.3x
assert_equals 1 "$RC" "junk-suffixed version exits 1"
assert_contains "Unrecognized positional argument '1.2.3x'" "$OUT" "suffix rejected by name"
assert_file_not_exists "$H/install.log" "rejected before any tool ran"

# ── I4: --minimal replaces an existing profile selection by value ───────
test_start "install_minimal_replaces_existing_profile_value"
H="$(new_home minimal local)"
mkdir -p "$H/.config/chezmoi"
printf '[data]\nprofile = "laptop"\nname = "n"\n' >"$H/.config/chezmoi/chezmoi.toml"
run_install "$H" --minimal
assert_equals 0 "$RC" "local-source install with --minimal exits 0"
assert_equals 'profile = "minimal"' "$(grep '^profile' "$H/.config/chezmoi/chezmoi.toml")" \
  "the existing profile key now selects minimal"
assert_file_contains "$H/.config/chezmoi/chezmoi.toml" 'name = "n"' "other [data] keys kept"

# ── I5: backup count boundary (zero vs exactly one) ─────────────────────
test_start "install_backup_reports_exactly_one_file"
H="$(new_home one local)"
printf 'export ONE=1\n' >"$H/.zshrc"
run_install "$H"
assert_equals 0 "$RC" "install exits 0"
assert_contains "Backed up 1 files to $H/.dotfiles.bak." "$OUT" "single backup reported"
backups=("$H"/.dotfiles.bak.*)
assert_equals 1 "${#backups[@]}" "the backup directory is kept"
assert_file_contains "${backups[0]:-/nonexistent}/.zshrc" "export ONE=1" \
  "backed-up copy holds the original content"

test_start "install_backup_reports_nothing_for_zero_files"
H="$(new_home zero local)"
run_install "$H"
assert_equals 0 "$RC" "install exits 0"
assert_contains "No existing dotfiles to back up." "$OUT" "zero backups reported as none"
backups=("$H"/.dotfiles.bak.*)
assert_equals 0 "${#backups[@]}" "the empty backup directory is removed"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
