#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031,SC2016
# Regression: Integration tests — module interop and third-party communication.
# Regression for: d7e7c2bc (v0.2.499 baseline)
# Why: End-to-end integration regressions across chezmoi + mise + dot CLI + shell init.
#
# Every case runs the code in a throwaway sandbox (HOME, XDG_*, TMPDIR and a
# stub-first PATH under one mktemp dir) and asserts what it did. Nothing here
# touches the real HOME, installs anything or reaches the network: curl,
# sudo, package managers and chezmoi are recording stubs wherever the code
# under test could call them.

# No `set -e`: an assertion returns 1 when it fails, and errexit would end
# the suite there instead of tallying the failure and running the rest.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
IT_WORK="$(mktemp -d "${TMPDIR:-/tmp}/integration.XXXXXX")"
trap 'rm -rf "$IT_WORK"' EXIT
IT_CHEZMOI="$(command -v chezmoi 2>/dev/null || true)"
IT_PY="$(command -v python3 2>/dev/null || true)"
# The TOML cases need tomllib (3.11+); older pythons count as absent.
[[ -n "$IT_PY" ]] && ! "$IT_PY" -c 'import tomllib' 2>/dev/null && IT_PY=""
IT_S=""

# it_sandbox <name>: fresh HOME/bin/tmp under $IT_WORK/<name>; sets IT_S.
# The default stubs record any call that could install, download or apply.
it_sandbox() {
  IT_S="$IT_WORK/$1"
  mkdir -p "$IT_S/home/.config" "$IT_S/bin" "$IT_S/tmp" "$IT_S/run"
  local t
  for t in sudo apt-get dnf pacman brew curl wget chezmoi mise; do
    it_stub "$t" "echo \"$t \$*\" >>\"$IT_S/danger.spy\"; exit 1"
  done
}

# it_stub <name> <sh body>: an executable stub in the current sandbox's bin.
it_stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"$IT_S/bin/$1"
  chmod +x "$IT_S/bin/$1"
}

# it_env <cmd...>: run in the current sandbox with a stub-first PATH.
it_env() {
  env -i HOME="$IT_S/home" XDG_CONFIG_HOME="$IT_S/home/.config" \
    XDG_DATA_HOME="$IT_S/home/.local/share" XDG_CACHE_HOME="$IT_S/home/.cache" \
    XDG_STATE_HOME="$IT_S/home/.local/state" XDG_RUNTIME_DIR="$IT_S/run" \
    TMPDIR="$IT_S/tmp" PATH="$IT_S/bin:/usr/bin:/bin" TERM=dumb NO_COLOR=1 \
    DOTFILES_NO_TUI=1 DOTFILES_NONINTERACTIVE=1 CI=1 "$@" </dev/null
}

# it_render <template> <out>: render with fixture data; 1 if chezmoi is absent.
it_render() {
  [[ -n "$IT_CHEZMOI" ]] || return 1
  printf '{"data":{"git_name":"Fixture User","git_email":"fixture@example.invalid","profile":"laptop","theme":"tokyonight-night"}}' \
    >"$IT_WORK/chezmoi.json"
  env -i HOME="$IT_WORK/render-home" PATH="/usr/bin:/bin" "$IT_CHEZMOI" \
    --config "$IT_WORK/chezmoi.json" --source "$REPO_ROOT/defaults" \
    --destination "$IT_WORK/render-home" --cache "$IT_WORK/render-cache" \
    --persistent-state "$IT_WORK/render-state.boltdb" \
    execute-template <"$1" >"$2" 2>"$2.err"
}

# it_skip <reason>: count a case that cannot run on this host as passed.
it_skip() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: $1)"
}

# it_toml <file> <python expr over `d`>: evaluate against the parsed TOML.
it_toml() {
  "$IT_PY" - "$1" "$2" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    d = tomllib.load(f)
print(eval(sys.argv[2], {"d": d}))
PY
}

# ═══════════════════════════════════════════════════════════════
# 1. DOT CLI → COMMAND DISPATCH CHAIN
# ═══════════════════════════════════════════════════════════════

