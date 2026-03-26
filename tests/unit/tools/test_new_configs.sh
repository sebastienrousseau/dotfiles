#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Validates all new configuration files exist and have correct structure
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# Config files that must exist
configs=(
  dot_config/ripgrep/ripgreprc
  dot_fdignore
  dot_config/mpv/mpv.conf
  dot_config/mpv/input.conf
  dot_config/zathura/zathurarc
  dot_config/mako/config
  dot_config/bat/config
  dot_config/lazygit/config.yml
  dot_config/user-dirs.dirs
  dot_config/firefox/user.js
  dot_config/fish/completions/dot-theme-sync.fish.tmpl
  dot_config/waybar/config.jsonc.tmpl
  dot_config/waybar/style.css.tmpl
  dot_config/ipython/profile_default/ipython_config.py
)

for cfg in "${configs[@]}"; do
  name="${cfg##*/}"
  test_start "${name}_exists"
  assert_file_exists "$REPO_ROOT/$cfg" "$name must exist"
done

# Ripgrep has smart-case
test_start "ripgrep_smart_case"
assert_file_contains "$REPO_ROOT/dot_config/ripgrep/ripgreprc" "smart-case" "ripgrep must have smart-case"

# MPV has gpu-hq
test_start "mpv_gpu_hq"
assert_file_contains "$REPO_ROOT/dot_config/mpv/mpv.conf" "gpu-hq" "mpv must have gpu-hq profile"

# Zathura has recolor
test_start "zathura_recolor"
assert_file_contains "$REPO_ROOT/dot_config/zathura/zathurarc" "recolor" "zathura must have recolor"

# Mako has urgency levels
test_start "mako_urgency"
assert_file_contains "$REPO_ROOT/dot_config/mako/config" "urgency=critical" "mako must have urgency levels"

# Firefox disables telemetry
test_start "firefox_no_telemetry"
assert_file_contains "$REPO_ROOT/dot_config/firefox/user.js" "telemetry" "firefox must disable telemetry"

# fd ignore has node_modules
test_start "fdignore_node_modules"
assert_file_contains "$REPO_ROOT/dot_fdignore" "node_modules" "fdignore must exclude node_modules"

# dot-theme-sync completion is a template
test_start "theme_sync_completion_template"
assert_file_contains "$REPO_ROOT/dot_config/fish/completions/dot-theme-sync.fish.tmpl" "dot-theme-sync" "must complete dot-theme-sync"

# Bat has style
test_start "bat_has_style"
assert_file_contains "$REPO_ROOT/dot_config/bat/config" "style" "bat must have style config"

# Lazygit has delta pager
test_start "lazygit_delta"
assert_file_contains "$REPO_ROOT/dot_config/lazygit/config.yml" "delta" "lazygit must use delta pager"

# Waybar has niri workspaces
test_start "waybar_niri_workspaces"
assert_file_contains "$REPO_ROOT/dot_config/waybar/config.jsonc.tmpl" "niri/workspaces" "waybar must have niri workspaces"

# Waybar style uses theme vars
test_start "waybar_themed"
assert_file_contains "$REPO_ROOT/dot_config/waybar/style.css.tmpl" 'ui.accent' "waybar style must use theme accent"

# IPython has vi mode
test_start "ipython_vi_mode"
assert_file_contains "$REPO_ROOT/dot_config/ipython/profile_default/ipython_config.py" "vi" "ipython must have vi mode"

# DAP has Python debugger
test_start "dap_python"
assert_file_contains "$REPO_ROOT/dot_config/nvim/lua/plugins/dap.lua" "debugpy" "dap must have python debugging"

# DAP has Go debugger
test_start "dap_go"
assert_file_contains "$REPO_ROOT/dot_config/nvim/lua/plugins/dap.lua" "delve" "dap must have go debugging"

# DAP has Rust/C debugger
test_start "dap_rust"
assert_file_contains "$REPO_ROOT/dot_config/nvim/lua/plugins/dap.lua" "codelldb" "dap must have rust/c debugging"

# DAP has bash debugger
test_start "dap_bash"
assert_file_contains "$REPO_ROOT/dot_config/nvim/lua/plugins/dap.lua" "bashdb" "dap must have bash debugging"

# tmux-sessionizer has zoxide
test_start "sessionizer_zoxide"
assert_file_contains "$REPO_ROOT/dot_local/bin/executable_tmux-sessionizer" "zoxide" "sessionizer must have zoxide integration"

# tmux-sessionizer has kill option
test_start "sessionizer_kill"
assert_file_contains "$REPO_ROOT/dot_local/bin/executable_tmux-sessionizer" "kill" "sessionizer must support kill"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
