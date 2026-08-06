#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Exhaustive runtime exercise of scripts/dot/commands/registry.sh.
#
# registry.sh only defines functions — the `dot` driver sources it and
# calls cmd_registry — so this test sources it the same way and drives
# every subcommand arm directly.
#
# No network: registry.sh resolves its index through curl, which speaks
# file://, and the module supports file:// URLs explicitly for local
# testing. We point it at a fixture index in the sandbox, so list /
# search / info walk real jq output rather than an empty cache.
#
# jq is optional on the plain unit-test runner; the arms that need it
# return 127 through _registry_require_jq and are recorded, not failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

REGISTRY_SCRIPT="$REPO_ROOT/scripts/dot/commands/registry.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "registry_file_exists"
assert_file_exists "$REGISTRY_SCRIPT" "registry.sh should exist"

# Fixture module and index. Two entries exercise search fields while
# the first points at a real, checksum-pinned chezmoi source archive.
MODULE_SOURCE="$DOTFILES_COV_TMPDIR/module-source/starship-preset"
mkdir -p "$MODULE_SOURCE"
printf '%s\n' 'export STARSHIP_CONFIG="$HOME/.config/starship.toml"' \
  >"$MODULE_SOURCE/dot_profile"
MODULE_ARCHIVE="$DOTFILES_COV_TMPDIR/starship-preset-1.2.0.tar.gz"
tar -czf "$MODULE_ARCHIVE" -C "$(dirname "$MODULE_SOURCE")" "$(basename "$MODULE_SOURCE")"
if command -v sha256sum >/dev/null 2>&1; then
  MODULE_SHA256="$(sha256sum "$MODULE_ARCHIVE" | awk '{print $1}')"
else
  MODULE_SHA256="$(shasum -a 256 "$MODULE_ARCHIVE" | awk '{print $1}')"
fi
FIXTURE="$DOTFILES_COV_TMPDIR/registry-index.json"
jq -n --arg archive_url "file://$MODULE_ARCHIVE" --arg sha256 "$MODULE_SHA256" '{
  version: 1,
  modules: [
    {
      name: "starship-preset",
      version: "1.2.0",
      description: "Opinionated starship prompt preset",
      tags: ["prompt", "shell"],
      archive_url: $archive_url,
      sha256: $sha256
    },
    {
      name: "nvim-minimal",
      version: "0.4.1",
      description: "Minimal Neovim configuration overlay",
      tags: ["editor"],
      archive_url: $archive_url,
      sha256: $sha256
    }
  ]
}' >"$FIXTURE"

EMPTY_FIXTURE="$DOTFILES_COV_TMPDIR/registry-empty.json"
printf '{"version":1,"modules":[]}\n' >"$EMPTY_FIXTURE"

# cov_setup_sandbox installs a curl shim that always returns an empty
# body — fine for callers that only check rc, but it would leave the
# registry index blank and collapse list/search/info into their
# empty-index arms. Replace it with one that resolves file:// by copy
# and fails anything else, so the fetch path is exercised for real
# while staying offline.
cat >"$DOTFILES_COV_TMPDIR/bin/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="${2:-}"; shift 2 ;;
    file://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
[[ -n "$url" ]] || exit 1
src="${url#file://}"
[[ -f "$src" ]] || exit 22
if [[ -n "$out" ]]; then cp "$src" "$out"; else cat "$src"; fi
exit 0
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/curl"

# Record chezmoi calls so preview and apply behavior can be asserted.
cat >"$DOTFILES_COV_TMPDIR/bin/chezmoi" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DOTFILES_COV_TMPDIR/chezmoi.calls"
exit 0
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/chezmoi"

# Source registry.sh the way the dot driver does. It runs under
# `set -euo pipefail`; the arms below deliberately return non-zero, so
# errexit is relaxed for the duration of the sweep.
set +e
source "$REGISTRY_SCRIPT"
set -e