# Every module the dispatcher routes to, and every other command module,
# must load and answer an unknown subcommand with a clean usage error
# (rc 0 or 1). A missing module exits 127; a parse error exits 2.
it_sandbox dispatch
test_start "dispatch_command_scripts_exist"
it_bad=""
it_mods=(core diagnostics ai tools appearance secrets security meta fleet completion)
for it_f in "$REPO_ROOT"/scripts/dot/commands/*.sh; do it_mods+=("$(basename "$it_f" .sh)"); done
for it_m in "${it_mods[@]}"; do
  it_rc=0
  it_out="$(cd "$IT_S/tmp" && it_env bash "$REPO_ROOT/scripts/dot/commands/$it_m.sh" __no_such_subcommand__ 2>&1)" || it_rc=$?
  if ((it_rc > 1)) || [[ "$it_out" == *"syntax error"* ]]; then it_bad+=" $it_m(rc=$it_rc)"; fi
done
assert_empty "$it_bad" "every command module loads and rejects an unknown subcommand"

# A bare `dot ai "<prompt>"` goes through bin/dot → commands/ai.sh and runs
# the prompt on Claude.
test_start "integration_dot_cli_sources_commands"
it_stub claude "echo \"claude \$*\" >>\"$IT_S/claude.spy\"; exit 0"
it_env bash "$DOT_CLI" ai "fixture prompt" >/dev/null 2>&1
assert_equals "claude --print" "$(cat "$IT_S/claude.spy" 2>/dev/null)" \
  "dot routes a command to its scripts/dot/commands module"

test_start "integration_custom_commands_dispatched"
mkdir -p "$IT_S/home/.config/dotfiles/commands"
printf 'echo "user-command ran with: $*"\n' >"$IT_S/home/.config/dotfiles/commands/zzfixture.sh"
it_out="$(it_env bash "$DOT_CLI" zzfixture one two 2>&1)"
assert_contains "user-command ran with: one two" "$it_out" \
  "dot runs a user command from XDG_CONFIG_HOME/dotfiles/commands"

# ═══════════════════════════════════════════════════════════════
# 2. CHEZMOI TEMPLATES → SHELL CONFIG CHAIN (rendered zshrc, real zsh)
# ═══════════════════════════════════════════════════════════════

test_start "integration_aliases_aggregator_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/shell/90-ux-aliases.sh.tmpl" "alias aggregator template must exist"

# One interactive zsh on the rendered zshrc, with a fixture file in each
# extension point: the paths layer, the functions layer, rc.d.local and a
# modules.d module. The functions layer is lazy: calling an undefined
# function must load it through the command_not_found handler.
it_sandbox zsh
IT_ZSH_OUT=""
IT_ZSH_SKIP=""
if ! command -v zsh >/dev/null 2>&1; then
  IT_ZSH_SKIP="zsh not installed"
elif ! it_render "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" "$IT_WORK/zshrc"; then
  IT_ZSH_SKIP="chezmoi not installed"
else
  it_h="$IT_S/home"
  mkdir -p "$it_h/.config/zsh/rc.d.local" "$it_h/.config/shell" "$it_h/.config/dotfiles/modules.d/fixture"
  cp "$IT_WORK/zshrc" "$it_h/.config/zsh/.zshrc"
  echo 'export IT_PATHS_LAYER=loaded' >"$it_h/.config/shell/00-core-paths.sh"
  echo 'it_fixture_fn() { print "functions-layer ran: $*"; }' >"$it_h/.config/shell/50-logic-functions-core.sh"
  echo 'export IT_RC_LOCAL=loaded' >"$it_h/.config/zsh/rc.d.local/10-fixture.zsh"
  echo 'export IT_MODULE=loaded' >"$it_h/.config/dotfiles/modules.d/fixture/init.sh"
  IT_ZSH_OUT="$(it_env env ZDOTDIR="$it_h/.config/zsh" zsh -i -c '
    print "paths=${IT_PATHS_LAYER:-unset} rclocal=${IT_RC_LOCAL:-unset} module=${IT_MODULE:-unset}"
    print "features=[$DOTFILES_FEATURES]"
    it_fixture_fn a b' 2>&1)"
fi

test_start "integration_functions_aggregator_exists"
if [[ -n "$IT_ZSH_SKIP" ]]; then it_skip "$IT_ZSH_SKIP"; else
  assert_contains "functions-layer ran: a b" "$IT_ZSH_OUT" "zsh loads the functions layer on first use"
fi

test_start "integration_paths_in_init"
if [[ -n "$IT_ZSH_SKIP" ]]; then it_skip "$IT_ZSH_SKIP"; else
  assert_contains "paths=loaded" "$IT_ZSH_OUT" "zsh sources the paths layer at startup"
fi

# ═══════════════════════════════════════════════════════════════
# 3. MISE CONFIG → TOOL AVAILABILITY
# ═══════════════════════════════════════════════════════════════

MISE_TOML="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"

test_start "integration_mise_config_syntax"
if [[ -z "$IT_PY" ]]; then it_skip "python3 not installed"; else
  it_rc=0
  it_toml "$MISE_TOML" 'len(d["tools"])' >/dev/null 2>&1 || it_rc=$?
  assert_equals "0" "$it_rc" "mise config parses as TOML with a [tools] table"
fi

# Tool names as mise installs them: `aqua:dandavison/delta` → delta.
IT_MISE_TOOLS=""
if [[ -n "$IT_PY" ]]; then
  IT_MISE_TOOLS=" $(it_toml "$MISE_TOML" '" ".join(k.split(":")[-1].split("/")[-1] for k in d["tools"])' 2>/dev/null) "
fi
for it_tool in delta lazygit fd; do
  test_start "integration_mise_has_modern_cli_tools_$it_tool"
  if [[ -z "$IT_PY" ]]; then it_skip "python3 not installed"; else
    assert_contains " $it_tool " "$IT_MISE_TOOLS" "mise [tools] installs $it_tool"
  fi
done

# The AI provisioning script, rendered and run with mise present. Downloads
# go through the real checksum verifier, against a fixture manifest that
# pins each native-installer URL to a fixture installer; curl is a stub
# that records the URL and serves that fixture.
it_sandbox provision
IT_PROV_SKIP=""
if ! it_render "$REPO_ROOT/install/provision/run_onchange_15-ai-cli-tools.sh.tmpl" "$IT_WORK/provision.sh"; then
  IT_PROV_SKIP="chezmoi not installed"
elif ! it_sha="$(command -v sha256sum || command -v shasum)"; then
  IT_PROV_SKIP="no SHA-256 tool"
else
  printf '#!/bin/sh\necho "installer ran" >>"%s/installer.spy"\n' "$IT_S" >"$IT_S/fixture-installer.sh"
  it_sum="$("$it_sha" "$IT_S/fixture-installer.sh" 2>/dev/null || shasum -a 256 "$IT_S/fixture-installer.sh")"
  it_sum="${it_sum%% *}"
  for it_url in https://claude.ai/install.sh https://code.kimi.com/kimi-code/install.sh \
    https://github.com/block/goose/releases/download/stable/download_cli.sh \
    https://antigravity.google/cli/install.sh; do
    printf '%s  %s\n' "$it_sum" "$it_url" >>"$IT_S/manifest.sha256"
  done
  it_stub curl "for a; do u=\"\$a\"; done; echo \"\$u\" >>\"$IT_S/curl.spy\"
while [ \$# -gt 0 ]; do [ \"\$1\" = -o ] && cp \"$IT_S/fixture-installer.sh\" \"\$2\"; shift; done; exit 0"
  it_stub mise "echo \"mise \$*\" >>\"$IT_S/mise.spy\"; exit 0"
  it_env env DOTFILES_SOURCE_DIR="$REPO_ROOT" DOTFILES_INSTALLER_MANIFEST="$IT_S/manifest.sha256" \
    bash "$IT_WORK/provision.sh" >"$IT_S/provision.out" 2>&1
fi
IT_CURL_SPY="$(cat "$IT_S/curl.spy" 2>/dev/null)"

# Claude Code is installed via Anthropic's native installer, not mise/npm:
# npm 11 drops the platform-native optionalDependency on global installs.
test_start "integration_mise_has_ai_tools_claude"
if [[ -n "$IT_PROV_SKIP" ]]; then it_skip "$IT_PROV_SKIP"; else
  assert_contains "https://claude.ai/install.sh" "$IT_CURL_SPY" "provisioning installs Claude Code via the native installer"
fi
test_start "integration_mise_never_installs_claude"
if [[ -n "$IT_PROV_SKIP" ]]; then it_skip "$IT_PROV_SKIP"; else
  assert_false '[[ "$(cat "$IT_S/mise.spy" 2>/dev/null)" == *claude* ]]' "and never through mise"
fi
test_start "integration_mise_has_ai_tools_antigravity"
if [[ -n "$IT_PROV_SKIP" ]]; then it_skip "$IT_PROV_SKIP"; else
  assert_contains "https://antigravity.google/cli/install.sh" "$IT_CURL_SPY" "provisioning installs Antigravity (agy) via its native installer"
fi

# ═══════════════════════════════════════════════════════════════
# 4. AI BRIDGE → PROVIDER BINARIES
# ═══════════════════════════════════════════════════════════════

# `dot ai <tool> <prompt>` must reach each provider's own binary.
it_sandbox bridge
test_start "integration_ai_providers_in_mise"
it_missing=""
for it_p in claude:cl copilot:copilot kimi:kimi agy:agy aider:aider opencode:opencode sgpt:sgpt \
  ollama:ollama kiro-cli:kiro autohand:autohand vibe:vibe qwen:qwen zai:zai; do
  it_bin="${it_p%%:*}"
  it_stub "$it_bin" "echo \"$it_bin \$*\" >>\"$IT_S/provider.spy\"; exit 0"
  it_env bash "$DOT_CLI" ai "${it_p#*:}" "fixture prompt" >/dev/null 2>&1
  [[ "$(cat "$IT_S/provider.spy" 2>/dev/null)" == *"$it_bin "* ]] || it_missing+=" ${it_p#*:}->$it_bin"
done
assert_empty "$it_missing" "every AI provider in the bridge invokes its binary"

# Source the AI aliases with a stub for every provider on PATH, and read
# back what each alias expands to.
it_sandbox aliases
for it_t in claude gh agy ollama kimi autohand vibe qwen zai; do it_stub "$it_t" "exit 0"; done
IT_ALIASES="$(it_env bash --norc --noprofile -c 'shopt -s expand_aliases; source "$1"; alias' _ \
  "$REPO_ROOT/defaults/.chezmoitemplates/aliases/ai/ai.aliases.sh" 2>&1)"

test_start "integration_ai_aliases_match_bridge"
it_missing=""
for it_a in "km='kimi'" "ah='autohand'" "vb='vibe'" "qw='qwen'" "za='zai'" "dkm='dot ai kimi'"; do
  [[ "$IT_ALIASES" == *"alias $it_a"* ]] || it_missing+=" $it_a"
done
assert_empty "$it_missing" "each installed AI CLI gets its short alias"

test_start "integration_ai_alias_claude"
assert_contains "alias cl='claude'" "$IT_ALIASES" "AI aliases include claude"
test_start "integration_ai_alias_copilot"
assert_contains "alias ghcp='gh copilot'" "$IT_ALIASES" "AI aliases include copilot"
test_start "integration_ai_alias_agy"
assert_contains "alias agys='agy chat'" "$IT_ALIASES" "AI aliases include agy"
test_start "integration_ai_alias_ollama"
assert_contains "alias ol='ollama'" "$IT_ALIASES" "AI aliases include ollama"

# ═══════════════════════════════════════════════════════════════
# 5. PREWARM → CACHE → SHELL STARTUP
# ═══════════════════════════════════════════════════════════════

# Each stub prints the command line it was run with, so a cache file shows
# which init it holds.
it_sandbox prewarm
for it_t in mise starship zoxide atuin fzf gh; do it_stub "$it_t" "echo \"# $it_t \$*\""; done
it_env bash "$REPO_ROOT/scripts/ops/prewarm.sh" >"$IT_S/prewarm.out" 2>&1
IT_CACHE="$IT_S/home/.cache"

test_start "integration_prewarm_generates_completions"
assert_file_exists "$IT_S/home/.local/share/zsh/completions/_gh" "prewarm generates zsh completions"

test_start "integration_prewarm_caches_tools"
it_missing=""
for it_t in mise starship zoxide atuin fzf; do
  [[ -s "$IT_CACHE/zsh/$it_t-init.zsh" ]] || it_missing+=" $it_t"
done
assert_empty "$it_missing" "prewarm caches every core tool's init"

test_start "integration_prewarm_handles_zsh"
assert_equals "# starship init zsh" "$(cat "$IT_CACHE/zsh/starship-init.zsh" 2>/dev/null)" "zsh cache holds the zsh init"
test_start "integration_prewarm_handles_bash"
assert_equals "# starship init bash" "$(cat "$IT_CACHE/bash/starship-init.bash" 2>/dev/null)" "bash cache holds the bash init"
test_start "integration_prewarm_handles_fish"
assert_equals "# starship init fish" "$(cat "$IT_CACHE/fish/starship-init.fish" 2>/dev/null)" "fish cache holds the fish init"
test_start "integration_prewarm_handles_nushell"
assert_equals "# starship init nu" "$(cat "$IT_CACHE/nushell/starship.nu" 2>/dev/null)" "nushell cache holds the nu init"

# The apply wrapper, run against a chezmoi stub with its defaults, must
# leave warm caches behind.
it_sandbox apply
it_stub chezmoi "echo \"chezmoi \$*\" >>\"$IT_S/chezmoi.spy\"; exit 0"
it_stub starship "echo \"# starship \$*\""
it_env env DOTFILES_SNAPSHOT_ON_APPLY=0 DOTFILES_POST_APPLY_REPAIR=0 DOTFILES_CHEZMOI_STATUS=0 \
  bash "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" >"$IT_S/apply.out" 2>&1
test_start "integration_apply_triggers_prewarm"
assert_file_exists "$IT_S/home/.cache/zsh/starship-init.zsh" "apply pre-warms the shell caches"

# ═══════════════════════════════════════════════════════════════
# 6. SHELL COMPLETIONS CONSISTENCY
# ═══════════════════════════════════════════════════════════════

test_start "integration_zsh_completion_exists"
assert_file_exists "$REPO_ROOT/share/completions/zsh/_dot" "zsh completion must exist"

test_start "integration_fish_completion_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl" "fish completion must exist"

# Run _dot at the command position with compsys stubbed: _describe prints
# the candidates it was given.
test_start "integration_completions_include_ai"
if ! command -v zsh >/dev/null 2>&1; then it_skip "zsh not installed"; else
  it_out="$(zsh -f -c '_arguments() { state=cmds; }; _describe() { print -rl -- "${(@P)4}"; }
    _default() { :; }; source "$1"' _ "$REPO_ROOT/share/completions/zsh/_dot" 2>&1)"
  assert_contains $'\nagy:' $'\n'"$it_out" "zsh completion offers the AI commands"
fi

# ═══════════════════════════════════════════════════════════════
# 7. SECURITY POLICY CHAIN
# ═══════════════════════════════════════════════════════════════

test_start "integration_mcp_policy_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/dotfiles/mcp-policy.json" "MCP policy must exist"

test_start "integration_mcp_lock_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/dotfiles/mcp-lock.json" "MCP lock must exist"

test_start "integration_mcp_registry_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/dotfiles/mcp-registry.json" "MCP registry must exist"

# Render the atuin config and apply its history_filter to cloud-CLI auth
# commands (which must be dropped) and to a benign command (which must not).
test_start "integration_atuin_filters_cloud_clis"
if [[ -z "$IT_PY" ]]; then it_skip "python3 not installed"; elif ! it_render \
  "$REPO_ROOT/defaults/dot_config/atuin/config.toml.tmpl" "$IT_WORK/atuin.toml"; then
  it_skip "chezmoi not installed"
else
  it_out="$(
    "$IT_PY" - "$IT_WORK/atuin.toml" <<'PY'
import re, sys, tomllib
with open(sys.argv[1], "rb") as f:
    pats = [re.compile(p) for p in tomllib.load(f)["history_filter"]]
for cmd in ["aws configure", "gcloud auth login", "az login", "kubectl --kubeconfig x get pods", "ls -la"]:
    print("%s=%s" % (cmd, "drop" if any(p.search(cmd) for p in pats) else "keep"))
PY
  )"
  assert_equals $'aws configure=drop\ngcloud auth login=drop\naz login=drop\nkubectl --kubeconfig x get pods=drop\nls -la=keep' \
    "$it_out" "atuin drops cloud CLI auth commands and keeps the rest"
fi

test_start "integration_gitleaks_config_exists"
assert_file_exists "$REPO_ROOT/config/gitleaks.toml" "gitleaks config must exist"

# ═══════════════════════════════════════════════════════════════
# 8. USER EXTENSION POINTS
# ═══════════════════════════════════════════════════════════════

test_start "integration_rc_d_local_sourced"
if [[ -n "$IT_ZSH_SKIP" ]]; then it_skip "$IT_ZSH_SKIP"; else
  assert_contains "rclocal=loaded" "$IT_ZSH_OUT" "zsh sources ZDOTDIR/rc.d.local/*.zsh"
fi

test_start "integration_modules_d_sourced"
if [[ -n "$IT_ZSH_SKIP" ]]; then it_skip "$IT_ZSH_SKIP"; else
  assert_contains "module=loaded" "$IT_ZSH_OUT" "zsh sources dotfiles/modules.d/*/*.sh"
