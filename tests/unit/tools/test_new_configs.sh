#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Exercises the new configuration files with the programs that read them:
#
#   ripgreprc, .fdignore, bat/config   the real rg / fd / bat
#   firefox user.js, waybar, fish      rendered by the real chezmoi, then
#                                      parsed (user.js, JSONC, CSS) or
#                                      loaded into a real fish
#   nvim dap.lua                       loaded into a headless nvim with the
#                                      nvim-dap module stubbed
#   ipython_config.py                  executed against a config object
#   tmux-sessionizer                   run against stub fzf/tmux/zoxide
#   mpv, zathura, mako, lazygit        parsed (their consumers are Linux
#                                      desktop programs absent on CI hosts)
#
# A consumer that is not installed skips only its own case, with a message.
# Everything runs inside a mktemp sandbox with HOME and XDG_* pointed at it.
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DEFAULTS="$REPO_ROOT/defaults"
CFG="$DEFAULTS/dot_config"
REAL_BASH="${BASH:-$(command -v bash)}"

WORK="$(mktemp -d -t dot-new-configs.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

skip_case() { # <name> <reason>
  printf '  - SKIP %s: %s\n' "$1" "$2"
}

# Config files that must exist
configs=(
  defaults/dot_config/ripgrep/ripgreprc
  defaults/dot_fdignore
  defaults/dot_config/mpv/mpv.conf
  defaults/dot_config/mpv/input.conf
  defaults/dot_config/zathura/zathurarc
  defaults/dot_config/mako/config
  defaults/dot_config/bat/config
  defaults/dot_config/lazygit/config.yml
  defaults/dot_config/user-dirs.dirs
  defaults/dot_config/firefox/user.js.tmpl
  defaults/dot_config/fish/completions/dot-theme-sync.fish.tmpl
  defaults/dot_config/waybar/config.jsonc.tmpl
  defaults/dot_config/waybar/style.css.tmpl
  defaults/dot_config/ipython/profile_default/ipython_config.py
)

for cfg in "${configs[@]}"; do
  name="${cfg##*/}"
  test_start "${name}_exists"
  assert_file_exists "$REPO_ROOT/$cfg" "$name must exist"
done

# ===========================================================================
# ripgrep: run rg with the config as RIPGREP_CONFIG_PATH
# ===========================================================================
RG_TREE="$WORK/rg"
mkdir -p "$RG_TREE/src" "$RG_TREE/node_modules/pkg"
printf 'Hello World\n' >"$RG_TREE/src/upper.txt"
printf 'hello lower\n' >"$RG_TREE/src/lower.txt"
printf 'hello shell\n' >"$RG_TREE/src/run.sh"
printf 'hello vendored\n' >"$RG_TREE/node_modules/pkg/index.txt"

rg_cfg() { # <args...> — sorted list of matching files, relative to the tree
  (cd "$RG_TREE" && RIPGREP_CONFIG_PATH="$CFG/ripgrep/ripgreprc" rg --no-messages -l "$@" . </dev/null | sed "s,^\./,," | LC_ALL=C sort)
}

test_start "ripgrep_smart_case"
if command -v rg >/dev/null 2>&1; then
  assert_equals $'src/lower.txt\nsrc/run.sh\nsrc/upper.txt' "$(rg_cfg hello)" \
    "an all-lowercase pattern matches case-insensitively"
  assert_equals "src/upper.txt" "$(rg_cfg Hello)" \
    "a pattern with an uppercase letter is case-sensitive"
  assert_equals "src/run.sh" "$(rg_cfg -t shell hello)" \
    "the custom 'shell' type selects shell scripts only"
else
  skip_case "ripgrep_smart_case" "rg not installed"
fi

