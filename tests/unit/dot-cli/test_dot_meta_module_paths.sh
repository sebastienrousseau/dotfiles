#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Execution paths of scripts/dot/commands/meta.sh.
#
# test_dot_commands_meta.sh drives cmd_upgrade by `eval`-ing the function out
# of the file, which measures nothing: the code runs from an eval string, not
# from meta.sh. And run from the checkout the module always finds the real
# README.md, docs/KEYS.md and executable_tour, so every "not present" arm was
# unreachable. This suite runs the module for real against a fixture source
# tree, with a PATH holding only the stubs each case wants found.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new meta-paths)"
mkdir -p "$FX/home" "$FX/stubs"
dot_fixture_basebin "$FX/basebin"
DOT_FIXTURE_HOME="$FX/home"

meta_run() {
  DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" dot_fixture_run "$FX" meta "$@"
}

# ── 1. upgrade: a failing phase is recorded, not fatal ─────────────────────
#
# The fonts phase is opt-in and needs the installer to exist in the source
# tree, so the fixture gets a stub one; the chezmoi phase is made to fail so
# the run reaches the failure summary at the end.
mkdir -p "$FX/scripts/fonts"
printf '#!/bin/sh\necho "fonts installed"\n' >"$FX/scripts/fonts/install-nerd-fonts.sh"
dot_fixture_stub "$FX/stubs" chezmoi 1
dot_fixture_stub "$FX/stubs" nvim 0

test_start "meta_upgrade_survives_a_failing_phase"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  DOTFILES_FONTS=1 dot_fixture_run "$FX" meta upgrade
assert_equals "0" "$DOT_FIXTURE_RC" "a failed phase must not abort the upgrade"
assert_contains "step(s) failed" "$DOT_FIXTURE_OUT" \
  "the run should end with a failure tally"

test_start "meta_upgrade_surfaces_the_failing_phase_log"
assert_contains "Dotfiles" "$DOT_FIXTURE_OUT" "the failing phase should be named"
assert_contains "Logs" "$DOT_FIXTURE_OUT" "the log directory should be reported"

test_start "meta_upgrade_runs_the_font_installer_when_enabled"
assert_contains "Nerd Fonts" "$DOT_FIXTURE_OUT" \
  "DOTFILES_FONTS=1 should add the fonts phase"

dot_fixture_stub "$FX/stubs" chezmoi 0

# ── 2. docs ────────────────────────────────────────────────────────────────
test_start "meta_docs_cats_the_readme_without_glow"
printf '# Fixture readme\n' >"$FX/README.md"
meta_run docs
assert_equals "0" "$DOT_FIXTURE_RC" "docs should exit 0"
assert_contains "Fixture readme" "$DOT_FIXTURE_OUT" \
  "with no glow on PATH the README should be catted"

test_start "meta_docs_reports_a_missing_readme"
rm -f "$FX/README.md"
meta_run docs
assert_equals "1" "$DOT_FIXTURE_RC" "docs without a README should exit 1"
assert_contains "README not found" "$DOT_FIXTURE_OUT" "the failure should say so"

# ── 3. learn walks both dot_local layouts before giving up ─────────────────
test_start "meta_learn_reports_a_missing_tour"
meta_run learn
assert_equals "1" "$DOT_FIXTURE_RC" "learn with no tour anywhere should exit 1"
assert_contains "not found" "$DOT_FIXTURE_OUT" "the failure should say so"

test_start "meta_learn_runs_the_legacy_tour_location"
mkdir -p "$FX/dot_local/bin"
printf '#!/bin/sh\necho "tour running"\n' >"$FX/dot_local/bin/executable_tour"
chmod +x "$FX/dot_local/bin/executable_tour"
meta_run learn
assert_equals "0" "$DOT_FIXTURE_RC" "the pre-.chezmoiroot layout should still work"
assert_contains "tour running" "$DOT_FIXTURE_OUT" "the tour should be executed"

# ── 4. keys sign-check ─────────────────────────────────────────────────────
#
# A git stub with settable answers, so each signing configuration can be
# staged without touching the developer's real git config.
meta_git_stub() {
  local key="$1" format="$2"
  cat >"$FX/stubs/git" <<STUB
#!/bin/sh
case "\$*" in
  *user.signingkey*) printf '%s\n' '$key' ;;
  *gpg.format*)      printf '%s\n' '$format' ;;
  *)                 : ;;
esac
exit 0
STUB
  chmod +x "$FX/stubs/git"
}

