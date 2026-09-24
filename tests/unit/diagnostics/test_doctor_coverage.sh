#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# scripts/diagnostics/doctor.sh: the lazy-load exemption for fnm/nvm/sdkman
# in the "uncached slow-init tools" probe. An fnm whose init is referenced
# from the zsh config but that has no lazy-load stub and no cache file must
# be reported as uncached; the same tool behind a lazy-load stub must not.
#
# PATH is a private bin of shims plus a "sysbin" of symlinked coreutils, so
# nothing from the host leaks in; HOME and /proc//sys roots are mktemp.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOCTOR="$REPO_ROOT/scripts/diagnostics/doctor.sh"
WORK="$(mktemp -d -t doctor-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

SYSBIN="$WORK/sysbin"
mkdir -p "$SYSBIN"
for tool in awk sed grep tr find date stat wc head tail basename dirname \
  readlink cut sort uniq cat mkdir mktemp printf hostname whoami rm touch ls env \
  python3 timeout locale tput; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
ln -sf "${BASH:-$(command -v bash)}" "$SYSBIN/bash"

H="$WORK/home"
BIN="$WORK/bin"
mkdir -p "$H/.config/zsh" "$H/.local/share" "$H/.cache" "$H/.local/state" "$BIN"
printf '#!/bin/sh\necho "fnm 1.0.0"\n' >"$BIN/fnm"
cat >"$BIN/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -sr) echo "Linux 6.1.0" ;;
  -m | -p) echo "x86_64" ;;
  *) echo "Linux" ;;
esac
EOF
chmod +x "$BIN/fnm" "$BIN/uname"
printf 'eval "$(fnm env --use-on-cd)"\n' >"$H/.config/zsh/node.zsh"

OUT=""
doctor_run() {
  OUT="$(cd "$H" && env PATH="$BIN:$SYSBIN" HOME="$H" \
    XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
    XDG_CACHE_HOME="$H/.cache" XDG_STATE_HOME="$H/.local/state" \
    SHELL="$BIN/zsh" DOTFILES_ACCESSIBILITY=1 NO_COLOR=1 \
    DOT_DOCTOR_OS_RELEASE="$H/os-release" DOT_DOCTOR_PROC_ROOT="$H/proc" \
    DOT_DOCTOR_SYS_ROOT="$H/sys" \
    "${BASH:-bash}" "$DOCTOR" 2>&1 </dev/null)" || true
}

test_start "doctor_flags_fnm_init_without_lazy_stub"
doctor_run
line="$(printf '%s\n' "$OUT" | grep 'uncached slow-init tools' || true)"
assert_contains "fnm" "$line" "eager fnm init flagged as uncached"

test_start "doctor_exempts_lazy_loaded_fnm"
printf '_lazy_load_fnm() { :; }\n' >>"$H/.config/zsh/node.zsh"
doctor_run
line="$(printf '%s\n' "$OUT" | grep 'uncached slow-init tools' || true)"
assert_contains "none detected" "$line" "lazy-loaded fnm is exempt"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