fi

# Headless nvim on a copy of config/lazy.lua, with a stub lazy.nvim whose
# setup() prints the spec imports it was given.
it_sandbox nvim
IT_NVIM_SKIP=""
command -v nvim >/dev/null 2>&1 || IT_NVIM_SKIP="nvim not installed"
it_nv_cfg="$IT_S/home/.config/nvim"
it_nv_lazy="$IT_S/home/.local/share/nvim/lazy/lazy.nvim/lua/lazy"
mkdir -p "$it_nv_cfg/lua/config" "$it_nv_lazy"
cp "$REPO_ROOT/defaults/dot_config/nvim/lua/config/lazy.lua" "$it_nv_cfg/lua/config/lazy.lua"
echo 'require("config.lazy")' >"$it_nv_cfg/init.lua"
cat >"$it_nv_lazy/init.lua" <<'LUA'
return {
  setup = function(opts)
    local out = {}
    for _, s in ipairs(opts.spec) do
      table.insert(out, s.import)
    end
    io.stdout:write("SPEC=" .. table.concat(out, ",") .. "\n")
  end,
}
LUA
it_nvim() { it_env env PATH="$(dirname "$(command -v nvim)"):/usr/bin:/bin" nvim --headless +qa 2>&1; }

test_start "integration_nvim_no_user_plugins"
if [[ -n "$IT_NVIM_SKIP" ]]; then it_skip "$IT_NVIM_SKIP"; else
  assert_equals "SPEC=plugins" "$(it_nvim)" "without lua/plugins.local only the managed specs load"
