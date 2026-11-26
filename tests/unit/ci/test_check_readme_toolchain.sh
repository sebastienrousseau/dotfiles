#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# tools/ci/check-readme-toolchain.py: the README's toolchain badge and
# Requirements table must state the floors docs/MINIMUM-TOOLCHAIN.md sets,
# the chezmoi floor must be the version CI pins, and every platform the
# README names must be in the toolchain table.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHECK="$REPO_ROOT/tools/ci/check-readme-toolchain.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/readme-toolchain-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# fixture BASH ZSH PWSH GIT CHEZMOI CI_PIN PLATFORMS: the three files, with
# the README stating BASH..CHEZMOI and PLATFORMS, the table the real floors.
fixture() {
  cat >"$WORK/TOOLCHAIN.md" <<'EOF'
| Component | Floor | Why this floor | Enforced by |
|---|---|---|---|
| **bash** (running `dot`, `install.sh`, every script) | **3.2** | x | x |
| **bash** (as an *interactive* shell with the full config) | **5.0** | x | x |
| **zsh** | **5.8** | x | x |
| **PowerShell** | **7.5** | x | x |
| **git** | **2.34** | x | x |
| **chezmoi** | **2.74.1** | x | x |

| Platform | Ships bash | Ships zsh | Ships git | Meets the CLI floor? | In CI? |
|---|---|---|---|---|---|
| Ubuntu 22.04 LTS | 5.1 | 5.8 | 2.34 | Yes | No |
| Debian 12 (bookworm) | 5.2 | 5.9 | 2.39 | Yes | No |
| macOS 15+, stock `/bin/bash` | 3.2.57 | 5.9 | 2.39+ | Yes | Yes |
EOF
  printf 'env:\n  CHEZMOI_VERSION: "%s"\n' "$6" >"$WORK/ci.yml"
  cat >"$WORK/README.md" <<EOF
<a href="#requirements"><img src="https://img.shields.io/badge/toolchain-bash%20$1%20%C2%B7%20chezmoi%20$5-93450a?style=for-the-badge" alt="Minimum toolchain: bash $1, chezmoi $5" /></a>

## Requirements

| Requirement | Floor |
| :--- | :--- |
| Shells | bash $1+ and zsh $2+ (Tier 1); fish, nushell and PowerShell $3+ at lower tiers |
| chezmoi | $5+ (the installer fetches it, checksum-verified) |
| git | $4+ |
| curl | any current release |
| Platforms | $7 |
| Windows | PowerShell $3+ runs the native \`dot.ps1\` for the daily workflow |

## Quick Start
EOF
}

GOOD_PLATFORMS="macOS 15+, Ubuntu 22.04+, Debian 12+, WSL2; Fedora and Arch community-supported"

# check: run the checker on the fixture; sets rc and out.
check() {
  rc=0
  out="$(python3 "$CHECK" --readme "$WORK/README.md" --toolchain "$WORK/TOOLCHAIN.md" --ci "$WORK/ci.yml" 2>&1)" || rc=$?
}

test_start "matching_readme_passes"
fixture 5.0 5.8 7.5 2.34 2.74.1 2.74.1 "$GOOD_PLATFORMS"
check
assert_equals "0" "$rc" "floors, pin and platforms agree"

test_start "a_stale_chezmoi_in_the_readme_fails"
fixture 5.0 5.8 7.5 2.34 2.73.0 2.74.1 "$GOOD_PLATFORMS"
check
assert_equals "1" "$rc" "the README states an old chezmoi"
assert_contains "chezmoi" "$out" "the tool is named"
assert_contains "2.74.1" "$out" "with the expected floor"

test_start "a_ci_pin_that_moves_without_the_readme_fails"
fixture 5.0 5.8 7.5 2.34 2.74.1 2.75.0 "$GOOD_PLATFORMS"
check
assert_equals "1" "$rc" "CHEZMOI_VERSION moved; README and table did not"
assert_contains "CHEZMOI_VERSION" "$out" "the pin is named"

test_start "a_stale_shell_floor_fails"
fixture 4.4 5.8 7.4 2.34 2.74.1 2.74.1 "$GOOD_PLATFORMS"
check
assert_equals "1" "$rc" "bash and PowerShell floors disagree with the table"
assert_contains "bash" "$out" "bash is named"
assert_contains "PowerShell" "$out" "PowerShell is named"

test_start "an_unbacked_platform_fails"
fixture 5.0 5.8 7.5 2.34 2.74.1 2.74.1 "macOS 15+, Ubuntu 22.04+, NixOS 23.11+"
check
assert_equals "1" "$rc" "a platform the toolchain table does not list"
assert_contains "NixOS 23.11" "$out" "the platform is named"

test_start "repository_readme_passes"
rc=0
out="$(python3 "$CHECK" 2>&1)" || rc=$?
assert_equals "0" "$rc" "this repository's README, table and pin agree"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
