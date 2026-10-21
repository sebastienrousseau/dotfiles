#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Feature matrix: the ADR-020 domains that have no route of their own.
# `dot <domain> --help` lists the domain's commands from its manifest and
# exits 0 without running any of them (docs/reference/FEATURE-MATRIX.md).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# fm_domain DOMAIN SUMMARY: `dot DOMAIN --help` exits 0 and lists its commands.
fm_domain() {
  test_start "fm_domain_$1"
  fm_run "$1" --help
  fm_expect_rc 0
  test_start "fm_domain_$1_lists_its_commands"
  fm_expect_out "dot $1 · $2"
}

test_fm_domain_cli() { fm_domain cli "plugins, updates, completions"; }
test_fm_domain_config() { fm_domain config "apply, diff and sync the dotfiles"; }
test_fm_domain_secret() { fm_domain secret "secrets, keys and SSH certificates"; }
test_fm_domain_security() { fm_domain security "OS hardening"; }
test_fm_domain_session() { fm_domain session "find, open and restore terminal sessions"; }
test_fm_domain_shell() { fm_domain shell "aliases, history, startup caches"; }
test_fm_domain_system() { fm_domain system "updates, cleanup, scheduled maintenance"; }
test_fm_domain_tool() { fm_domain tool "toolchains, packages, project templates"; }
test_fm_domain_top() { fm_domain top "what the machine and its agents are doing"; }
test_fm_domain_ui() { fm_domain ui "primitives for scripts"; }

test_fm_domain_cli
test_fm_domain_config
test_fm_domain_secret
test_fm_domain_security
test_fm_domain_session
test_fm_domain_shell
test_fm_domain_system
test_fm_domain_tool
test_fm_domain_top
test_fm_domain_ui

fm_finish
