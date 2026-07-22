#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/manual.sh.
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/manual.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/manual.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "manual_deep_branches_execute"
manual_tmp="$DOTFILES_COV_TMPDIR/manual-deep"
mkdir -p "$manual_tmp/repo/_build/manual/html" \
  "$manual_tmp/data/dotfiles/manual/html" \
  "$manual_tmp/cache/dotfiles/manual" \
  "$manual_tmp/bin" \
  "$manual_tmp/work"
printf '<html>local</html>\n' >"$manual_tmp/repo/_build/manual/dotfiles.html"
printf '<html>multi</html>\n' >"$manual_tmp/repo/_build/manual/html/index.html"
printf 'text manual\n' >"$manual_tmp/repo/_build/manual/dotfiles.txt"
printf 'pdf\n' >"$manual_tmp/repo/_build/manual/dotfiles.pdf"
printf 'epub\n' >"$manual_tmp/repo/_build/manual/dotfiles.epub"
printf 'markdown archive\n' >"$manual_tmp/repo/_build/manual/dotfiles-md.tar.gz"
printf '<html>offline</html>\n' >"$manual_tmp/data/dotfiles/manual/dotfiles.html"
printf 'offline text\n' >"$manual_tmp/data/dotfiles/manual/dotfiles.txt"
cat >"$manual_tmp/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
out=""
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
mkdir -p "$(dirname "$out")"
printf 'downloaded manual\n' >"$out"
EOF_CURL
cat >"$manual_tmp/bin/tar" <<'EOF_TAR'
#!/usr/bin/env bash
while (($#)); do
  case "$1" in
    -C)
      mkdir -p "$2"
      printf '# extracted\n' >"$2/README.md"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
EOF_TAR
cat >"$manual_tmp/bin/uname" <<'EOF_UNAME'
#!/usr/bin/env bash
printf 'OtherOS\n'
EOF_UNAME
cat >"$manual_tmp/bin/pager" <<'EOF_PAGER'
#!/usr/bin/env bash
cat "$1" >/dev/null
EOF_PAGER
chmod +x "$manual_tmp/bin/curl" \
  "$manual_tmp/bin/tar" \
  "$manual_tmp/bin/uname" \
  "$manual_tmp/bin/pager"
(
  set +e
  export HOME="$manual_tmp/home"
  export XDG_CACHE_HOME="$manual_tmp/cache"
  export XDG_DATA_HOME="$manual_tmp/data"
  export PAGER="$manual_tmp/bin/pager"
  export PATH="$manual_tmp/bin:$PATH"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  _DOT_SOURCE_DIR_CACHE="$manual_tmp/repo"
  cd "$manual_tmp/work" || exit 1

  set -- --local text
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  format_file html
  format_file html-multi
  format_file pdf
  format_file epub
  format_file text
  format_file markdown
  format_file bad

  USE_LOCAL=true USE_OFFLINE=false FORMAT=html cmd_open
  USE_LOCAL=true USE_OFFLINE=false FORMAT=html-multi cmd_open
  USE_LOCAL=true USE_OFFLINE=false FORMAT=text cmd_open
  USE_LOCAL=true USE_OFFLINE=false FORMAT=markdown cmd_open
  USE_LOCAL=false USE_OFFLINE=true FORMAT=html cmd_open
  USE_LOCAL=false USE_OFFLINE=true FORMAT=text cmd_download
  USE_LOCAL=false USE_OFFLINE=false FORMAT=pdf cmd_download
  USE_LOCAL=false USE_OFFLINE=false FORMAT=epub cmd_open
  USE_LOCAL=true FORMAT=missing resolve_source missing
) >/dev/null || true
assert_file_exists "$manual_tmp/work/dotfiles.txt" \
  "manual deep branches downloaded sandbox text manual"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