# ===========================================================================
# fd: the ignore file deployed as ~/.fdignore applies below $HOME
# ===========================================================================
test_start "fdignore_node_modules"
if command -v fd >/dev/null 2>&1; then
  cp "$DEFAULTS/dot_fdignore" "$HOME/.fdignore"
  FD_TREE="$HOME/proj"
  mkdir -p "$FD_TREE/src" "$FD_TREE/node_modules/pkg" "$FD_TREE/__pycache__"
  touch "$FD_TREE/src/app.js" "$FD_TREE/src/app.min.js" \
    "$FD_TREE/node_modules/pkg/index.js" "$FD_TREE/__pycache__/m.pyc"
  found="$(cd "$FD_TREE" && fd --type f | LC_ALL=C sort)"
  assert_equals "src/app.js" "$found" \
    "fd skips node_modules, __pycache__ and minified files listed in ~/.fdignore"
  rm -f "$HOME/.fdignore"
else
  skip_case "fdignore_node_modules" "fd not installed"
fi

# ===========================================================================
# bat: render a file with the config as BAT_CONFIG_PATH
# ===========================================================================
test_start "bat_has_style"
if command -v bat >/dev/null 2>&1; then
  printf 'echo hi\n' >"$WORK/sample.sh"
  bat_out="$(cd "$WORK" && BAT_CONFIG_PATH="$CFG/bat/config" bat --color=never \
    --paging=never --decorations=always --terminal-width=60 sample.sh 2>"$WORK/bat.err")"
  assert_contains "File: sample.sh" "$bat_out" "the header style prints the file name"
  assert_contains "   1 │ echo hi" "$bat_out" "the numbers and grid styles frame each line"
  assert_equals "" "$(<"$WORK/bat.err")" "bat accepts every option (theme, pager, syntax maps)"
else
  skip_case "bat_has_style" "bat not installed"
fi

# ===========================================================================
# Templates: rendered by the real chezmoi against a sandbox source holding
# the repository's data files. The theme is chosen through the config file,
# which takes precedence over .chezmoidata.toml.
# ===========================================================================
CHEZMOI_BIN="$(command -v chezmoi 2>/dev/null || true)"
SRC="$WORK/src"
mkdir -p "$SRC/.chezmoidata" "$SRC/.chezmoitemplates"
cp "$DEFAULTS/.chezmoidata.toml" "$SRC/"
cp "$DEFAULTS/.chezmoidata/themes.toml" "$SRC/.chezmoidata/"
cp "$DEFAULTS/.chezmoitemplates/theme-name" "$SRC/.chezmoitemplates/"

render() { # <template> <theme> <out>
  printf '{"data":{"theme":"%s"}}\n' "$2" >"$WORK/chezmoi-$2.json"
  command env -i HOME="$HOME" PATH="/usr/bin:/bin" LANG=C LC_ALL=C \
    "$CHEZMOI_BIN" --config "$WORK/chezmoi-$2.json" --source "$SRC" \
    --destination "$WORK/dest" --cache "$WORK/chezmoi-cache" \
    --persistent-state "$WORK/chezmoi-state.boltdb" \
    execute-template <"$1" >"$3" 2>"$3.err"
}
# theme_value <theme> <dotted.key> — the value from the repository's themes.toml
theme_value() {
  python3 - "$SRC/.chezmoidata/themes.toml" "$1" "$2" <<'PY'
import sys, tomllib
node = tomllib.load(open(sys.argv[1], "rb"))["themes"][sys.argv[2]]
for part in sys.argv[3].split("."):
    node = node[part]
print(node)
PY
}

# user_pref <user.js> <pref> — the pref's value as JSON; fails on any line
# that is neither a comment nor a well-formed user_pref call.
user_pref() {
  python3 - "$1" "$2" <<'PY'
import json, re, sys
prefs = {}
for n, line in enumerate(open(sys.argv[1]), 1):
    s = line.strip()
    if not s or s.startswith("//") or s.startswith("/*"):
        continue
    m = re.fullmatch(r'user_pref\("([^"]+)",\s*(.+)\);', s)
    if not m:
        sys.exit(f"line {n} is not a user_pref call: {s}")
    prefs[m.group(1)] = json.loads(m.group(2))
print(json.dumps(prefs.get(sys.argv[2])))
PY
}