fi

test_start "integration_nvim_user_plugins"
if [[ -n "$IT_NVIM_SKIP" ]]; then it_skip "$IT_NVIM_SKIP"; else
  mkdir -p "$it_nv_cfg/lua/plugins.local"
  assert_contains "SPEC=plugins,plugins.local" "$(it_nvim)" "lazy.lua imports the user's lua/plugins.local"
fi

# ═══════════════════════════════════════════════════════════════
# 9. DOT CLI HELP — key command categories
# ═══════════════════════════════════════════════════════════════

test_start "integration_help_start_here"
assert_output_contains "Start Here" "bash '$REPO_ROOT/bin/dot' help"

test_start "integration_help_daily_use"
assert_output_contains "Daily Use" "bash '$REPO_ROOT/bin/dot' help"

test_start "integration_help_inspect"
assert_output_contains "Inspect" "bash '$REPO_ROOT/bin/dot' help"

test_start "integration_help_ai_section"
assert_output_contains "AI" "bash '$REPO_ROOT/bin/dot' help"

test_start "integration_help_fleet_section"
assert_output_contains "Fleet" "bash '$REPO_ROOT/bin/dot' help"

test_start "integration_help_configuration"
assert_output_contains "Configuration" "bash '$REPO_ROOT/bin/dot' help"

