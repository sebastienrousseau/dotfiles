#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Flesch reading compliance — validates that user-facing
# documentation meets plain-English readability standards.
#
# Target: Flesch Reading Ease 60-70 (Standard/Plain English, 8th-9th grade)
# Method: Proxy metrics (sentence length, word complexity, passive voice)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# User-facing docs that must meet readability standards
USER_DOCS=(
  README.md
  docs/AI.md
  docs/operations/MIGRATION.md
  docs/reference/PROFILES.md
  docs/reference/FEATURES.md
  docs/security/ENCRYPTION.md
  docs/guides/INSTALL.md
)

# Extract prose from markdown (strip code blocks, tables, HTML, links)
_extract_prose() {
  awk '/^```/{skip=!skip; next} !skip{print}' "$1" | # Remove fenced code blocks
    sed '/^|/d' |                   # Remove tables
    sed '/^<[^>]*>$/d' |           # Remove HTML-only lines
    sed 's/\[[^]]*\]([^)]*)//g' |  # Strip link syntax
    sed '/^##* /d' |                # Remove headings
    sed '/^$/d' |                   # Remove blank lines
    sed '/^---$/d' |                # Remove horizontal rules
    sed '/^- \[/d'                  # Remove checkbox lines
}

# Count words in text
_word_count() {
  echo "$1" | wc -w | tr -d ' '
}

# Count sentences (periods, exclamation, question marks)
_sentence_count() {
  echo "$1" | grep -oE '[.!?]' | wc -l | tr -d ' '
}

# Average words per sentence
_avg_sentence_length() {
  words=$(_word_count "$1")
  sentences=$(_sentence_count "$1")
  if [[ "$sentences" -eq 0 ]]; then
    echo "0"
    return
  fi
  echo $((words / sentences))
}

# Count complex words (4+ syllables, approximated by length 10+ chars)
_complex_word_pct() {
  total=$(_word_count "$1")
  if [[ "$total" -eq 0 ]]; then
    echo "0"
    return
  fi
  complex=$(echo "$1" | tr ' ' '\n' | awk 'length >= 10' | wc -l | tr -d ' ')
  echo $((complex * 100 / total))
}

# ═══════════════════════════════════════════════════════════════
# 1. SENTENCE LENGTH — average must be 15-25 words
# ═══════════════════════════════════════════════════════════════

test_start "flesch_sentence_length"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prose=$(_extract_prose "$filepath")
  avg=$(_avg_sentence_length "$prose")
  if [[ "$avg" -gt 30 ]]; then
    printf '    %s: avg sentence length %s words (max 30)\n' "$doc" "$avg"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "user docs must have avg sentence length <= 30 words"

# ═══════════════════════════════════════════════════════════════
# 2. COMPLEX WORD RATIO — must be under 20%
# ═══════════════════════════════════════════════════════════════

test_start "flesch_complex_words"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prose=$(_extract_prose "$filepath")
  pct=$(_complex_word_pct "$prose")
  if [[ "$pct" -gt 20 ]]; then
    printf '    %s: %s%% complex words (max 20%%)\n' "$doc" "$pct"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "user docs must have < 20% complex words"

# ═══════════════════════════════════════════════════════════════
# 3. PASSIVE VOICE — minimal use
# ═══════════════════════════════════════════════════════════════

test_start "flesch_passive_voice"
# Check for common passive patterns
passive_patterns='(is|are|was|were|been|being)\s+(used|required|needed|provided|recommended|configured|enabled|disabled|managed|handled|installed|defined|applied|generated|maintained|created|stored|tracked|enforced|supported|documented|processed|executed|verified|validated|included|excluded|specified|detected|resolved|implemented|designed|intended|expected|allowed|blocked|encrypted|decrypted|authenticated|authorized|deployed|provisioned|orchestrated|deprecated|removed|replaced|updated|upgraded|migrated)'
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prose=$(_extract_prose "$filepath")
  total_sentences=$(_sentence_count "$prose")
  if [[ "$total_sentences" -eq 0 ]]; then
    continue
  fi
  passive_count=$(echo "$prose" | grep -ciE "$passive_patterns" || true)
  passive_pct=$((passive_count * 100 / total_sentences))
  if [[ "$passive_pct" -gt 40 ]]; then
    printf '    %s: %s%% passive sentences (max 40%%)\n' "$doc" "$passive_pct"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "user docs must have < 40% passive voice"

# ═══════════════════════════════════════════════════════════════
# 4. JARGON CHECK — no corporate buzzwords
# ═══════════════════════════════════════════════════════════════