if [[ -n "$CHEZMOI_BIN" ]] && command -v python3 >/dev/null 2>&1; then
  FF_DARK="$WORK/user-dark.js"
  FF_LIGHT="$WORK/user-light.js"
  render "$CFG/firefox/user.js.tmpl" fallback-dark "$FF_DARK"
  render "$CFG/firefox/user.js.tmpl" fallback-light "$FF_LIGHT"

  test_start "firefox_no_telemetry"
  for pref in toolkit.telemetry.enabled toolkit.telemetry.unified \
    datareporting.healthreport.uploadEnabled datareporting.policy.dataSubmissionEnabled; do
    assert_equals "false" "$(user_pref "$FF_DARK" "$pref")" "$pref is disabled"
  done

  test_start "firefox_theme_sync"
  assert_equals "0" "$(user_pref "$FF_DARK" layout.css.prefers-color-scheme.content-override)" \
    "a dark theme asks websites for their dark scheme"
  assert_equals "1" "$(user_pref "$FF_LIGHT" layout.css.prefers-color-scheme.content-override)" \
    "a light theme asks websites for their light scheme"

  test_start "waybar_niri_workspaces"
  WB="$WORK/waybar.json"
  render "$CFG/waybar/config.jsonc.tmpl" fallback-dark "$WB"
  wb_facts="$(
    python3 - "$WB" <<'PY'
import json, sys
text = "".join(l for l in open(sys.argv[1]) if not l.lstrip().startswith("//"))
cfg = json.loads(text)
print("left=" + ",".join(cfg["modules-left"]))
print("format=" + cfg["niri/workspaces"]["format"])
print("months=" + cfg["clock"]["calendar"]["format"]["months"])
PY
  )"
  assert_contains "left=niri/workspaces,niri/window" "$wb_facts" \
    "the rendered JSONC parses and puts niri workspaces on the left"
  assert_contains "format={icon}" "$wb_facts" "the niri/workspaces module is configured"
  assert_contains "color='$(theme_value fallback-dark ui.accent)'" "$wb_facts" \
    "the calendar is coloured with the theme accent"

  test_start "waybar_themed"
  css_rule() { # <css> <selector> <property>
    python3 - "$@" <<'PY'
import re, sys
css, sel, prop = open(sys.argv[1]).read(), sys.argv[2], sys.argv[3]
m = re.search(re.escape(sel) + r"\s*\{([^}]*)\}", css)
decl = dict(
    (k.strip(), v.strip())
    for k, v in (d.split(":", 1) for d in m.group(1).split(";") if ":" in d)
)
print(decl[prop])
PY
  }
  for theme in fallback-dark fallback-light; do
    render "$CFG/waybar/style.css.tmpl" "$theme" "$WORK/waybar-$theme.css"
    assert_equals "$(theme_value "$theme" ui.accent)" \
      "$(css_rule "$WORK/waybar-$theme.css" '#workspaces button.active' background)" \
      "$theme: the active workspace uses the theme accent"
    assert_equals "$(theme_value "$theme" term.fg)" \
      "$(css_rule "$WORK/waybar-$theme.css" 'window#waybar' color)" \
      "$theme: the bar text uses the theme foreground"
  done

  test_start "theme_sync_completion_template"
  if command -v fish >/dev/null 2>&1; then
    COMP="$WORK/dot-theme-sync.fish"
    render "$CFG/fish/completions/dot-theme-sync.fish.tmpl" fallback-dark "$COMP"
    themes_n="$(python3 -c 'import sys, tomllib; print(len(tomllib.load(open(sys.argv[1], "rb"))["themes"]))' \
      "$SRC/.chezmoidata/themes.toml")"
    cands="$(fish --no-config -c "source '$COMP'; complete -C 'dot-theme-sync '")"
    assert_contains $'\nfallback-light\n' $'\n'"$cands"$'\n' "a theme name is offered"
    assert_equals "$themes_n" "$(printf '%s\n' "$cands" | awk 'NF' | wc -l | tr -d ' ')" \
      "every theme in themes.toml is offered"
    flags="$(fish --no-config -c "source '$COMP'; complete -C 'dot-theme-sync --'")"
    assert_contains "--full" "$flags" "--full is completed"
    assert_contains "--help" "$flags" "--help is completed"
  else
    skip_case "theme_sync_completion_template" "fish not installed"
  fi