test_start "integration_help_reference"
assert_output_contains "Reference" "bash '$REPO_ROOT/bin/dot' help"

# ═══════════════════════════════════════════════════════════════
# 10. CHEZMOI DATA FLOW — template variables reach the output
# ═══════════════════════════════════════════════════════════════

test_start "integration_chezmoidata_version_used_in_templates"
if [[ -z "$IT_PY" ]]; then it_skip "python3 not installed"; elif [[ -n "$IT_ZSH_SKIP" ]]; then it_skip "$IT_ZSH_SKIP"; else
  it_ver="$(it_toml "$REPO_ROOT/defaults/.chezmoidata.toml" 'd["dotfiles_version"]')"
  IFS= read -r it_line <"$IT_WORK/zshrc"
  assert_contains "(v$it_ver)" "$it_line" "the rendered zshrc carries dotfiles_version $it_ver"
fi

test_start "integration_chezmoidata_email_used_in_gitconfig"
if ! it_render "$REPO_ROOT/defaults/dot_gitconfig.tmpl" "$IT_WORK/gitconfig"; then it_skip "chezmoi not installed"; else
  assert_equals "fixture@example.invalid" "$(git config --file "$IT_WORK/gitconfig" user.email)" \
    "the rendered gitconfig takes user.email from chezmoi data"
