#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Unit tests for Wave 1: zshrc lazy alias loading hook and FNM fix
#
# Renders dot_zshrc.tmpl and rc.d/30-options.zsh.tmpl with chezmoi in a
# sandbox and sources them in `zsh -f` with a sandboxed HOME whose shell
# layers are stubs that record when they load. Node/SDK managers are
# stubs that record how they are called.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ZSHRC_TMPL="$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl"
OPTIONS_TMPL="$REPO_ROOT/defaults/dot_config/zsh/rc.d/30-options.zsh.tmpl"

echo "Testing Wave 1: zshrc lazy hook and FNM fix..."

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ZSH_BIN="$(command -v zsh)"
CHEZMOI_BIN="$(command -v chezmoi)"
: >"$SANDBOX/chezmoi.toml"
mkdir -p "$SANDBOX/render-home"

# render <template> <output> [data-json]: data-json goes in the config's
# data section, which overrides .chezmoidata.toml (--override-data needs a
# newer chezmoi than the 2.47.1 CI pins).
render() {
  local config="$SANDBOX/chezmoi.toml"
  if [[ -n "${3:-}" ]]; then
    config="$SANDBOX/chezmoi-override.json"
    printf '{"data":%s}\n' "$3" >"$config"
  fi
  env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
    "$CHEZMOI_BIN" --config "$config" --source "$REPO_ROOT/defaults" \
    --persistent-state "$SANDBOX/state.boltdb" execute-template <"$1" >"$2"
}

# ═══════════════════════════════════════════════════════════════
# dot_zshrc: eager core layers, deferred heavy layers
# ═══════════════════════════════════════════════════════════════

H="$SANDBOX/home"
mkdir -p "$H/.config/shell" "$H/stubs"

test_start "zshrc_renders"
rc=0
render "$ZSHRC_TMPL" "$H/.zshrc" || rc=$?
assert_equals "0" "$rc" "dot_zshrc.tmpl renders with chezmoi"

# Each layer records that it loaded; the lazy alias layer also defines
# an alias only it provides.
for layer in 00-core-paths 05-core-safety 10-secrets 40-ls-colors 50-logic-functions-core \
  51-logic-functions-extra 90-ux-aliases 91-ux-aliases-lazy; do
  printf 'LAYERS_LOADED+=(%s)\n' "$layer" >"$H/.config/shell/$layer.sh"
done
printf "alias lazyprobe='print lazy-alias-ran'\n" >>"$H/.config/shell/91-ux-aliases-lazy.sh"

# Tools the zshrc might initialise eagerly record every call.
for tool in fnm mise starship zoxide atuin; do
  printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$tool" "$SANDBOX/tools.log" >"$H/stubs/$tool"
  chmod +x "$H/stubs/$tool"
done
: >"$SANDBOX/tools.log"

# zshrc <zsh-flags> <script>: source the rendered zshrc, then run <script>.
zshrc() {
  env -i HOME="$H" PATH="$H/stubs:/usr/bin:/bin" TERM=dumb \
    "$ZSH_BIN" -f "$1" -c 'source "$HOME/.zshrc"; '"$2" 2>/dev/null
}

