#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Tests must run the tools mise installed, not mise's shims. A shim looks
# its tool up from HOME, so one a test runs under a sandbox HOME found no
# installs there and, with the user's auto_install and the framework's
# MISE_YES, downloaded the tool into the sandbox: about 2.4 GB of python per
# sandbox, which filled the disk mid pre-push. A non-interactive shell has
# the shims directory ahead of the install directories, so `command -v
# python3` (and dot_fixture_basebin's symlinks) found the shim.
#
# Each case gives a child a PATH with a fake shims directory first and a
# fake mise whose `bin-paths` names a fake install directory, sources the
# framework file, and checks what python3 resolves to.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SHIMS="$TMP/data/mise/shims"
INSTALL="$TMP/data/mise/installs/python/3.14/bin"
TOOLS="$TMP/tools"
mkdir -p "$SHIMS" "$INSTALL" "$TOOLS" "$TMP/home"
printf '#!/bin/sh\necho shim\n' >"$SHIMS/python3"
printf '#!/bin/sh\necho real\n' >"$INSTALL/python3"
cat >"$TOOLS/mise" <<EOF
#!/bin/sh
[ "\$1" = bin-paths ] && echo "$INSTALL"
EOF
chmod +x "$SHIMS/python3" "$INSTALL/python3" "$TOOLS/mise"

# _resolve <framework file> <PATH>: in a child with that PATH, source the
# file, then print where python3 resolves, whether a shims entry is left on
# PATH, and MISE_AUTO_INSTALL.
# shellcheck disable=SC2016 # the child shell expands $1, not this one
_resolve() {
  env -i HOME="$TMP/home" PATH="$2" TMPDIR="$TMP" bash -c '
    source "$1" >/dev/null 2>&1
    case ":$PATH:" in *"/mise/shims:"*) left=shims ;; *) left=none ;; esac
    printf "%s|%s|%s\n" "$(command -v python3)" "$left" "${MISE_AUTO_INSTALL-unset}"
  ' _ "$1"
}

for lib in assertions.sh mise_env.sh; do
  name="${lib%.sh}"

  out="$(_resolve "$REPO_ROOT/tests/framework/$lib" "$SHIMS:$TOOLS:/usr/bin:/bin")"
  test_start "mise_${name}_resolves_the_installed_binary"
  assert_equals "$INSTALL/python3|none|false" "$out" \
    "python3 is the installed binary, no shims entry is left, auto-install is off"

  # Without mise there is nothing to resolve the shims with: PATH is kept.
  out="$(_resolve "$REPO_ROOT/tests/framework/$lib" "$SHIMS:/usr/bin:/bin")"
  test_start "mise_${name}_without_mise_keeps_path"
  assert_equals "$SHIMS/python3|shims|false" "$out" \
    "with no mise on PATH, the shims stay and auto-install is still off"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
