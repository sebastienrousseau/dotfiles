#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Template validation: every chezmoi template in the repository renders
# with the real chezmoi against this checkout, in a sandbox (empty config,
# throwaway HOME, destination, cache and state), so the result never
# depends on the machine's own chezmoi setup. It used to read
# $HOME/.dotfiles and the user's chezmoi config, so on CI it found nothing
# and crashed, and locally it validated whatever the user had installed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHEZMOI_BIN="$(command -v chezmoi || true)"
if [[ -z "$CHEZMOI_BIN" ]]; then
  test_start "template_validation_requires_chezmoi"
  assert_true "true" "skipped: chezmoi not installed"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

SANDBOX="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/tmpl-validate.XXXXXX")" && pwd)" # pwd drops a doubled slash
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home"
: >"$SANDBOX/chezmoi.toml"

# cz <args...>: chezmoi against this checkout with nothing from the host.
cz() {
  env -i HOME="$SANDBOX/home" PATH="/usr/bin:/bin" "$CHEZMOI_BIN" \
    --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT" \
    --destination "$SANDBOX/home" --cache "$SANDBOX/cache" \
    --persistent-state "$SANDBOX/state.boltdb" "$@"
}

# --- Every template renders ---------------------------------------------------
while IFS= read -r tmpl; do
  test_start "template_renders_${tmpl//[^A-Za-z0-9]/_}"
  init=()
  # The config template uses init-only functions (stdinIsATTY, prompt*).
  [[ "$tmpl" == "defaults/.chezmoi.toml.tmpl" ]] && init=(--init)
  if cz execute-template "${init[@]}" <"$REPO_ROOT/$tmpl" >/dev/null 2>"$SANDBOX/err"; then
    assert_true "true" "$tmpl renders"
  else
    assert_equals "renders" "$(head -c 300 "$SANDBOX/err")" "$tmpl renders"
  fi
done < <(cd "$REPO_ROOT" && git ls-files 'defaults/*.tmpl' 'defaults/**/*.tmpl' | sort -u)

# --- Built-in and repository data --------------------------------------------
data="$(cz data --format json 2>/dev/null)"
field() { printf '%s' "$data" | python3 -c 'import json,sys; d=json.load(sys.stdin); v=d
for k in sys.argv[1].split("."): v=v.get(k,"") if isinstance(v,dict) else ""
print(v)' "$1"; }

test_start "template_data_os"
assert_equals "$(uname -s | tr '[:upper:]' '[:lower:]')" "$(field chezmoi.os)" ".chezmoi.os is the host OS"

test_start "template_data_home_dir"
assert_equals "$SANDBOX/home" "$(field chezmoi.homeDir)" ".chezmoi.homeDir is the sandbox HOME"

test_start "template_data_dotfiles_version"
assert_equals "$(sed -n 's/^dotfiles_version = "\(.*\)"$/\1/p' "$REPO_ROOT/defaults/.chezmoidata.toml")" \
  "$(field dotfiles_version)" ".dotfiles_version comes from .chezmoidata.toml"

# --- Config template without a TTY -------------------------------------------
# Container builds, CI and drift detection run `chezmoi init` with no TTY.
# The config template must not prompt then, must keep values already
# stored (a re-init used to reset a configured git identity to "Your
# Name <you@example.com>"), must take CHEZMOI_<KEY> from the environment,
# and must not invent placeholder identities.
render_cfg() { # render_cfg <config-file> [VAR=value...]
  local cfg="$1"
  shift
  env -i HOME="$SANDBOX/home" PATH="/usr/bin:/bin" "$@" "$CHEZMOI_BIN" \
    --config "$cfg" --source "$REPO_ROOT" --destination "$SANDBOX/home" \
    --cache "$SANDBOX/cache" --persistent-state "$SANDBOX/state.boltdb" \
    execute-template --init <"$REPO_ROOT/defaults/.chezmoi.toml.tmpl" 2>/dev/null
}
cfgval() { sed -n "s/^$1 *= \"\(.*\)\"\$/\1/p"; }

test_start "config_tmpl_no_tty_no_placeholder_identity"
out="$(render_cfg "$SANDBOX/chezmoi.toml")"
assert_equals "|" "$(cfgval git_name <<<"$out")|$(cfgval git_email <<<"$out")" "no TTY, nothing stored: identity left empty"

printf '[data]\ngit_name = "Ann Example"\ngit_email = "ann@example.org"\nprofile = "server"\n' >"$SANDBOX/stored.toml"
test_start "config_tmpl_no_tty_keeps_stored_values"
out="$(render_cfg "$SANDBOX/stored.toml")"
assert_equals "Ann Example|ann@example.org|server" \
  "$(cfgval git_name <<<"$out")|$(cfgval git_email <<<"$out")|$(cfgval profile <<<"$out")" "a re-init keeps the stored identity and profile"

printf '[data]\ngit_name = "Your Name"\ngit_email = "you@example.com"\n' >"$SANDBOX/placeholder.toml"
test_start "config_tmpl_no_tty_drops_stored_placeholders"
out="$(render_cfg "$SANDBOX/placeholder.toml")"
assert_equals "|" "$(cfgval git_name <<<"$out")|$(cfgval git_email <<<"$out")" "stored placeholders are not carried forward"

test_start "config_tmpl_no_tty_env_overrides"
out="$(render_cfg "$SANDBOX/stored.toml" CHEZMOI_GIT_NAME="Env Name" CHEZMOI_PROFILE=container)"
assert_equals "Env Name|ann@example.org|container" \
  "$(cfgval git_name <<<"$out")|$(cfgval git_email <<<"$out")|$(cfgval profile <<<"$out")" "CHEZMOI_<KEY> wins over the stored value"

# --- Helper templates document themselves ------------------------------------
shopt -s nullglob
for helper in "$REPO_ROOT"/defaults/.chezmoitemplates/functions/helpers/*.tmpl; do
  test_start "helper_documented_$(basename "$helper" .tmpl)"
  assert_true "head -5 '$helper' | grep -q '{{-[[:space:]]*/\\*'" "$(basename "$helper") opens with a documentation comment"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
