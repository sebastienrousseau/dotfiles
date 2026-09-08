#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform tests for scripts/fonts/install-nerd-fonts.sh.
#
# The script downloads release archives from GitHub and installs fonts
# with unzip + fc-cache on Linux or Homebrew casks on macOS. Every case
# runs with PATH pointing at shims: `curl` serves a local fixture
# archive and a matching SHA-256 manifest so the repo's
# download_verified_asset helper passes its real checksum check without
# any network access, and `brew` / `unzip` / `fc-cache` record their
# argv instead of installing anything.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

FONTS_FILE="$REPO_ROOT/scripts/fonts/install-nerd-fonts.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
CALLS="$TMP/font-calls.log"
FHOME="$TMP/font-home"
mkdir -p "$FHOME"

# The archive `curl` will serve, and its real digest.
PAYLOAD="$TMP/font-payload.zip"
printf 'PK\003\004 fixture nerd font archive\n' >"$PAYLOAD"
if command -v sha256sum >/dev/null 2>&1; then
  PAYLOAD_SHA="$(sha256sum "$PAYLOAD" | awk '{print $1}')"
else
  PAYLOAD_SHA="$(shasum -a 256 "$PAYLOAD" | awk '{print $1}')"
fi

F_BIN=""
_f_scenario() {
  F_BIN="$TMP/font-$1"
  shift
  mkdir -p "$F_BIN"
  local tool p
  for tool in cat env printf sed grep tr awk wc dirname basename mktemp rm cp \
    uname locale tput sha256sum shasum mkdir head tail sort cut ls stty "$@"; do
    p="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$F_BIN/$tool"
  done
  ln -sf "$BASH" "$F_BIN/bash"
}

_f_record() {
  rm -f "$F_BIN/$1"
  cat >"$F_BIN/$1" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$1" "\$*" >>"$CALLS"
exit 0
EOF
  chmod +x "$F_BIN/$1"
}

_f_shim() {
  rm -f "$F_BIN/$1"
  cat >"$F_BIN/$1"
  chmod +x "$F_BIN/$1"
}

# curl shim: serves the SHA-256 manifest for the checksum URL and the
# fixture archive for anything else. No network is touched.
_f_curl() {
  _f_shim curl <<EOF
#!/usr/bin/env bash
dest=""
url=""
prev=""
for a in "\$@"; do
  case "\$prev" in -o) dest="\$a" ;; esac
  case "\$a" in https://*) url="\$a" ;; esac
  prev="\$a"
done
[[ -n "\$dest" ]] || exit 1
case "\$url" in
  *SHA-256.txt)
    for font in JetBrainsMono FiraCode Iosevka Fixture; do
      printf '%s  %s.zip\n' "$PAYLOAD_SHA" "\$font"
    done >"\$dest"
    ;;
  *)
    cat "$PAYLOAD" >"\$dest"
    ;;
esac
exit 0
EOF
}

F_OUT=""
F_RC=0
_run_fonts() {
  F_RC=0
  : >"$CALLS"
  F_OUT="$(
    env BASH_XTRACEFD=21 PATH="$F_BIN" HOME="$FHOME" DOTFILES_ACCESSIBILITY=1 \
      "$BASH" "$FONTS_FILE" "$@" </dev/null 2>&1
  )" || F_RC=$?
}

_f_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$F_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $F_RC"
  for needle in "$@"; do
    if [[ "$needle" == "CALL:"* ]]; then
      grep -qF -- "${needle#CALL:}" "$CALLS" 2>/dev/null ||
        problems="${problems}\n      missing call: ${needle#CALL:}"
    else
      [[ "$F_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
    fi
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$F_OUT" | tail -20 | sed 's/^/      /'
    sed 's/^/      call: /' "$CALLS" 2>/dev/null || true
  fi
}

_f_uname() {
  _f_shim uname <<EOF
#!/usr/bin/env bash
echo "$1"
EOF
}

# =======================================================================
# 1. Linux: download, verify, unzip, refresh the font cache.
# =======================================================================
_f_scenario linux
_f_uname Linux
_f_curl
_f_record unzip
_f_record fc-cache
_run_fonts Fixture
_f_expect "linux_installs_a_named_font" 0 \
  "Nerd Fonts" "Downloading" "Fixture Nerd Font" "Installed" \
  "$FHOME/.local/share/fonts/FixtureNerdFont" \
  "CALL:unzip -o" "CALL:fc-cache -f"

test_start "linux_creates_the_target_directory"
assert_dir_exists "$FHOME/.local/share/fonts/FixtureNerdFont" \
  "the per-font target directory must be created"

# Without arguments the script installs its three default families.
_run_fonts
_f_expect "linux_installs_the_default_font_list" 0 \
  "JetBrainsMono Nerd Font" "FiraCode Nerd Font" "Iosevka Nerd Font"

# fc-cache is optional.
_f_scenario linux_nofccache
_f_uname Linux
_f_curl
_f_record unzip
_run_fonts Fixture
_f_expect "linux_without_fc_cache_still_installs" 0 "Installed"

# A failing unzip is reported.
_f_scenario linux_badzip
_f_uname Linux
_f_curl
_f_shim unzip <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_run_fonts Fixture
_f_expect "linux_reports_a_failed_unzip" 1 "Unzip failed" "Fixture.zip"

# A checksum mismatch must abort before anything is installed.
_f_scenario linux_badsum
_f_uname Linux
_f_record unzip
_f_shim curl <<'EOF'
#!/usr/bin/env bash
dest=""
url=""
prev=""
for a in "$@"; do
  case "$prev" in -o) dest="$a" ;; esac
  case "$a" in https://*) url="$a" ;; esac
  prev="$a"
done
[[ -n "$dest" ]] || exit 1
case "$url" in
  *SHA-256.txt) printf '%064d  Fixture.zip\n' 0 >"$dest" ;;
  *) printf 'not the pinned bytes\n' >"$dest" ;;
esac
exit 0
EOF
_run_fonts Fixture
test_start "linux_rejects_a_checksum_mismatch"
if [[ "$F_RC" != "0" ]] && ! grep -q 'unzip' "$CALLS" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: a bad digest must abort before unzip"
  printf '%s\n' "$F_OUT" | tail -10 | sed 's/^/      /'
fi

# =======================================================================
# 2. macOS: Homebrew casks, including the name-mapping table.
# =======================================================================
_f_scenario macos
_f_uname Darwin
_f_record brew
_run_fonts
_f_expect "macos_maps_default_fonts_to_casks" 0 \
  "CALL:brew tap homebrew/cask-fonts" \
  "CALL:brew install --cask font-jetbrains-mono-nerd-font" \
  "CALL:brew install --cask font-fira-code-nerd-font" \
  "CALL:brew install --cask font-iosevka-nerd-font"

_run_fonts Hasklig
_f_expect "macos_lowercases_unmapped_font_names" 0 \
  "CALL:brew install --cask font-hasklig-nerd-font"

_f_scenario macos_nobrew
_f_uname Darwin
_run_fonts
_f_expect "macos_without_homebrew_exits_1" 1 \
  "Homebrew" "not found. Install font manually."

# =======================================================================
# 3. Anything else is unsupported.
# =======================================================================
_f_scenario bsd
_f_uname FreeBSD
_run_fonts
_f_expect "unsupported_platform_exits_1" 1 "Unsupported OS" "font install"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