else
  skip_case "templates" "chezmoi or python3 not installed"
fi

# ===========================================================================
# Parsed configs (consumers are Linux desktop programs)
# ===========================================================================
if command -v python3 >/dev/null 2>&1; then
  test_start "mpv_gpu_hq"
  mpv_top="$(
    python3 - "$CFG/mpv/mpv.conf" <<'PY'
import sys
section = None
for line in open(sys.argv[1]):
    s = line.split("#", 1)[0].strip()
    if not s:
        continue
    if s.startswith("["):
        section = s
        continue
    if section is None and "=" in s:
        k, v = s.split("=", 1)
        print(f"{k}={v}")
PY
  )"
  assert_contains $'\nprofile=gpu-hq\n' $'\n'"$mpv_top"$'\n' \
    "the top-level profile is gpu-hq"

  test_start "zathura_recolor"
  zathura_opts="$(
    python3 - "$CFG/zathura/zathurarc" <<'PY'
import shlex, sys
for line in open(sys.argv[1]):
    words = shlex.split(line, comments=True)
    if len(words) >= 3 and words[0] == "set":
        print(f"{words[1]}={words[2]}")
PY
  )"
  assert_contains $'\nrecolor=true\n' $'\n'"$zathura_opts"$'\n' "recolor is switched on"
  assert_contains $'\nrecolor-keephue=true\n' $'\n'"$zathura_opts"$'\n' "recolor keeps hues"

  test_start "mako_urgency"
  mako_crit="$(
    python3 - "$CFG/mako/config" <<'PY'
import sys
sections, cur = {}, ""
for line in open(sys.argv[1]):
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    if s.startswith("[") and s.endswith("]"):
        cur = s[1:-1]
        continue
    k, v = s.split("=", 1)
    sections.setdefault(cur, {})[k] = v
crit = sections["urgency=critical"]
print(f"timeout={crit['default-timeout']} border={crit['border-color']}")
PY
  )"
  assert_equals "timeout=0 border=#f38ba8" "$mako_crit" \
    "critical notifications never time out and get their own border"

  test_start "lazygit_delta"
  if python3 -c 'import yaml' 2>/dev/null; then
    lg_pager="$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["git"]["paging"]["pager"])' \
      "$CFG/lazygit/config.yml")"
    assert_equals "delta" "${lg_pager%% *}" "the git pager is delta"
    if command -v delta >/dev/null 2>&1; then
      # Run the configured pager command on a real diff.
      printf -- '--- a/f\n+++ b/f\n@@ -1 +1 @@\n-old\n+new\n' >"$WORK/lg.diff"
      rc=0
      pager_out="$(sh -c "$lg_pager" <"$WORK/lg.diff" 2>&1)" || rc=$?
      assert_equals "0" "$rc" "the configured pager command runs"
      assert_contains "new" "$pager_out" "delta renders the diff without paging"
    else
      skip_case "lazygit_delta_runs" "delta not installed"
    fi
  else
    skip_case "lazygit_delta" "python3 yaml module not installed"
  fi

  test_start "ipython_vi_mode"
  ipy="$(
    python3 - "$CFG/ipython/profile_default/ipython_config.py" <<'PY'
import runpy, sys

class Node:
    def __getattr__(self, name):
        if name.startswith("__"):
            raise AttributeError(name)
        value = Node()
        object.__setattr__(self, name, value)
        return value

