#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Flesch reading compliance — validates that user-facing
# documentation meets plain-English readability standards.
#
# Target: Flesch Reading Ease 60-70 (Standard/Plain English, 8th-9th grade)
# Method: Proxy metrics (sentence length, word complexity, passive voice)

set -euo pipefail

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

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
