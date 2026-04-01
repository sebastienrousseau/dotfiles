#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Documentation accuracy — validates that docs reference
# real files, commands, and features that actually exist in the codebase.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ═══════════════════════════════════════════════════════════════
# 1. README.md — claims must match reality
# ═══════════════════════════════════════════════════════════════

test_start "readme_install_url_valid"
# Install URL must point to install.sh on master
assert_file_contains "$REPO_ROOT/README.md" "raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh" "README install URL must reference master/install.sh"

test_start "readme_dot_doctor_exists"
assert_file_contains "$REPO_ROOT/README.md" "dot doctor" "README must reference dot doctor"

test_start "readme_dot_learn_exists"
assert_file_contains "$REPO_ROOT/README.md" "dot learn" "README must reference dot learn"

test_start "readme_version_badge_present"
assert_file_contains "$REPO_ROOT/README.md" "Version-v" "README must have version badge"

test_start "readme_first_5_minutes_section"
assert_file_contains "$REPO_ROOT/README.md" "First 5 Minutes" "README must have First 5 Minutes section"

test_start "readme_references_profiles_doc"
assert_file_contains "$REPO_ROOT/README.md" "PROFILES.md" "README must link to PROFILES.md"

test_start "readme_references_features_doc"
assert_file_contains "$REPO_ROOT/README.md" "FEATURES.md" "README must link to FEATURES.md"

test_start "readme_references_migration_doc"
assert_file_contains "$REPO_ROOT/README.md" "MIGRATION.md" "README must link to MIGRATION.md"

# ═══════════════════════════════════════════════════════════════
# 2. AI.md — documented providers must exist in code
# ═══════════════════════════════════════════════════════════════

test_start "ai_doc_bridge_commands_match_code"
# Every bridge command documented in AI.md must exist in ai.sh dispatch
ai_script="$REPO_ROOT/scripts/dot/commands/ai.sh"
failures=0
for cmd in cl copilot gemini kiro sgpt ollama opencode aider autohand vibe qwen zai; do
  if grep -q "dot $cmd" "$REPO_ROOT/docs/AI.md" 2>/dev/null; then
    if ! grep -q "$cmd" "$ai_script" 2>/dev/null; then
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "all AI.md bridge commands must exist in ai.sh"

test_start "ai_doc_no_removed_providers"
# Cline was removed — docs must not reference it
assert_output_not_contains "dot cline" "grep -F 'dot cline' '$REPO_ROOT/docs/AI.md'"

# ═══════════════════════════════════════════════════════════════
# 3. FEATURES.md — documented flags must exist in .chezmoidata.toml
# ═══════════════════════════════════════════════════════════════

test_start "features_doc_flags_match_chezmoidata"
failures=0
for flag in alias_wrapper dms zellij linux_desktop niri waybar fuzzel mako foot kanshi touch t2 surface; do
  if ! grep -q "$flag" "$REPO_ROOT/.chezmoidata.toml" 2>/dev/null; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all FEATURES.md flags must exist in .chezmoidata.toml"

# ═══════════════════════════════════════════════════════════════
# 4. PROFILES.md — documented presets must exist
# ═══════════════════════════════════════════════════════════════

test_start "profiles_doc_preset_files_exist"
failures=0
for preset in mac-m1 geekom-a9 surface-pro-7p mac-t2-linux; do
  if ! ls "$REPO_ROOT/templates/chezmoi-data/${preset}"* >/dev/null 2>&1; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all PROFILES.md presets must have matching template files"

# ═══════════════════════════════════════════════════════════════
# 5. TOOLS.md — documented tools must be in mise config
# ═══════════════════════════════════════════════════════════════

test_start "tools_doc_ai_tools_in_mise"
mise_config="$REPO_ROOT/dot_config/mise/config.toml"
failures=0
for tool in claude copilot gemini ollama opencode aider; do
  if grep -q "$tool" "$REPO_ROOT/docs/reference/TOOLS.md" 2>/dev/null; then
    if ! grep -qi "$tool" "$mise_config" 2>/dev/null; then
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "AI tools in TOOLS.md must be in mise config"

test_start "tools_doc_no_cline"
assert_output_not_contains "Cline" "grep -F 'Cline' '$REPO_ROOT/docs/reference/TOOLS.md'"

# ═══════════════════════════════════════════════════════════════
# 6. UTILS.md — documented commands must exist in dot CLI
# ═══════════════════════════════════════════════════════════════

test_start "utils_doc_commands_exist"
dot_cli="$REPO_ROOT/dot_local/bin/executable_dot"
failures=0
for cmd in apply doctor heal rollback bundle secrets; do
  if grep -q "dot $cmd" "$REPO_ROOT/docs/reference/UTILS.md" 2>/dev/null; then
    if ! grep -q "$cmd" "$dot_cli" 2>/dev/null; then
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "all UTILS.md commands must exist in dot CLI"

test_start "utils_doc_no_cline"
assert_output_not_contains "cline" "grep -F 'dot cline' '$REPO_ROOT/docs/reference/UTILS.md'"

# ═══════════════════════════════════════════════════════════════
# 7. INSTALL.md — documented steps must match install.sh
# ═══════════════════════════════════════════════════════════════