cfg = Node()
runpy.run_path(sys.argv[1], init_globals={"get_config": lambda: cfg})
shell = cfg.TerminalInteractiveShell
print(f"mode={shell.editing_mode} confirm_exit={shell.confirm_exit}")
print(f"ext={cfg.InteractiveShellApp.extensions}")
PY
  )"
  assert_contains "mode=vi" "$ipy" "the terminal shell uses vi editing"
  assert_contains "ext=['autoreload']" "$ipy" "autoreload is loaded"
else
  skip_case "parsed_configs" "python3 not installed"
fi

# ===========================================================================
# nvim-dap: load the plugin spec in a headless nvim and run its config()
# ===========================================================================
DAP_LUA="$WORK/dap_probe.lua"
cat >"$DAP_LUA" <<'LUA'
local dap = { adapters = {}, configurations = {} }
package.loaded["dap"] = dap
package.loaded["dap.utils"] = { pick_process = function() end }
local spec = dofile(arg[1])
local mason
for _, s in ipairs(spec) do
  if s[1] == "mfussenegger/nvim-dap" then
    s.config()
  elseif s[1] == "jay-babu/mason-nvim-dap.nvim" then
    mason = s.opts.ensure_installed
  end
end
local function say(k, v)
  io.write(k, "=", tostring(v), "\n")
end
local got
dap.adapters.python(function(a)
  got = a
end, { request = "launch" })
say("python_launch", got.type .. " " .. got.command)
dap.adapters.python(function(a)
  got = a
end, { request = "attach", connect = { port = 5678 } })
say("python_attach", got.type .. " " .. got.host .. ":" .. got.port)
say("delve", dap.adapters.delve.executable.command)
say("codelldb", dap.adapters.codelldb.executable.command)
say("bashdb", dap.adapters.bashdb.command)
for _, ft in ipairs({ "python", "go", "rust", "c", "cpp", "sh" }) do
  local seen = {}
  for _, c in ipairs(dap.configurations[ft] or {}) do
    seen[c.type] = true
  end
  local types = vim.tbl_keys(seen)
  table.sort(types)
  say("ft_" .. ft, table.concat(types, ","))
end
say("mason", table.concat(mason, ","))
LUA

if command -v nvim >/dev/null 2>&1; then
  dap_out="$(nvim --clean -l "$DAP_LUA" "$CFG/nvim/lua/plugins/dap.lua" 2>&1)"
  NVIM_DATA="$XDG_DATA_HOME/nvim"
  dap_val() { printf '%s\n' "$dap_out" | awk -v k="$1=" 'index($0, k) == 1 { print substr($0, length(k) + 1) }'; }
  mason_has() { [[ ",${dap_out##*mason=}," == *",$1,"* ]] && echo yes || echo no; }

  test_start "dap_python"
  assert_equals "executable $NVIM_DATA/mason/bin/debugpy-adapter" "$(dap_val python_launch)" \
    "launching python starts the Mason debugpy adapter"
  assert_equals "server 127.0.0.1:5678" "$(dap_val python_attach)" \
    "attaching connects to the debugpy server"
  assert_equals "python" "$(dap_val ft_python)" "python files get debugpy configurations"
  assert_equals "yes" "$(mason_has python)" "Mason installs debugpy"

  test_start "dap_go"
  assert_equals "dlv" "$(dap_val delve)" "the delve adapter runs dlv"
  assert_equals "delve" "$(dap_val ft_go)" "go files get delve configurations"
  assert_equals "yes" "$(mason_has delve)" "Mason installs delve"

  test_start "dap_rust"
  assert_equals "$NVIM_DATA/mason/bin/codelldb" "$(dap_val codelldb)" \
    "the codelldb adapter runs Mason's codelldb"
  for ft in rust c cpp; do
    assert_equals "codelldb" "$(dap_val ft_$ft)" "$ft files get codelldb configurations"
  done
  assert_equals "yes" "$(mason_has codelldb)" "Mason installs codelldb"

  test_start "dap_bash"
  assert_equals "$NVIM_DATA/mason/packages/bash-debug-adapter/bash-debug-adapter" \
    "$(dap_val bashdb)" "the bashdb adapter runs Mason's bash-debug-adapter"
  assert_equals "bashdb" "$(dap_val ft_sh)" "sh files get bashdb configurations"
  assert_equals "yes" "$(mason_has bash)" "Mason installs the bash adapter"