# ex <label> <args…> — call cmd_registry, tolerate any rc.
ex() {
  local label="$1"
  shift
  test_start "registry_ex_${label}"
  set +e
  cmd_registry "$@" </dev/null >/dev/null 2>&1
  local rc=$?
  set -e
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
}

# ── url resolution ───────────────────────────────────────────────────
# Default URL (no config, no env override).
ex url_default url

# set-url validation: scheme must be https:// or file://.
ex set_url_noarg set-url
ex set_url_bad_scheme set-url "http://example.com/registry.json"
ex set_url_ftp_scheme set-url "ftp://example.com/registry.json"

# Persist a file:// URL, then confirm _registry_url reads it back out
# of the config file rather than falling through to the default.
ex set_url_file set-url "file://$FIXTURE"

test_start "registry_set_url_persists"
cfg="$(_registry_config_file)"
if [[ -f "$cfg" ]] && grep -q "$FIXTURE" "$cfg"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: url written to $cfg"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: config not written"
fi

test_start "registry_url_reads_config"
if [[ "$(_registry_url)" == "file://$FIXTURE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: resolved from config"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got $(_registry_url)"
fi

# ── index-backed arms ────────────────────────────────────────────────
# The 6h cache means a second call reuses the fetched index; clear it
# between URL switches so the fetch path re-executes.
_clear_cache() { rm -rf "$(_registry_cache_dir)"; }

export DOTFILES_REGISTRY_URL="file://$FIXTURE"
_clear_cache

ex list_default
ex list list
ex list_cached list
ex search_name search starship
ex search_description search neovim
ex search_tag search editor
ex search_miss search zzzznomatch
ex search_noarg search
ex info_hit info starship-preset
ex info_miss info not-a-module
ex info_noarg info
ex install_noarg install
ex install_preview install starship-preset
test_start "registry_install_preview_is_non_mutating"
if [[ ! -e "$XDG_DATA_HOME/dotfiles/modules/starship-preset" ]] &&
  grep -q -- '--dry-run' "$DOTFILES_COV_TMPDIR/chezmoi.calls"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

ex install_apply install starship-preset --yes
test_start "registry_install_apply_persists_verified_source"
installed="$XDG_DATA_HOME/dotfiles/modules/starship-preset/1.2.0"
if [[ -f "$installed/dot_profile" ]] &&
  [[ -f "$XDG_DATA_HOME/dotfiles/modules/starship-preset/installed.json" ]] &&
  [[ "$(grep -c -- '--dry-run' "$DOTFILES_COV_TMPDIR/chezmoi.calls")" -eq 2 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi
ex installed installed
ex install_miss install not-a-module
ex install_bad_option install starship-preset --force
ex help --help
ex unknown definitely-not-a-subcommand

# Empty index — the "no modules published yet" arm.
export DOTFILES_REGISTRY_URL="file://$EMPTY_FIXTURE"
_clear_cache
ex list_empty list

# Unreachable URL with no cache — the fetch-failure arm.
export DOTFILES_REGISTRY_URL="file://$DOTFILES_COV_TMPDIR/does-not-exist.json"
_clear_cache
ex list_fetch_fails list

# Link-bearing archives are rejected before extraction.
LINK_SOURCE="$DOTFILES_COV_TMPDIR/link-source"
mkdir -p "$LINK_SOURCE"
ln -s /etc/passwd "$LINK_SOURCE/unsafe-link"
LINK_ARCHIVE="$DOTFILES_COV_TMPDIR/link-module.tar.gz"
tar -czf "$LINK_ARCHIVE" -C "$LINK_SOURCE" .
test_start "registry_rejects_link_archive"
if _registry_archive_is_safe "$LINK_ARCHIVE" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: link archive accepted"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# Env override beats the config file.
test_start "registry_env_override_wins"
export DOTFILES_REGISTRY_URL="file:///tmp/override.json"
if [[ "$(_registry_url)" == "file:///tmp/override.json" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: env override honoured"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got $(_registry_url)"
fi
unset DOTFILES_REGISTRY_URL

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
