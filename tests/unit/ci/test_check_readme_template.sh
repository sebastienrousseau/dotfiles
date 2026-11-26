#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behaviour of tools/ci/check-readme-template.py against fixture READMEs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHECK="$REPO_ROOT/tools/ci/check-readme-template.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/readme-template-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/TEMPLATE.md" <<'EOF'
<h1 align="center">{{PROJECT_NAME}}</h1>

## Contents

## Install

## Quick Start

## When not to use {{PROJECT_NAME}}

## License
EOF

# write_readme FILE HEADING...: a README with a centred h1 and the headings.
write_readme() {
  local file="$1" heading
  shift
  printf '<h1 align="center">demo</h1>\n' >"$file"
  for heading in "$@"; do printf '\n## %s\n\ntext\n' "$heading" >>"$file"; done
}

# check ARGS...: run the checker; sets rc and out.
check() {
  rc=0
  out="$(python3 "$CHECK" --template "$WORK/TEMPLATE.md" "$@" 2>&1)" || rc=$?
}

test_start "matching_readme_passes"
write_readme "$WORK/good.md" Contents Install "Quick Start" "When not to use demo" License
check --readme "$WORK/good.md" --enforce
assert_equals "0" "$rc" "a README in the template's order passes when enforcing"

test_start "reordered_headings_warn_in_report_mode"
write_readme "$WORK/order.md" Contents "Quick Start" Install "When not to use demo" License
check --readme "$WORK/order.md"
assert_equals "0" "$rc" "report mode never fails the job"
assert_contains "::warning" "$out" "the difference is annotated"
assert_contains "out of order" "$out" "the problem is named"

test_start "reordered_headings_fail_when_enforced"
check --readme "$WORK/order.md" --enforce
assert_equals "1" "$rc" "enforce mode fails on a reordered README"

test_start "missing_and_unexpected_headings_are_named"
write_readme "$WORK/extra.md" Contents Install "Quick Start" "Why this approach?" License
check --readme "$WORK/extra.md" --enforce
assert_equals "1" "$rc" "a missing heading fails"
assert_contains "missing heading: When not to use demo" "$out" "the missing heading is named"
assert_contains "unexpected heading: Why this approach?" "$out" "the extra heading is named"

test_start "unresolved_token_is_reported"
write_readme "$WORK/token.md" Contents Install "Quick Start" "When not to use demo" License
printf '\nInstall with {{INSTALL_COMMAND}}.\n' >>"$WORK/token.md"
check --readme "$WORK/token.md" --enforce
assert_equals "1" "$rc" "an unresolved token fails"
assert_contains "unresolved template variable: {{INSTALL_COMMAND}}" "$out" "the token is named"

test_start "late_quick_start_is_reported"
{
  printf '<h1 align="center">demo</h1>\n\n## Contents\n\n## Install\n'
  for _ in $(seq 1 120); do printf 'line\n'; done
  printf '\n## Quick Start\n\n## When not to use demo\n\n## License\n'
} >"$WORK/late.md"
check --readme "$WORK/late.md" --enforce
assert_equals "1" "$rc" "a Quick Start past line 90 fails"
assert_contains "Quick Start is at line" "$out" "the line is named"

# The Documentation section opens with the family's four links, labels in
# this order, so every repository's README points at the same four places.
printf '<h1 align="center">{{PROJECT_NAME}}</h1>\n\n## Install\n\n## Documentation\n\n## License\n' \
  >"$WORK/DOCS-TEMPLATE.md"
LINKS='**[User Manual](https://doc.example.org/) · [API reference](docs/api.md) · [Development](DEVELOPMENT.md) · [Ecosystem map](docs/ECOSYSTEM.md)**'

# docs_readme FILE FIRST-LINE: a README whose Documentation section opens
# with FIRST-LINE.
docs_readme() {
  printf '<h1 align="center">demo</h1>\n\n## Install\n\ntext\n\n## Documentation\n\n%s\n\nMore.\n\n## License\n' \
    "$2" >"$1"
}

test_start "documentation_links_pass"
docs_readme "$WORK/docs-ok.md" "$LINKS"
check --readme "$WORK/docs-ok.md" --template "$WORK/DOCS-TEMPLATE.md" --enforce
assert_equals "0" "$rc" "the four links in order pass"

test_start "documentation_links_missing_fail"
docs_readme "$WORK/docs-none.md" "See the manual."
check --readme "$WORK/docs-none.md" --template "$WORK/DOCS-TEMPLATE.md" --enforce
assert_equals "1" "$rc" "a Documentation section without the links fails"
assert_contains "four documentation links" "$out" "the problem is named"

test_start "documentation_links_reordered_fail"
docs_readme "$WORK/docs-order.md" \
  '**[API reference](docs/api.md) · [User Manual](https://doc.example.org/) · [Development](DEVELOPMENT.md) · [Ecosystem map](docs/ECOSYSTEM.md)**'
check --readme "$WORK/docs-order.md" --template "$WORK/DOCS-TEMPLATE.md" --enforce
assert_equals "1" "$rc" "the links out of order fail"

test_start "documentation_manual_must_be_a_url"
docs_readme "$WORK/docs-local.md" \
  '**[User Manual](docs/manual/) · [API reference](docs/api.md) · [Development](DEVELOPMENT.md) · [Ecosystem map](docs/ECOSYSTEM.md)**'
check --readme "$WORK/docs-local.md" --template "$WORK/DOCS-TEMPLATE.md" --enforce
assert_equals "1" "$rc" "a User Manual that is not the published site fails"

test_start "repository_readme_passes_enforced"
check --readme "$REPO_ROOT/README.md" --template "$REPO_ROOT/defaults/Code/README-TEMPLATE.md" --enforce
assert_equals "0" "$rc" "this repository's README matches the template"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