else
  skip_case "dap" "nvim not installed"
fi

# ===========================================================================
# tmux-sessionizer: stub fzf, tmux and zoxide, record what they are asked
# ===========================================================================
SESS_BIN="$WORK/sess-bin"
CALLS="$WORK/sess-calls"
mkdir -p "$SESS_BIN"
# fzf: save the offered list, then pick the line matching $FZF_PICK.
cat >"$SESS_BIN/fzf" <<STUB
#!$REAL_BASH
cat >"$WORK/fzf-input"
grep -m1 -- "\$FZF_PICK" "$WORK/fzf-input" || exit 1
STUB
# tmux: log the call; list-sessions prints \$TMUX_SESSIONS; has-session fails.
cat >"$SESS_BIN/tmux" <<STUB
#!$REAL_BASH
printf 'tmux %s\n' "\$*" >>"$CALLS"
case "\$1" in
  list-sessions) [[ -n "\${TMUX_SESSIONS:-}" ]] && printf '%s\n' \$TMUX_SESSIONS ;;
  has-session) exit 1 ;;
esac
exit 0
STUB
cat >"$SESS_BIN/zoxide" <<STUB
#!$REAL_BASH
printf 'zoxide %s\n' "\$*" >>"$CALLS"
[[ "\$1 \${2:-}" == "query --list" ]] && printf '%s\n' "$WORK/frecent/webapp"
exit 0
STUB
chmod +x "$SESS_BIN/fzf" "$SESS_BIN/tmux" "$SESS_BIN/zoxide"
mkdir -p "$WORK/frecent/webapp"

run_sessionizer() { # <env...> -- <args...>
  local envs=()
  while [[ "$1" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  : >"$CALLS"
  command env -u TMUX PATH="$SESS_BIN:/usr/bin:/bin" HOME="$HOME" \
    TMUX_SESSIONIZER_DIRS="$WORK/no-such-dir" "${envs[@]}" \
    "$REAL_BASH" "$DEFAULTS/dot_local/bin/executable_tmux-sessionizer" "$@" \
    </dev/null >"$WORK/sess-out" 2>&1
}

test_start "sessionizer_zoxide"
run_sessionizer FZF_PICK=webapp --
assert_contains "$WORK/frecent/webapp" "$(cat "$WORK/fzf-input" 2>/dev/null)" \
  "zoxide's frecent directory is offered in the picker"
assert_contains "tmux new-session -ds webapp -c $WORK/frecent/webapp" "$(cat "$CALLS")" \
  "picking it creates a session rooted there"
assert_contains "zoxide add $WORK/frecent/webapp" "$(cat "$CALLS")" \
  "the visit is recorded back into zoxide"
assert_contains "tmux attach-session -t webapp" "$(cat "$CALLS")" "the new session is attached"

test_start "sessionizer_kill"
run_sessionizer FZF_PICK=beta "TMUX_SESSIONS=alpha beta" -- --kill
assert_equals $'alpha\nbeta' "$(cat "$WORK/fzf-input" 2>/dev/null)" \
  "the running sessions are offered"
assert_contains "tmux kill-session -t beta" "$(cat "$CALLS")" "the picked session is killed"
assert_contains "Killed:" "$(cat "$WORK/sess-out")" "the kill is reported"
assert_equals "" "$(grep -e '-t alpha' "$CALLS")" "the other session survives"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