fi

# DOTFILES_FEATURES in a live zsh must list exactly the enabled features.
test_start "integration_chezmoidata_features_used_in_zshrc"
if [[ -z "$IT_PY" ]]; then it_skip "python3 not installed"; elif [[ -n "$IT_ZSH_SKIP" ]]; then it_skip "$IT_ZSH_SKIP"; else
  it_feat="$(it_toml "$REPO_ROOT/defaults/.chezmoidata.toml" '",".join(sorted(k for k, v in d["features"].items() if v))')"
  assert_contains "features=[$it_feat]" "$IT_ZSH_OUT" "zsh exports the enabled .features"
fi

# ═══════════════════════════════════════════════════════════════
# 11. DOT_LOCAL/BIN SCRIPTS
# ═══════════════════════════════════════════════════════════════

# dot-ai reads ~/.dotfiles: link the repo there, stub rg and dot.
it_sandbox dotai
ln -s "$REPO_ROOT" "$IT_S/home/.dotfiles"
it_stub rg 'for a; do case "$a" in /*) [ -e "$a" ] || echo "MISSING-SOURCE:$a" ;; esac; done; echo "fixture context"'
it_stub dot "printf '%s\n' \"\$*\" >>\"$IT_S/dot.spy\""
it_env bash "$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai" "how do I extract?" >"$IT_S/out" 2>&1
IT_DOTAI_SPY="$(cat "$IT_S/dot.spy" 2>/dev/null)"

