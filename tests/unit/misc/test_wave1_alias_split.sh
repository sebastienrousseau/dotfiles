#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Unit tests for Wave 1: Eager/Lazy alias split (90/91 templates)
#
# Renders 90-ux-aliases.sh.tmpl (eager) and 91-ux-aliases-lazy.sh.tmpl
# (lazy) with chezmoi in a sandbox, sources each result in a clean bash,
# and checks which aliases and functions each layer defines against what
# every alias category defines when sourced on its own:
#   * the 18 core categories load eagerly and never lazily;
#   * every other category loads lazily and never eagerly;
#   * macOS aliases load eagerly on Darwin only, and never lazily.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

EAGER_TMPL="$REPO_ROOT/defaults/dot_config/shell/90-ux-aliases.sh.tmpl"
LAZY_TMPL="$REPO_ROOT/defaults/dot_config/shell/91-ux-aliases-lazy.sh.tmpl"
ALIAS_DIR="$REPO_ROOT/defaults/.chezmoitemplates/aliases"

# The eager set, as specified by the Wave 1 split.
CORE_CATEGORIES=(archives cd clear configuration default diagnostics disk-usage
  editor git interactive installer mkdir modern ps rsync sudo system compliance)

echo "Testing Wave 1: Eager/Lazy alias split..."

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi not installed; cannot render the alias templates"
  echo "RESULTS:0:0:0"
  exit 0
fi

export LC_ALL=C
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home" "$SANDBOX/stub" "$SANDBOX/cats"
: >"$SANDBOX/chezmoi.toml"
CHEZMOI_BIN="$(command -v chezmoi)"

# Tool-gated alias files only define their aliases when the tool exists.
# No-op stubs make those categories observable. nmap and ufw are left
# out on purpose: their files must not cut the lazy layer short when the
# tool is missing.
for tool in docker kubectl terraform gcloud go npm pnpm yarn cargo rustup svn fd gdate \
  vagrant tmux wget lua make hyperfine heroku gpg openssl python3 uv dig; do
  printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/stub/$tool"
  chmod +x "$SANDBOX/stub/$tool"
done

render() {
  env -i HOME="$SANDBOX/home" PATH="$PATH" \
    "$CHEZMOI_BIN" --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
    --persistent-state "$SANDBOX/state.boltdb" execute-template <"$1" >"$2"
}

# Print the aliases (a:NAME) and functions (f:NAME) that sourcing the
# given files adds to a clean, non-interactive bash.
defined_names() {
  env -i HOME="$SANDBOX/home" PATH="$SANDBOX/stub:/usr/bin:/bin" LC_ALL=C \
    DOTFILES_SAFE_ALIASES=1 "$BASH" --norc --noprofile -c '
    snap() { { compgen -a | sed "s/^/a:/"; compgen -A function | sed "s/^/f:/"; } | sort; }
    before=$(snap)
    for f in "$@"; do source "$f" </dev/null >/dev/null 2>&1 || true; done
    comm -13 <(printf "%s\n" "$before") <(snap)' _ "$@"
}

# --- Rendering ---

test_start "eager_template_renders"
rc=0
render "$EAGER_TMPL" "$SANDBOX/90-ux-aliases.sh" || rc=$?
assert_equals "0" "$rc" "90-ux-aliases.sh.tmpl renders with chezmoi"

test_start "lazy_template_renders"
rc=0
render "$LAZY_TMPL" "$SANDBOX/91-ux-aliases-lazy.sh" || rc=$?
assert_equals "0" "$rc" "91-ux-aliases-lazy.sh.tmpl renders with chezmoi"

test_start "eager_output_has_shebang"
assert_equals "#!/usr/bin/env bash" "$(head -n 1 "$SANDBOX/90-ux-aliases.sh")" \
  "rendered eager layer starts with a bash shebang"

test_start "lazy_output_has_shebang"
assert_equals "#!/usr/bin/env bash" "$(head -n 1 "$SANDBOX/91-ux-aliases-lazy.sh")" \
  "rendered lazy layer starts with a bash shebang"

