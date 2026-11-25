#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# Issue forms: GitHub only rejects a malformed form once it is on the
# default branch, so their shape is checked here first.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DIR="$REPO_ROOT/.github/ISSUE_TEMPLATE"
FORMS=(bug_report feature_request plugin_proposal docs)

test_start "forms_present"
for form in "${FORMS[@]}"; do
  assert_file_exists "$DIR/$form.yml" "$form is an issue form"
done
test_start "legacy_bug_template_removed"
if [[ -e "$DIR/bug_report.md" ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: bug_report.md would shadow the form"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

if ! python3 -c 'import yaml' 2>/dev/null; then
  printf '%b\n' "  ${YELLOW}∼${NC} form_schema: skipped (PyYAML unavailable)"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# form_problems FILE: one line per schema problem, nothing when the form is valid.
form_problems() {
  python3 - "$1" <<'PY'
import sys, yaml
path = sys.argv[1]
known = {"type:bug", "type:enhancement", "type:docs", "type:security"}
try:
    form = yaml.safe_load(open(path, encoding="utf-8"))
except Exception as err:  # noqa: BLE001 - any parse failure is the finding
    print(f"does not parse: {err}")
    sys.exit()
for key in ("name", "description", "body"):
    if not form.get(key):
        print(f"missing {key}")
for label in form.get("labels", []):
    if label not in known:
        print(f"unknown label {label}")
ids = []
for item in form.get("body", []):
    kind = item.get("type")
    if kind not in {"markdown", "input", "textarea", "dropdown", "checkboxes"}:
        print(f"unknown field type {kind}")
    if kind == "markdown":
        continue
    if not item.get("attributes", {}).get("label"):
        print(f"{kind} without a label")
    if not item.get("id"):
        print(f"{kind} without an id")
    ids.append(item.get("id"))
if len(ids) != len(set(ids)):
    print("duplicate field ids")
if not any(i.get("validations", {}).get("required") for i in form.get("body", [])):
    print("no required field")
PY
}

test_start "form_schema"
for form in "${FORMS[@]}"; do
  [[ -f "$DIR/$form.yml" ]] || continue
  assert_equals "" "$(form_problems "$DIR/$form.yml")" "$form.yml matches the issue-form schema"
done

test_start "chooser_config"
config="$(python3 -c 'import sys, yaml; c = yaml.safe_load(open(sys.argv[1])); print(c.get("blank_issues_enabled"), any("security/advisories" in l.get("url", "") for l in c.get("contact_links", [])))' "$DIR/config.yml" 2>&1)"
assert_equals "False True" "$config" "blank issues are off and vulnerabilities go to a private advisory"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