test_start "meta_keys_reports_a_missing_ssh_key_file"
meta_git_stub "$FX/home/.ssh/absent.pub" "ssh"
meta_run keys sign-check
assert_equals "0" "$DOT_FIXTURE_RC" "sign-check should report, not fail"
assert_contains "SSH key file not found" "$DOT_FIXTURE_OUT" \
  "a configured but absent SSH key should be called out"

test_start "meta_keys_finds_a_gpg_key_in_the_keyring"
meta_git_stub "ABCD1234" "gpg"
dot_fixture_stub "$FX/stubs" gpg 0
meta_run keys sign-check
assert_contains "GPG key found" "$DOT_FIXTURE_OUT" \
  "a resolvable GPG key should be reported as found"

test_start "meta_keys_reports_a_gpg_key_missing_from_the_keyring"
dot_fixture_stub "$FX/stubs" gpg 2
meta_run keys sign-check
assert_contains "GPG key not found" "$DOT_FIXTURE_OUT" \
  "an unresolvable GPG key should be called out"
rm -f "$FX/stubs/gpg" "$FX/stubs/git"

test_start "meta_keys_cats_the_catalogue"
mkdir -p "$FX/docs"
printf '# Fixture keys\n' >"$FX/docs/KEYS.md"
meta_run keys
assert_equals "0" "$DOT_FIXTURE_RC" "keys should exit 0"
assert_contains "Fixture keys" "$DOT_FIXTURE_OUT" "the catalogue should be printed"

# ── 5. sandbox picks a container runtime, or says it cannot ────────────────
test_start "meta_sandbox_falls_back_to_podman"
dot_fixture_stub "$FX/stubs" podman 0
meta_run sandbox
assert_equals "0" "$DOT_FIXTURE_RC" "podman should be accepted"
assert_contains "Podman" "$DOT_FIXTURE_OUT" "the podman path should be announced"

test_start "meta_sandbox_requires_a_container_runtime"
rm -f "$FX/stubs/podman"
meta_run sandbox
assert_equals "1" "$DOT_FIXTURE_RC" "no runtime at all should exit 1"
assert_contains "Docker or Podman is required" "$DOT_FIXTURE_OUT" \
  "the failure should name both options"

# ── 6. mcp ─────────────────────────────────────────────────────────────────
test_start "meta_mcp_doctor_reports_a_missing_helper"
meta_run mcp doctor
assert_equals "1" "$DOT_FIXTURE_RC" "mcp doctor without its script should exit 1"
assert_contains "MCP doctor script not found" "$DOT_FIXTURE_OUT" \
  "the missing helper should be named"

test_start "meta_mcp_registry_reports_a_missing_registry"
meta_run mcp registry
assert_equals "1" "$DOT_FIXTURE_RC" "an absent registry should exit 1"
assert_contains "MCP registry not found" "$DOT_FIXTURE_OUT" \
  "the failure should name the path it looked for"

test_start "meta_mcp_registry_cats_the_registry_without_jq"
mkdir -p "$FX/dot_config/dotfiles"
printf '{ "servers": {} }\n' >"$FX/dot_config/dotfiles/mcp-registry.json"
meta_run mcp registry
assert_equals "0" "$DOT_FIXTURE_RC" "registry should exit 0"
assert_contains '"servers"' "$DOT_FIXTURE_OUT" \
  "with no jq on PATH the registry should be catted verbatim"

# `dot mcp doctor` reaches the module as `meta.sh mcp doctor`, but the
# dispatcher in bin/dot can also hand the subcommand through twice; both
# spellings must land on the same place.
test_start "meta_mcp_tolerates_a_repeated_doctor_subcommand"
meta_run mcp doctor doctor
assert_equals "1" "$DOT_FIXTURE_RC" \
  "the repeated spelling should still reach the (absent) doctor script"
assert_contains "MCP doctor script not found" "$DOT_FIXTURE_OUT" \
  "and report the same missing helper"

test_start "meta_mcp_tolerates_a_repeated_registry_subcommand"
meta_run mcp registry registry
assert_equals "0" "$DOT_FIXTURE_RC" \
  "the repeated spelling should still print the registry"
assert_contains '"servers"' "$DOT_FIXTURE_OUT" "and print the same content"

test_start "meta_mcp_rejects_an_unknown_subcommand"
meta_run mcp nonsense
assert_equals "1" "$DOT_FIXTURE_RC" "an unknown mcp subcommand should exit 1"
assert_contains "Usage: dot mcp" "$DOT_FIXTURE_OUT" "it should print usage"

print_summary