test_start "flesch_no_jargon"
jargon_words='(facilitate|utilize|leverage|synergy|paradigm|holistic|ecosystem|scalable|robust|streamline|optimize|orchestrate|proliferate|seamless)'
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prose=$(_extract_prose "$filepath")
  if echo "$prose" | grep -qiE "$jargon_words"; then
    matches=$(echo "$prose" | grep -oiE "$jargon_words" | sort -u | tr '\n' ', ')
    printf '    %s: jargon found: %s\n' "$doc" "$matches"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "user docs must not use corporate jargon"

# ═══════════════════════════════════════════════════════════════
# 5. HEADING CLARITY — no overly long headings
# ═══════════════════════════════════════════════════════════════

test_start "flesch_heading_length"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  while IFS= read -r heading; do
    word_count=$(echo "$heading" | wc -w | tr -d ' ')
    if [[ "$word_count" -gt 10 ]]; then
      printf '    %s: heading too long (%s words): %s\n' "$doc" "$word_count" "$heading"
      failures=$((failures + 1))
    fi
  done < <(awk '/^```/{skip=!skip; next} !skip && /^#{1,3} /{sub(/^#+ /,""); print}' "$filepath")
done
assert_equals "0" "$failures" "headings must be <= 10 words"

# ═══════════════════════════════════════════════════════════════
# 6. ACTIONABLE INSTRUCTIONS — code blocks after imperatives
# ═══════════════════════════════════════════════════════════════

test_start "flesch_has_code_examples"
# User-facing docs should have code examples
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  code_blocks=$(grep -c '^```' "$filepath" || true)
  if [[ "$code_blocks" -lt 2 ]]; then
    printf '    %s: only %s code blocks (min 2)\n' "$doc" "$code_blocks"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "user docs must have at least 2 code blocks"

# ═══════════════════════════════════════════════════════════════
# 7. DOCUMENT LENGTH — not too short, not too long
# ═══════════════════════════════════════════════════════════════

test_start "flesch_doc_length"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  lines=$(wc -l < "$filepath" | tr -d ' ')
  if [[ "$lines" -lt 20 ]]; then
    printf '    %s: too short (%s lines, min 20)\n' "$doc" "$lines"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "user docs must be at least 20 lines"

