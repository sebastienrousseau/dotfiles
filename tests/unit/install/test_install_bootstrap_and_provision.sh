#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Runs install.sh against stubbed git, chezmoi, curl and uname for two paths
# the core mutation run found untested: an OS the chezmoi bootstrap does not
# support stops the install before anything is cloned, and --provision runs
# the cloned provisioning scripts.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-install-run.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# stub <dir> <name> <body>: an executable stub that also logs its call.
stub() {
  printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >>"$TMP_LOG"\n%s\n' "$2" "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# run_install <case-dir> [args...]: install.sh with the case's stubs first on
# PATH and the case's HOME.
run_install() {
  local dir="$1"
  shift
  TMP_LOG="$dir/log" PATH="$dir/bin:/usr/bin:/bin" HOME="$dir/home" \
    DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 \
    bash "$dir/install.sh" "$@" >"$dir/out" 2>&1
}

# ── unsupported OS ──────────────────────────────────────────────────────
# A standalone copy (no repo beside it) takes the embedded bootstrap.
OS_CASE="$WORK/os"
mkdir -p "$OS_CASE/bin" "$OS_CASE/home"
cp "$REPO_ROOT/install.sh" "$OS_CASE/install.sh"
stub "$OS_CASE/bin" uname 'case "${1:-}" in -m) echo amd64 ;; *) echo FreeBSD ;; esac'
stub "$OS_CASE/bin" curl 'exit 1'
stub "$OS_CASE/bin" git 'exit 0'
: >"$OS_CASE/log"

test_start "unsupported_os_stops_the_install"
run_install "$OS_CASE"
rc=$?
assert_not_equals "0" "$rc" "install.sh fails"
assert_file_contains "$OS_CASE/out" "Unsupported OS for chezmoi bootstrap: freebsd" "and names the OS"
cloned=no
grep -q '^git clone' "$OS_CASE/log" && cloned=yes
assert_equals "no" "$cloned" "nothing is cloned without chezmoi"

# ── --provision ─────────────────────────────────────────────────────────
# prov_case <name>: a case dir whose git stub clones a source with one
# provisioning script that marks $HOME/provisioned.
prov_case() {
  PROV_CASE="$WORK/$1"
  mkdir -p "$PROV_CASE/bin" "$PROV_CASE/home"
  cp "$REPO_ROOT/install.sh" "$PROV_CASE/install.sh"
  : >"$PROV_CASE/log"
  stub "$PROV_CASE/bin" chezmoi 'exit 0'
  stub "$PROV_CASE/bin" curl 'exit 1'
  stub "$PROV_CASE/bin" git '
if [[ "$1" == "clone" ]]; then
  dest="${*: -1}"
  mkdir -p "$dest/.git" "$dest/defaults" "$dest/install/provision"
  printf "profile = \"default\"\n" >"$dest/defaults/.chezmoidata.toml"
  printf "#!/usr/bin/env bash\ntouch \"\$HOME/provisioned\"\n" \
    >"$dest/install/provision/run_onchange_10-mark.sh"
fi
[[ "$1" == "describe" ]] && exit 1
[[ "$1" == "rev-parse" ]] && echo v0.2.500
exit 0'
}

test_start "provision_runs_the_cloned_scripts"
prov_case prov
run_install "$PROV_CASE" --provision
assert_equals "0" "$?" "install.sh --provision succeeds"
assert_file_exists "$PROV_CASE/home/provisioned" "the provisioning script ran"

# The minimal profile skips provisioning however it was selected: --minimal,
# DOTFILES_MINIMAL=1, or a detected container (Codespaces here).
test_start "minimal_profile_from_the_environment_skips_provisioning"
prov_case prov-env
DOTFILES_MINIMAL=1 run_install "$PROV_CASE" --provision
assert_equals "0" "$?" "install.sh succeeds"
assert_file_not_exists "$PROV_CASE/home/provisioned" "DOTFILES_MINIMAL=1 does not provision"

test_start "container_minimal_profile_skips_provisioning"
prov_case prov-container
CODESPACES=1 run_install "$PROV_CASE"
assert_equals "0" "$?" "install.sh succeeds"
assert_false 'grep -q "install.sh\" --provision" "$PROV_CASE/out"' "a container is not offered the provisioning hint"
prov_case prov-container2
CODESPACES=1 run_install "$PROV_CASE" --provision
assert_file_not_exists "$PROV_CASE/home/provisioned" "a container does not provision"

test_summary