test_start "integration_dot_ai_script_syntax"
assert_contains "User Question: how do I extract?" "$IT_DOTAI_SPY" "dot-ai sends the question through the AI bridge"

test_start "integration_dot_ai_searches_existing_sources"
assert_false '[[ "$IT_DOTAI_SPY" == *MISSING-SOURCE* ]]' "every directory dot-ai retrieves from exists in the source tree"

# The tour needs a TTY: run it on a pty with gum stubbed to confirm every
# slide and pick "Run dot doctor" at the end.
it_sandbox tour
it_stub gum 'case "$1" in choose) echo "Run dot doctor" ;; style) shift; echo "$*" ;; esac; exit 0'
it_stub clear 'exit 0'
it_stub dot "echo \"dot \$*\" >>\"$IT_S/dot.spy\""
test_start "integration_tour_script_syntax"
it_pty_py="$(command -v python3 2>/dev/null || true)"
if [[ -z "$it_pty_py" ]]; then it_skip "python3 not installed"; else
  it_env "$it_pty_py" -c '
import os, sys
pid, fd = os.forkpty()
if pid == 0:
    os.execv("/bin/sh", ["/bin/sh", sys.argv[1]])
while True:
    try:
        if not os.read(fd, 4096):
            break
    except OSError:
        break
os.waitpid(pid, 0)
' "$REPO_ROOT/defaults/dot_local/bin/executable_tour" >/dev/null 2>&1
  assert_contains "dot doctor" "$(cat "$IT_S/dot.spy" 2>/dev/null)" "the tour runs every slide and hands off to dot doctor"
fi

# ═══════════════════════════════════════════════════════════════
# 12. ROLLBACK SCRIPT
# ═══════════════════════════════════════════════════════════════

test_start "integration_rollback_script_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/rollback.sh" "rollback.sh must exist"

it_sandbox rollback
echo "fixture zshrc" >"$IT_S/home/.zshrc"
test_start "integration_rollback_syntax"
assert_contains "Usage:" "$(it_env bash "$REPO_ROOT/scripts/ops/rollback.sh" --help 2>&1)" "rollback --help prints usage"

it_env bash "$REPO_ROOT/scripts/ops/rollback.sh" backup >/dev/null 2>&1
test_start "integration_rollback_has_backup"
it_bk="$(cat "$IT_S"/home/.local/share/dotfiles/backups/backup_*_manual/.zshrc 2>/dev/null)"
assert_equals "fixture zshrc" "$it_bk" "rollback backup copies the managed dotfiles"

test_start "integration_rollback_has_status"
# The numbered backup list, not the activity log, must show the backup.
assert_output_matches '1\. backup_[0-9_]+_manual' "it_env bash '$REPO_ROOT/scripts/ops/rollback.sh' status"