test_start "zshrc_interactive_guard"
assert_equals "unset:0" "$(zshrc +i 'print -r -- "${DOTFILES_SOURCED:-unset}:${#LAYERS_LOADED}"')" \
  "a non-interactive shell returns before loading anything"

test_start "zshrc_core_loop_layers"
assert_equals "00-core-paths 05-core-safety 90-ux-aliases" "$(zshrc -i 'print -r -- "${LAYERS_LOADED[*]}"')" \
  "startup loads exactly the eager layers (paths, safety, eager aliases)"

test_start "zshrc_source_guard"
assert_equals "00-core-paths 05-core-safety 90-ux-aliases" \
  "$(zshrc -i 'source "$HOME/.zshrc"; print -r -- "${LAYERS_LOADED[*]}"')" \
  "sourcing the zshrc twice loads the eager layers once"

test_start "zshrc_autoloads_add_zsh_hook"
assert_equals "1" "$(zshrc -i 'print -r -- ${+functions[add-zsh-hook]}')" \
  "add-zsh-hook is autoloaded"

test_start "zshrc_uses_precmd_hook"
assert_equals "registered" \
  "$(zshrc -i '(( ${precmd_functions[(I)_load_deferred_layers]} )) && print registered || print missing')" \
  "_load_deferred_layers is registered as a precmd hook"

test_start "zshrc_removes_hook_after_load"
assert_equals "removed" \
  "$(zshrc -i 'for f in "${precmd_functions[@]}"; do "$f"; done
    (( ${precmd_functions[(I)_load_deferred_layers]} )) && print still-there || print removed')" \
  "the first prompt runs the hook, which deregisters itself"

test_start "zshrc_loads_lazy_aliases_on_demand"
assert_equals "not-at-startup|lazy-alias-ran" \
  "$(zshrc -i 'alias lazyprobe >/dev/null && print -n at-startup || print -n not-at-startup
    print -n "|"; lazyprobe')" \
  "a lazy alias is not loaded at startup but runs on first use"

test_start "zshrc_dot_load_loads_deferred_layers"
assert_equals "ready|10-secrets 40-ls-colors 50-logic-functions-core 91-ux-aliases-lazy 51-logic-functions-extra" \
  "$(zshrc -i 'LAYERS_LOADED=(); dot load; print -r -- "$DOTFILES_LAYERS_LOAD_STATE|${LAYERS_LOADED[*]}"')" \
  "'dot load' loads the deferred function and alias layers"

test_start "zshrc_no_eager_fnm_eval"
: >"$SANDBOX/tools.log"
zshrc -i 'for f in "${precmd_functions[@]}"; do "$f"; done' >/dev/null
fnm_calls="$(grep '^fnm' "$SANDBOX/tools.log" || true)"
assert_empty "$fnm_calls" "startup and the first prompt never run fnm"

# ═══════════════════════════════════════════════════════════════
# rc.d/30-options.zsh: lazy node/SDK managers
# ═══════════════════════════════════════════════════════════════

O="$SANDBOX/opts"
mkdir -p "$O/home/.nvm" "$O/home/.sdkman/bin" "$O/bin" "$O/nodebin"

# fnm: `fnm env` prints shell code that puts a node on PATH.
cat >"$O/bin/fnm" <<EOF
#!/bin/sh
echo "fnm \$*" >>"$O/calls.log"
if [ "\$1" = env ]; then echo 'export PATH="$O/nodebin:\$PATH"'; fi
EOF
for cmd in node npm; do
  printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$O/calls.log" >"$O/nodebin/$cmd"
done
chmod +x "$O/bin/fnm" "$O/nodebin/node" "$O/nodebin/npm"

# nvm and SDKMAN: init scripts that define the real command.
printf 'NVM_INITS=$((NVM_INITS + 1))\nnvm() { print -r -- "nvm-real $*"; }\n' >"$O/home/.nvm/nvm.sh"
printf 'SDK_INITS=$((SDK_INITS + 1))\nsdk() { print -r -- "sdk-real $*"; }\n' >"$O/home/.sdkman/bin/sdkman-init.sh"

# options <rendered-file> <script>
options() {
  env -i HOME="$O/home" PATH="$O/bin:/usr/bin:/bin" TERM=dumb \
    "$ZSH_BIN" -f -i -c 'NVM_INITS=0; SDK_INITS=0
      _dotfiles_add_precmd() { :; }; _dotfiles_add_preexec() { :; }
      source "$1"; '"$2" _ "$1" 2>/dev/null
}

test_start "options_render_fnm"
rc=0
render "$OPTIONS_TMPL" "$O/30-options-fnm.zsh" '{"tools":{"node_manager":"fnm"}}' || rc=$?
assert_equals "0" "$rc" "30-options renders with node_manager = fnm"

test_start "options_fnm_lazy_wrapper"
: >"$O/calls.log"
assert_equals "fnm:function node:function npm:function npx:function pnpm:function pnpx:function|" \
  "$(options "$O/30-options-fnm.zsh" 'print -r -- "$(whence -w fnm node npm npx pnpm pnpx | tr -d " " | tr "\n" " " | sed "s/ \$//")|$(grep " env" "'"$O"'/calls.log")"')" \
  "fnm and the node commands are lazy wrappers; fnm env has not run"

test_start "options_node_lazy_wrapper"
: >"$O/calls.log"
options "$O/30-options-fnm.zsh" 'node --version; npm ls; print -r -- "after:$(whence -w node) ${+functions[_lazy_load_fnm]}"' >"$O/out.txt"
assert_equals "fnm env --use-on-cd --shell zsh --log-level quiet|node --version|npm ls|after:node: command 0" \
  "$(tr '\n' '|' <"$O/calls.log")$(grep '^after:' "$O/out.txt" | tr '\n' ' ' | sed 's/ $//')" \
  "first node call runs fnm env once, then node; wrappers are gone"

test_start "options_fnm_wrapper_runs_fnm"
: >"$O/calls.log"
options "$O/30-options-fnm.zsh" 'fnm list' >/dev/null
assert_equals "fnm env --use-on-cd --shell zsh --log-level quiet|fnm list|" "$(tr '\n' '|' <"$O/calls.log")" \
  "fnm itself loads its env, then runs"

test_start "options_render_nvm"
rc=0
render "$OPTIONS_TMPL" "$O/30-options-nvm.zsh" '{"tools":{"node_manager":"nvm"}}' || rc=$?
assert_equals "0" "$rc" "30-options renders with node_manager = nvm"

test_start "options_nvm_fallback"
assert_equals "0|nvm-real ls|1" \
  "$(options "$O/30-options-nvm.zsh" 'a=$NVM_INITS; out=$(nvm ls); nvm ls >/dev/null; print -r -- "$a|$out|$NVM_INITS"')" \
  "nvm is sourced on first use, not at startup"

test_start "options_render_default"
rc=0
render "$OPTIONS_TMPL" "$O/30-options-default.zsh" || rc=$?
assert_equals "0" "$rc" "30-options renders with the default node manager"

test_start "options_nvm_requires_no_fnm"
assert_equals "fnm:command node:none nvm:none|0" \
  "$(options "$O/30-options-default.zsh" 'print -r -- "$(whence -w fnm node nvm | tr -d " " | tr "\n" " " | sed "s/ \$//")|$NVM_INITS"')" \
  "with the default manager neither the fnm nor the nvm wrappers are installed"

test_start "options_sdkman_lazy"
assert_equals "0|sdk-real version|1" \
  "$(options "$O/30-options-default.zsh" 'a=$SDK_INITS; out=$(sdk version); sdk version >/dev/null; print -r -- "$a|$out|$SDK_INITS"')" \
  "SDKMAN is sourced on first sdk call, not at startup"

echo ""
echo "Wave 1 zshrc lazy hook and FNM fix tests completed."
print_summary