test_start "install_doc_has_help_flag"
assert_file_contains "$REPO_ROOT/docs/guides/INSTALL.md" "help" "INSTALL.md must document --help"

test_start "install_doc_mentions_chezmoi"
assert_file_contains "$REPO_ROOT/docs/guides/INSTALL.md" "chezmoi" "INSTALL.md must mention chezmoi"

# ═══════════════════════════════════════════════════════════════
# 8. MIGRATION.md — version references must be current
# ═══════════════════════════════════════════════════════════════

test_start "migration_doc_exists"
assert_file_exists "$REPO_ROOT/docs/operations/MIGRATION.md" "MIGRATION.md must exist"

test_start "migration_doc_has_rollback"
assert_file_contains "$REPO_ROOT/docs/operations/MIGRATION.md" "rollback" "MIGRATION.md must document rollback"

test_start "migration_doc_has_upgrade_workflow"
assert_file_contains "$REPO_ROOT/docs/operations/MIGRATION.md" "dot apply" "MIGRATION.md must document upgrade via dot apply"

# ═══════════════════════════════════════════════════════════════
# 9. ENCRYPTION.md — documented commands must work
# ═══════════════════════════════════════════════════════════════

test_start "encryption_doc_exists"
assert_file_exists "$REPO_ROOT/docs/security/ENCRYPTION.md" "ENCRYPTION.md must exist"

test_start "encryption_doc_references_age"
assert_file_contains "$REPO_ROOT/docs/security/ENCRYPTION.md" "age-keygen" "ENCRYPTION.md must document age key generation"

test_start "encryption_doc_references_sops"
assert_file_contains "$REPO_ROOT/docs/security/ENCRYPTION.md" "sops" "ENCRYPTION.md must document sops"

# ═══════════════════════════════════════════════════════════════
# 10. CROSS-DOC LINK INTEGRITY — internal links resolve
# ═══════════════════════════════════════════════════════════════

test_start "doc_links_resolve"
# Check that markdown links to other docs files actually exist
broken=0
while IFS= read -r doc; do
  # Extract relative links like [text](../path/FILE.md) or [text](path/FILE.md)
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    [[ "$link" == http* ]] && continue
    [[ "$link" == "#"* ]] && continue
    [[ "$link" == /* ]] && continue  # Skip absolute paths (env-specific)
    # Resolve relative to the doc's directory
    doc_dir="$(dirname "$doc")"
    target="$doc_dir/$link"
    # Remove anchor fragments
    target="${target%%#*}"
    if [[ ! -f "$target" && ! -d "$target" ]]; then
      broken=$((broken + 1))
    fi
  done < <(grep -oE '\]\([^)]+\)' "$doc" 2>/dev/null | sed 's/\](//' | sed 's/)//' | grep -v '^http' | grep -v '^#')
done < <(find "$REPO_ROOT/docs" -name "*.md" -not -path "*/archive/*" 2>/dev/null)
# Also check README.md
while IFS= read -r link; do
  [[ -z "$link" ]] && continue
  [[ "$link" == http* ]] && continue
  [[ "$link" == "#"* ]] && continue
  [[ "$link" == /* ]] && continue
  target="$REPO_ROOT/$link"
  target="${target%%#*}"
  if [[ ! -f "$target" && ! -d "$target" ]]; then
    broken=$((broken + 1))
  fi
done < <(grep -oE '\]\([^)]+\)' "$REPO_ROOT/README.md" 2>/dev/null | sed 's/\](//' | sed 's/)//' | grep -v '^http' | grep -v '^#' | grep -v 'codespaces')
if [[ "$broken" -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all internal doc links resolve"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $broken broken internal doc links"
fi

# ═══════════════════════════════════════════════════════════════
# 11. CLAUDE.md — project instructions must be accurate
# ═══════════════════════════════════════════════════════════════

test_start "claudemd_references_test_runner"
assert_file_contains "$REPO_ROOT/CLAUDE.md" "test_runner.sh" "CLAUDE.md must reference test runner"

test_start "claudemd_references_chezmoidata"
assert_file_contains "$REPO_ROOT/CLAUDE.md" ".chezmoidata.toml" "CLAUDE.md must reference .chezmoidata.toml"

test_start "claudemd_shellcheck_flags"
assert_file_contains "$REPO_ROOT/CLAUDE.md" "SC1091" "CLAUDE.md must document shellcheck exclusions"

# ═══════════════════════════════════════════════════════════════
# 12. MAN PAGE — must document current commands
# ═══════════════════════════════════════════════════════════════

test_start "manpage_exists"
assert_file_exists "$REPO_ROOT/dot_local/share/man/man1/dot.1" "dot.1 man page must exist"

test_start "manpage_documents_ai"
assert_file_contains "$REPO_ROOT/dot_local/share/man/man1/dot.1" "autohand" "man page must document new AI CLIs"

test_start "manpage_documents_extensions"
assert_file_contains "$REPO_ROOT/dot_local/share/man/man1/dot.1" "modules.d" "man page must document user extension points"

test_start "manpage_no_cline"
# Man page must not reference removed Cline CLI
assert_output_not_contains "cline" "cat '$REPO_ROOT/dot_local/share/man/man1/dot.1'"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