# ═══════════════════════════════════════════════════════════════
# 13. BUNDLE SCRIPT
# ═══════════════════════════════════════════════════════════════

test_start "integration_bundle_script_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/bundle.sh" "bundle.sh must exist"

# tar and zstd are stubs: the "archive" records the paths handed to tar.
it_sandbox bundle
mkdir -p "$IT_S/home/.dotfiles" "$IT_S/home/.config/chezmoi"
it_stub zstd 'exit 0'
it_stub tar 'while [ $# -gt 0 ]; do case "$1" in
  -cf) out="$2"; shift 2 ;;
  -P) shift; printf "%s\n" "$@" >"$out"; exit 0 ;;
  *) shift ;;
esac; done; exit 1'
it_env bash "$REPO_ROOT/scripts/ops/bundle.sh" "$IT_S/out" >/dev/null 2>&1
test_start "integration_bundle_syntax"
assert_contains "$IT_S/home/.dotfiles" "$(cat "$IT_S"/out/dotfiles_offline_bundle_*.tar.zst 2>/dev/null)" \
  "bundle archives the dotfiles checkout"

# ═══════════════════════════════════════════════════════════════
# 14. HEAL SCRIPTS
# ═══════════════════════════════════════════════════════════════

test_start "integration_heal_script_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal.sh" "heal.sh must exist"

test_start "integration_heal_tools_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-tools.sh" "heal-tools.sh must exist"

test_start "integration_heal_system_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-system.sh" "heal-system.sh must exist"

test_start "integration_heal_chezmoi_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-chezmoi.sh" "heal-chezmoi.sh must exist"

# A dry run over an empty HOME with one dangling symlink.
it_sandbox heal
ln -s "$IT_S/home/nowhere" "$IT_S/home/dangling"
IT_HEAL_OUT="$(it_env bash "$REPO_ROOT/scripts/ops/heal.sh" --dry-run 2>&1)"

test_start "integration_heal_syntax"
assert_contains "Would: remove broken symlink: $IT_S/home/dangling" "$IT_HEAL_OUT" "heal --dry-run finds the broken symlink"

test_start "integration_heal_tools_syntax"
assert_contains "Would: install '" "$IT_HEAL_OUT" "heal --dry-run lists the missing tools it would install"

# ═══════════════════════════════════════════════════════════════
# 15. DOCTOR CHECKS FOR KEY TOOLS
# ═══════════════════════════════════════════════════════════════

it_sandbox doctor
for it_t in claude copilot agy ollama; do it_stub "$it_t" 'exit 0'; done
IT_DOCTOR_OUT="$(it_env bash "$REPO_ROOT/scripts/diagnostics/doctor.sh" 2>&1)"
for it_t in claude copilot agy ollama; do
  test_start "integration_doctor_checks_$it_t"
  assert_contains "$IT_S/bin/$it_t" "$IT_DOCTOR_OUT" "doctor reports where $it_t is installed"
done

# ═══════════════════════════════════════════════════════════════
# 16. SMOKE TEST CHECKS KEY TOOLS
# ═══════════════════════════════════════════════════════════════

test_start "integration_smoke_test_exists"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/smoke-test.sh" "smoke-test.sh must exist"

# A tool mise has installed but that is not on PATH yet (shims not active)
# still counts as present.
it_sandbox smoke
it_stub mise '[ "$1 $2" = "ls --installed" ] && echo "aqua:fixture/zz-fixture-tool  1.0.0" && echo "pipx:shell-gpt/sgpt  1.0.0"; exit 0'
test_start "integration_smoke_test_checks_mise"
it_rc=0
it_env bash -c 'source "$1"; check_cmd zz-fixture-tool' _ "$REPO_ROOT/lib/dot/utils.sh" >/dev/null 2>&1 || it_rc=$?
assert_equals "0" "$it_rc" "check_cmd falls back to mise ls --installed"

# The smoke test uses that lookup: sgpt is found (via mise), so it gets as
# far as the version probe instead of "not found".
test_start "integration_smoke_test_sources_check_cmd"
it_out="$(it_env bash "$REPO_ROOT/scripts/diagnostics/smoke-test.sh" 2>&1)"
it_line="$(printf '%s\n' "$it_out" | grep 'sgpt')"
assert_contains "output mismatch" "$it_line" "the smoke test's tool lookup is mise-aware"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