# --- Bash compatibility: aliases must expand in a non-interactive bash ---

expand_aliases_after() {
  env -i HOME="$SANDBOX/home" PATH="$SANDBOX/stub:/usr/bin:/bin" "$BASH" --norc --noprofile -c '
    source "$1" </dev/null >/dev/null 2>&1 || true
    shopt -q expand_aliases && echo on || echo off' _ "$1"
}

test_start "eager_enables_expand_aliases"
assert_equals "on" "$(expand_aliases_after "$SANDBOX/90-ux-aliases.sh")" \
  "sourcing the eager layer turns on expand_aliases in bash"

test_start "lazy_enables_expand_aliases"
assert_equals "on" "$(expand_aliases_after "$SANDBOX/91-ux-aliases-lazy.sh")" \
  "sourcing the lazy layer turns on expand_aliases in bash"

# --- Which layer defines what ---

defined_names "$SANDBOX/90-ux-aliases.sh" >"$SANDBOX/eager.names"
defined_names "$SANDBOX/91-ux-aliases-lazy.sh" >"$SANDBOX/lazy.names"

categories=()
for dir in "$ALIAS_DIR"/*/; do
  cat_name="$(basename "$dir")"
  files=("$dir"*.aliases.sh)
  [[ -e "${files[0]}" ]] || continue
  categories+=("$cat_name")
  defined_names "${files[@]}" >"$SANDBOX/cats/$cat_name"
done

# Names defined by more than one category cannot be attributed to one.
sort "$SANDBOX"/cats/* | uniq -d >"$SANDBOX/shared.names"
unique_names() { comm -23 "$SANDBOX/cats/$1" "$SANDBOX/shared.names"; }
count_in() { comm -12 <(unique_names "$1") "$2" | wc -l | tr -d ' '; }

is_core() {
  local c
  for c in "${CORE_CATEGORIES[@]}"; do [[ "$c" == "$1" ]] && return 0; done
  return 1
}

test_start "core_categories_count"
assert_equals "18" "${#CORE_CATEGORIES[@]}" "the eager split covers 18 core categories"

test_start "every_core_category_exists"
missing=""
for c in "${CORE_CATEGORIES[@]}"; do
  [[ -d "$ALIAS_DIR/$c" ]] || missing+=" $c"
done
assert_empty "$missing" "every core category has an alias directory"

test_start "eager_and_lazy_are_disjoint"
overlap="$(comm -12 "$SANDBOX/eager.names" "$SANDBOX/lazy.names" | comm -23 - "$SANDBOX/shared.names" | tr '\n' ' ')"
assert_empty "$overlap" "no category's aliases load in both layers"

host_os="$(uname -s)"
for c in "${categories[@]}"; do
  total="$(unique_names "$c" | wc -l | tr -d ' ')"
  if [[ "$total" -eq 0 ]]; then
    echo "  - $c: defines no aliases or functions in this sandbox; nothing to place"
    continue
  fi
  in_eager="$(count_in "$c" "$SANDBOX/eager.names")"
  in_lazy="$(count_in "$c" "$SANDBOX/lazy.names")"
  if [[ "$c" == "macOS" ]]; then
    test_start "macos_never_lazy"
    assert_equals "0" "$in_lazy" "macOS aliases are never in the lazy layer"
    test_start "macos_eager_only_on_darwin"
    if [[ "$host_os" == "Darwin" ]]; then
      assert_equals "$total" "$in_eager" "on Darwin all $total macOS names load eagerly"
    else
      assert_equals "0" "$in_eager" "off Darwin no macOS names load eagerly"
    fi
  elif is_core "$c"; then
    test_start "core_${c}_loads_eagerly_only"
    assert_equals "$total/0" "$in_eager/$in_lazy" \
      "core '$c': all $total names eager, none lazy (eager/lazy)"
  else
    test_start "noncore_${c}_loads_lazily_only"
    assert_equals "0/$total" "$in_eager/$in_lazy" \
      "'$c': none of $total names eager, all lazy (eager/lazy)"
  fi
done

echo ""
echo "Wave 1 alias split tests completed."
print_summary