# ═══════════════════════════════════════════════════════════════
# 8. PER-DOC SENTENCE LENGTH — each doc checked individually
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_sentence_length_${doc_slug}"
  prose=$(_extract_prose "$filepath")
  avg=$(_avg_sentence_length "$prose")
  if [[ "$avg" -le 30 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: avg sentence length $avg words"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: avg sentence length $avg words (max 30)"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 9. PER-DOC COMPLEX WORD CHECK — each doc checked individually
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_complex_words_${doc_slug}"
  prose=$(_extract_prose "$filepath")
  pct=$(_complex_word_pct "$prose")
  if [[ "$pct" -le 20 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $pct% complex words"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $pct% complex words (max 20%)"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 10. PER-DOC PASSIVE VOICE — each doc checked individually
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_passive_voice_${doc_slug}"
  prose=$(_extract_prose "$filepath")
  total_sentences=$(_sentence_count "$prose")
  if [[ "$total_sentences" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (no prose sentences)"
    continue
  fi
  passive_count=$(echo "$prose" | grep -ciE "$passive_patterns" || true)
  passive_pct=$((passive_count * 100 / total_sentences))
  if [[ "$passive_pct" -le 40 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $passive_pct% passive voice"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $passive_pct% passive voice (max 40%)"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 11. PARAGRAPH LENGTH — no paragraphs longer than 5 sentences
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_paragraph_length_${doc_slug}"
  max_period_run=$(sed "/^\`\`\`/,/^\`\`\`/d" "$filepath" | awk '/^$/{if(s>15){n++};s=0;next}{s+=gsub(/\./,"&")} END{print n+0}')
  if [[ "$max_period_run" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no dense paragraphs"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dense paragraphs detected"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 12. CODE BLOCKS HAVE CONTEXT — text before code blocks
# ═══════════════════════════════════════════════════════════════

test_start "flesch_code_blocks_have_context"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prev_line=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\` && -z "$prev_line" ]]; then
      # Code block preceded by blank line — check if it is inside another block
      # Allow if this is the closing fence
      if [[ ! "$line" =~ ^\`\`\`[a-z] && "$line" != '```' ]]; then
        prev_line="$line"
        continue
      fi
    fi
    prev_line="$line"
  done < "$filepath"
done
assert_equals "0" "$failures" "code blocks should have context text before them"

# ═══════════════════════════════════════════════════════════════
# 13. NO DOC STARTS WITH CODE BLOCK — must have intro text
# ═══════════════════════════════════════════════════════════════

test_start "flesch_no_doc_starts_with_code"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  first_content=$(awk 'NF{print; exit}' "$filepath")
  if [[ "$first_content" =~ ^\`\`\` ]]; then
    printf '    %s: starts with a code block instead of intro text\n' "$doc"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no doc should start with a code block"

# ═══════════════════════════════════════════════════════════════
# 14. NO ALL CAPS EMPHASIS — except acronyms (2-5 uppercase letters)
# ═══════════════════════════════════════════════════════════════

test_start "flesch_no_all_caps_emphasis"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prose=$(_extract_prose "$filepath")
  # Find words 6+ chars that are ALL CAPS (likely emphasis, not acronyms)
  caps_words=$(echo "$prose" | grep -oE '\b[A-Z]{6,}\b' | grep -vE '^(README|INSTALL|MIGRATION|PROFILES|FEATURES|ENCRYPTION|IMPORTANT|WARNING|CLAUDE|DOTFILES|RESULTS|CHANGED|SCRIPTS|STANDALONE|PASSED|FAILED|ARCHITECT|ENGINE|LICENSE|SECURITY|CHANGELOG|CONTRIBUTING|TROUBLESHOOTING|OPERATIONS|ALIASES|ARCHITECTURE|COMPLIANCE|RELIABILITY|TESTING|VERSION|INCIDENT|RESPONSE)$' || true)
  if [[ -n "$caps_words" ]]; then
    printf '    %s: ALL CAPS words found: %s\n' "$doc" "$(echo "$caps_words" | tr '\n' ', ')"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "docs should not use ALL CAPS for emphasis (except acronyms)"

# ═══════════════════════════════════════════════════════════════
# 15. BULLET LISTS — no more than 10 items without subheadings
# ═══════════════════════════════════════════════════════════════

test_start "flesch_bullet_list_length"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  in_code=0
  bullet_count=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\` ]]; then
      in_code=$((1 - in_code))
      continue
    fi
    [[ $in_code -eq 1 ]] && continue
    if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]] ]]; then
      bullet_count=$((bullet_count + 1))
    elif [[ "$line" =~ ^#{1,3}[[:space:]] || -z "$line" ]]; then
      if [[ "$bullet_count" -gt 10 ]]; then
        printf '    %s: bullet list with %d items (max 10 without subheading)\n' "$doc" "$bullet_count"
        failures=$((failures + 1))
      fi
      bullet_count=0
    fi
  done < "$filepath"
  # Check trailing list
  if [[ "$bullet_count" -gt 10 ]]; then
    printf '    %s: bullet list with %d items at end of file\n' "$doc" "$bullet_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "bullet lists should not exceed 10 items without subheadings"

# ═══════════════════════════════════════════════════════════════
# 16. CLEAR TITLE — first non-empty line must be a # heading
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_clear_title_${doc_slug}"
  first_content=$(awk 'NF{print; exit}' "$filepath")
  if [[ "$first_content" =~ ^#[[:space:]] || "$first_content" =~ ^\<[phH] ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has clear title"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing clear title"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 17. NO WEAK OPENINGS — avoid "It is", "There is", "There are"
# ═══════════════════════════════════════════════════════════════

test_start "flesch_no_weak_openings"
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  prose=$(_extract_prose "$filepath")
  weak_count=$(echo "$prose" | grep -cE '(^|\. )(It is|There is|There are) ' || true)
  if [[ "$weak_count" -gt 3 ]]; then
    printf '    %s: %d weak sentence openings (max 3)\n' "$doc" "$weak_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "docs should minimize weak openings (It is, There is, There are)"

# ═══════════════════════════════════════════════════════════════
# 18. CONSISTENT HEADING HIERARCHY — ## for sections, ### for subs
# ═══════════════════════════════════════════════════════════════

test_start "flesch_heading_hierarchy"
# Verify no doc skips heading levels (e.g., # to ### without ##)
failures=0
for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  jumps=$(awk '/^```/{c=!c;next} !c && /^#{1,6} /{match($0,/^#+/); print RLENGTH}' "$filepath" | awk 'NR>1 && $1>prev+1{n++} {prev=$1} END{print n+0}')
  if [[ "$jumps" -gt 0 ]]; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "headings must follow consistent hierarchy"

# ═══════════════════════════════════════════════════════════════
# 19. PER-DOC LENGTH CHECK — each doc individually
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_doc_length_${doc_slug}"
  lines=$(wc -l < "$filepath" | tr -d ' ')
  if [[ "$lines" -ge 20 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $lines lines"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $lines lines (min 20)"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 20. PER-DOC CODE EXAMPLES — each doc individually
# ═══════════════════════════════════════════════════════════════

for doc in "${USER_DOCS[@]}"; do
  filepath="$REPO_ROOT/$doc"
  [[ -f "$filepath" ]] || continue
  doc_slug="${doc//[\/.]/_}"
  test_start "flesch_code_examples_${doc_slug}"
  code_blocks=$(grep -c "^\`\`\`" "$filepath" 2>/dev/null || true)
  half=$((code_blocks / 2))
  if [[ "$half" -ge 1 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $half code blocks"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no code blocks"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 21. INDIVIDUAL DOC EXISTENCE — each doc must exist
# ═══════════════════════════════════════════════════════════════

test_start "flesch_readme_exists"
assert_file_exists "$REPO_ROOT/README.md" "README.md must exist"

test_start "flesch_ai_doc_exists"
assert_file_exists "$REPO_ROOT/docs/AI.md" "AI.md must exist"

test_start "flesch_migration_doc_exists"
assert_file_exists "$REPO_ROOT/docs/operations/MIGRATION.md" "MIGRATION.md must exist"

test_start "flesch_profiles_doc_exists"
assert_file_exists "$REPO_ROOT/docs/reference/PROFILES.md" "PROFILES.md must exist"

test_start "flesch_features_doc_exists"
assert_file_exists "$REPO_ROOT/docs/reference/FEATURES.md" "FEATURES.md must exist"

test_start "flesch_encryption_doc_exists"
assert_file_exists "$REPO_ROOT/docs/security/ENCRYPTION.md" "ENCRYPTION.md must exist"

test_start "flesch_install_doc_exists"
assert_file_exists "$REPO_ROOT/docs/guides/INSTALL.md" "INSTALL.md must exist"

# ═══════════════════════════════════════════════════════════════
# 22. INDIVIDUAL DOC WORD COUNT — each doc has substance
# ═══════════════════════════════════════════════════════════════

test_start "flesch_readme_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/README.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

test_start "flesch_ai_doc_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/docs/AI.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

test_start "flesch_migration_doc_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/docs/operations/MIGRATION.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

test_start "flesch_profiles_doc_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/docs/reference/PROFILES.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

test_start "flesch_features_doc_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/docs/reference/FEATURES.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

test_start "flesch_encryption_doc_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/docs/security/ENCRYPTION.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

test_start "flesch_install_doc_has_words"
wc=$(_word_count "$(_extract_prose "$REPO_ROOT/docs/guides/INSTALL.md")")
if [[ "$wc" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $wc words"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $wc words (min 50)"
fi

# ═══════════════════════════════════════════════════════════════
# 23. INDIVIDUAL DOC NO JARGON — each doc checked
# ═══════════════════════════════════════════════════════════════

test_start "flesch_readme_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/README.md'"

test_start "flesch_ai_doc_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/docs/AI.md'"

test_start "flesch_migration_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/docs/operations/MIGRATION.md'"

test_start "flesch_profiles_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/docs/reference/PROFILES.md'"

test_start "flesch_features_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/docs/reference/FEATURES.md'"

test_start "flesch_encryption_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/docs/security/ENCRYPTION.md'"

test_start "flesch_install_no_jargon"
assert_output_not_contains "facilitate" "cat '$REPO_ROOT/docs/guides/INSTALL.md'"

# ═══════════════════════════════════════════════════════════════
# 24. INDIVIDUAL DOC ACTIVE VOICE — no "utilize"
# ═══════════════════════════════════════════════════════════════

test_start "flesch_readme_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/README.md'"

test_start "flesch_ai_doc_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/docs/AI.md'"

test_start "flesch_migration_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/docs/operations/MIGRATION.md'"

test_start "flesch_install_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/docs/guides/INSTALL.md'"

test_start "flesch_profiles_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/docs/reference/PROFILES.md'"

test_start "flesch_features_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/docs/reference/FEATURES.md'"

test_start "flesch_encryption_no_utilize"
assert_output_not_contains "utilize" "cat '$REPO_ROOT/docs/security/ENCRYPTION.md'"

# ═══════════════════════════════════════════════════════════════
# 25. NO "LEVERAGE" OR "SYNERGY" IN DOCS
# ═══════════════════════════════════════════════════════════════

test_start "flesch_readme_no_leverage"
assert_output_not_contains "leverage" "cat '$REPO_ROOT/README.md'"

test_start "flesch_install_no_leverage"
assert_output_not_contains "leverage" "cat '$REPO_ROOT/docs/guides/INSTALL.md'"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
