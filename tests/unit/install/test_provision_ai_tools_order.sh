#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# install/provision/run_onchange_15-ai-cli-tools.sh: the AI tools that run
# on node or python (codex, copilot, aider) need mise's runtimes installed
# first. Run before `mise install`, `dot ai install` failed each of them
# ("requires configured install dependency 'node@26', but its selected
# version is not installed", drill A1). `dot ai install --yes` also installs
# mise when it is missing, so then it runs again once the runtimes exist.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi renders the template"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ai-tools-order.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src/bin" "$WORK/path" "$WORK/home"
chezmoi --source "$REPO_ROOT/defaults" execute-template \
  <"$REPO_ROOT/install/provision/run_onchange_15-ai-cli-tools.sh.tmpl" >"$WORK/run.sh"

# A stub `dot`: logs `dot ai install`, and installs a stub mise (logging
# `mise install`) when there is none, as `dot ai install --yes` does.
cat >"$WORK/src/bin/dot" <<EOF
#!/usr/bin/env bash
echo "dot \$*" >>"$WORK/calls"
if [ ! -x "$WORK/path/mise" ]; then
  printf '#!/bin/sh\necho "mise \$*" >>"%s/calls"\n' "$WORK" >"$WORK/path/mise"
  chmod +x "$WORK/path/mise"
fi
EOF

# run <with_mise>: the rendered script with only the stubs and the system.
run() {
  rm -f "$WORK/calls" "$WORK/path/mise"
  if [[ "$1" == yes ]]; then
    printf '#!/bin/sh\necho "mise $*" >>"%s/calls"\n' "$WORK" >"$WORK/path/mise"
    chmod +x "$WORK/path/mise"
  fi
  env -i HOME="$WORK/home" PATH="$WORK/path:/usr/bin:/bin" DOTFILES_SOURCE_DIR="$WORK/src" \
    bash "$WORK/run.sh" >/dev/null 2>&1
  paste -sd '|' "$WORK/calls"
}

test_start "with_mise_the_runtimes_come_first"
assert_equals "mise install|dot ai install --yes" "$(run yes)" \
  "mise install (node, python, the conf.d tools) runs before dot ai install"

test_start "without_mise_dot_ai_installs_it_then_runtimes_then_again"
assert_equals "dot ai install --yes|mise install|dot ai install --yes" "$(run no)" \
  "dot ai install brings mise, then mise install, then dot ai install for what needed a runtime"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
