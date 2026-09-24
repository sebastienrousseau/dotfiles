#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot-theme-sync behaviour: runs the script end to end and its reload /
# regeneration functions in a sandbox, asserting outcomes (exit status,
# output, files written, stubs invoked or not), and renders the
# theme-dependent templates with the real chezmoi renderer against fixture
# theme data.
#
# Hermetic: HOME and the XDG dirs live in a mktemp sandbox, the chezmoi
# source is a synthetic tree, and every subprocess runs under `env -i` with
# a PATH of recording stubs plus a symlinked toolbox of core utilities.
# Nothing reaches the network or the real HOME.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/bin/dot-theme-sync"
DEFAULTS="$REPO_ROOT/defaults"
TMUX_AI="$DEFAULTS/dot_local/bin/executable_tmux-ai"
TMUX_STATUS="$DEFAULTS/dot_local/bin/executable_tmux-status"
PLIST_TEMPLATE="$DEFAULTS/private_Library/LaunchAgents/com.sebastienrousseau.dot-theme-auto.plist.tmpl"
INSTALLER_TEMPLATE="$DEFAULTS/run_onchange_after_31-theme-auto-launchagent.sh.tmpl"
REAL_BASH="${BASH:-$(command -v bash)}"
CHEZMOI_BIN="$(command -v chezmoi 2>/dev/null || true)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-theme-sync.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
CFG="$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
OUT="$WORK/out"
ERR="$WORK/err"
CALLS="$WORK/calls"
mkdir -p "$WORK/tmp" "$WORK/run" "$WORK/lock" "$CALLS"

# ---------------------------------------------------------------------------
# Toolbox: only core utilities, so host desktop tools stay invisible.
# ---------------------------------------------------------------------------
TOOLS="$WORK/tools"
mkdir -p "$TOOLS"
for t in awk sed grep sort head tail tr cut mktemp mv cp cat date dirname \
  basename readlink rm mkdir rmdir cmp id sha256sum shasum sleep wc ls touch; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" && "$p" == /* ]] && ln -s "$p" "$TOOLS/$t"
done
# Resolve the interpreter behind any version-manager shim so it works
# without that manager's environment.
PY3="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null || true)"
[[ -n "$PY3" ]] && ln -s "$PY3" "$TOOLS/python3"

# ---------------------------------------------------------------------------
# Stubs: one directory per platform (uname) plus a common set.
# ---------------------------------------------------------------------------
STUBS="$WORK/stubs"
mkstub() { # <dir> <name>; body on stdin
  mkdir -p "$STUBS/$1"
  {
    printf '#!%s\n' "$REAL_BASH"
    cat
  } >"$STUBS/$1/$2"
  chmod +x "$STUBS/$1/$2"
}
mkstub Darwin uname <<'EOF'
echo Darwin
EOF
mkstub Linux uname <<'EOF'
echo Linux
EOF
mkstub common chezmoi <<'EOF'
printf '%s\n' "$*" >>"$CALLS/chezmoi"
exit "${FAKE_CHEZMOI_RC:-0}"
EOF
mkstub common pgrep <<'EOF'
exit 1
EOF
mkstub launchctl launchctl <<'EOF'
printf '%s\n' "$*" >>"$CALLS/launchctl"
[[ "${1:-}" == bootstrap && "${FAKE_LAUNCHCTL_FAIL:-0}" == 1 ]] && exit 1
exit 0
EOF

# ---------------------------------------------------------------------------
# Synthetic chezmoi source tree with fixture theme data.
# ---------------------------------------------------------------------------
SRC="$WORK/src"
mkdir -p "$SRC/.chezmoidata" "$SRC/.chezmoitemplates" "$SRC/private_Library/LaunchAgents"
cp "$DEFAULTS/.chezmoitemplates/theme-name" "$SRC/.chezmoitemplates/theme-name"
cp "$PLIST_TEMPLATE" "$SRC/private_Library/LaunchAgents/"
: >"$SRC/run_onchange_22-iterm2-profile.sh.tmpl"
DATA_FILE="$SRC/.chezmoidata.toml"
THEMES_FILE="$SRC/.chezmoidata/themes.toml"
cat >"$DATA_FILE" <<'TOML'
dotfiles_version = "0.0.0-fixture"
theme = "fixture-dark"
theme_family = "fixture"
theme_mode = "dark"
terminal_font_family = "Fixture Mono"
terminal_font_size = 13
default_shell = "bash"

[features]
linux_desktop = false
niri = false
TOML
cat >"$THEMES_FILE" <<'TOML'
[themes.fixture-dark]
mode = "dark"
family = "fixture"
macos_accent = 5
wallpaper = ""
source = "custom"

[themes.fixture-dark.term]
bg = "#101820"
fg = "#e6edf3"
cursor = "#7aa2f7"
cursor_text = "#101820"
sel_bg = "#283040"
sel_fg = "#e6edf3"
c0 = "#1f2733"
c1 = "#ff5d62"
c2 = "#98bb6c"
c3 = "#e6c384"
c4 = "#3d7bff"
c5 = "#957fb8"
c6 = "#7fb4ca"
c7 = "#c8c093"
c8 = "#727169"
c9 = "#e82424"
c10 = "#76946a"
c11 = "#ff9e3b"
c12 = "#7e9cd8"
c13 = "#938aa9"
c14 = "#6a9589"
c15 = "#dcd7ba"

[themes.fixture-dark.ui]
accent = "#ff8800"
accent_text = "#000000"
error = "#ff2255"
warning = "#ffcc00"
success = "#22cc55"
info = "#3d7bff"
panel = "#1b2430"
border = "#2a3444"
secondary = "#22ccaa"
tertiary = "#cc66ff"
text_muted = "#9aa4b2"
accent_on_surface = "#ff8800"
secondary_on_surface = "#22ccaa"
tertiary_on_surface = "#cc66ff"

[themes.fixture-dark.app]
nvim = "tokyonight-night"
nvim_style = "night"
gtk_theme = "Adwaita-dark"
gtk_icon = "Papirus-Dark"
gnome_shell = ""

[themes.fixture-light]
mode = "light"
family = "fixture"
macos_accent = 2
wallpaper = ""
source = "custom"

[themes.fixture-light.term]
bg = "#fbf7ef"
fg = "#1c1f26"
cursor = "#0044cc"
cursor_text = "#fbf7ef"
sel_bg = "#dde3ee"
sel_fg = "#1c1f26"
c0 = "#5c6370"
c1 = "#c8323c"
c2 = "#3f7a1e"
c3 = "#9a6b00"
c4 = "#0044cc"
c5 = "#7a3ea0"
c6 = "#137a8a"
c7 = "#2b2f3a"
c8 = "#8a919c"
c9 = "#e04b55"
c10 = "#5a9a3a"
c11 = "#b98400"
c12 = "#2f6fe0"
c13 = "#9a5fc0"
c14 = "#2a9ab0"
c15 = "#12151c"

[themes.fixture-light.ui]
accent = "#0066ff"
accent_text = "#ffffff"
error = "#cc0022"
warning = "#aa7700"
success = "#2a8a3a"
info = "#0044cc"
panel = "#eee9dd"
border = "#d6d0c2"
secondary = "#0a8a70"
tertiary = "#8a3ac0"
text_muted = "#5c6370"
accent_on_surface = "#0066ff"
secondary_on_surface = "#0a8a70"
tertiary_on_surface = "#8a3ac0"

[themes.fixture-light.app]
nvim = "tokyonight-day"
nvim_style = "day"
gtk_theme = "Adwaita"
gtk_icon = "Papirus-Light"

[themes.bare-dark]
mode = "dark"
family = "bare"
TOML

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
EXTRA_ENV=()
reset_calls() {
  rm -rf "$CALLS"
  mkdir -p "$CALLS"
}
reset_home() {
  rm -rf "$HOME" "$WORK/lock" "$WORK/run"
  mkdir -p "$XDG_CONFIG_HOME/chezmoi" "$XDG_STATE_HOME" "$WORK/lock" "$WORK/run"
}
seed_targets() {
  mkdir -p "$XDG_CONFIG_HOME/kitty" "$XDG_CONFIG_HOME/tmux" "$XDG_CONFIG_HOME/ghostty" "$HOME/.codex/themes"
  printf 'palette = "old"\n' >"$XDG_CONFIG_HOME/starship.toml"
  printf 'background #000000\n' >"$XDG_CONFIG_HOME/kitty/kitty.conf"
  printf 'set -g status on\n' >"$XDG_CONFIG_HOME/tmux/tmux.conf"
  printf '<plist/>\n' >"$HOME/.codex/themes/dotfiles.tmTheme"
  printf 'background = #000000\n' >"$XDG_CONFIG_HOME/ghostty/config"
}
# Run the script as a subprocess with only stubs and the toolbox on PATH.
run_sync() { # <platform> [args...]
  local platform="$1"
  shift
  command env -i HOME="$HOME" PATH="$STUBS/$platform:$STUBS/common:$TOOLS" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    XDG_RUNTIME_DIR="$WORK/run" TMPDIR="$WORK/tmp" LANG=C LC_ALL=C \
    CHEZMOI_SOURCE_DIR="$SRC" DOT_THEME_LOCK_ROOT="$WORK/lock" CALLS="$CALLS" \
    ${EXTRA_ENV[@]+"${EXTRA_ENV[@]}"} \
    "$REAL_BASH" "$SCRIPT_FILE" "$@" >"$OUT" 2>"$ERR"
}
# Source the script (its guard keeps main from running) and run a case body
# from stdin under the script's own set -euo pipefail, with shell-function
# stubs standing in for the external commands.
run_fn() { # <platform> [shell]
  local platform="$1" shell="${2:-$REAL_BASH}"
  cat >"$WORK/case.sh"
  command env -i HOME="$HOME" PATH="$STUBS/$platform:$STUBS/common:$TOOLS" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    XDG_RUNTIME_DIR="$WORK/run" TMPDIR="$WORK/tmp" LANG=C LC_ALL=C \
    CHEZMOI_SOURCE_DIR="$SRC" DOT_THEME_LOCK_ROOT="$WORK/lock" CALLS="$CALLS" \
    ${EXTRA_ENV[@]+"${EXTRA_ENV[@]}"} \
    "$shell" -c 'source "$1"; source "$2"' _ "$SCRIPT_FILE" "$WORK/case.sh" >"$OUT" 2>"$ERR"
}
calls() { cat "$CALLS/$1" 2>/dev/null || true; }
has() { [[ "$2" == *"$1"* ]] && echo yes || echo no; }
# Render a template with the real chezmoi against the fixture source. The
# `.chezmoi` map is replaced by a fixture so the OS and home directory are
# deterministic on every host.
RENDER="$WORK/render"
mkdir -p "$RENDER" "$WORK/chezmoi-dest"
printf '{}\n' >"$WORK/chezmoi.json"
for os in darwin linux; do
  printf '{"os":"%s","arch":"arm64","homeDir":"/DOT_HOME","sourceDir":"/DOT_SOURCE","username":"fixture","hostname":"fixture-host","kernel":{"osrelease":"fixture"}}\n' \
    "$os" >"$SRC/.chezmoi-$os.json"
done
render_template() { # <template> <os> <theme> <output>
  local template="$1" os="$2" theme="$3" out="$4"
  {
    printf '{{- $_ := set $ "chezmoi" (include ".chezmoi-%s.json" | fromJson) -}}' "$os"
    printf '{{- $_ := set $ "theme" "%s" -}}' "$theme"
    cat "$template"
  } | command env -i HOME="$HOME" PATH="$TOOLS" LANG=C LC_ALL=C \
    "$CHEZMOI_BIN" --config "$WORK/chezmoi.json" --source "$SRC" \
    --destination "$WORK/chezmoi-dest" --cache "$WORK/chezmoi-cache" \
    --persistent-state "$WORK/chezmoi-state.boltdb" \
    execute-template >"$out" 2>"$out.err"
}

# ===========================================================================
# Command-line surface
# ===========================================================================
test_start "help_describes_coordinated_applications"
reset_home
run_sync Linux --help
assert_equals 0 $? "--help exits 0"
assert_contains "USAGE" "$(cat "$OUT")" "usage block is printed"
assert_contains "Browsers   desktop sync + Firefox content preference" "$(cat "$OUT")" \
  "usage mentions browser coordination"

test_start "unknown_flag_prints_usage_and_fails"
run_sync Linux --definitely-not-a-flag
assert_equals 1 $? "unknown flag exits 1"
assert_contains "unknown flag" "$(cat "$OUT")" "unknown flag is named"
assert_contains "USAGE" "$(cat "$OUT")" "usage follows the error"

test_start "json_requires_plan"
run_sync Linux fixture-dark --json
assert_equals 1 $? "--json without --plan exits 1"
assert_contains "requires --plan" "$(cat "$ERR")" "error names the missing flag"

# ===========================================================================
# Theme name validation
# ===========================================================================
test_start "rejects_theme_names_outside_the_safe_charset"
reset_home
reset_calls
run_sync Linux 'bad;name'
assert_equals 1 $? "shell metacharacters are refused"
assert_contains "Invalid" "$(cat "$OUT")" "invalid name is reported"
assert_file_not_exists "$CFG" "no machine state is written for a bad name"
assert_equals "" "$(calls chezmoi)" "renderer never runs for a bad name"

test_start "rejects_theme_missing_from_manifest"
run_sync Linux ghost-dark
assert_equals 1 $? "unknown theme exits 1"
assert_contains "Unknown" "$(cat "$OUT")" "unknown theme is reported"
assert_contains "dot theme list" "$(cat "$OUT")" "remedy is suggested"
assert_file_not_exists "$CFG" "no machine state is written for an unknown theme"

# ===========================================================================
# Dry run and plan are pure
# ===========================================================================
test_start "dry_run_writes_nothing"
reset_home
reset_calls
run_sync Linux fixture-light --dry-run
assert_equals 0 $? "dry run exits 0"
assert_contains 'write theme="fixture-light"' "$(cat "$OUT")" "dry run previews the state write"
assert_contains "no changes made" "$(cat "$OUT")" "dry run reports completion"
assert_file_not_exists "$CFG" "dry run leaves machine state absent"
assert_equals "" "$(calls chezmoi)" "dry run never calls the renderer"

test_start "plan_reads_machine_override_before_repo_default"
reset_home
reset_calls
printf '[data]\ntheme = "fixture-light"\ntheme_mode = "light"\n' >"$CFG"
run_sync Linux fixture-dark --plan --json
assert_equals 0 $? "plan exits 0"
previous="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["previous"]["name"], d["previous"]["preference"])' "$OUT" 2>/dev/null)"
assert_equals "fixture-light light" "$previous" "machine-local chezmoi.toml wins over the tracked default"
desired="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["desired"]["name"], d["desired"]["family"], d["desired"]["mode"])' "$OUT" 2>/dev/null)"
assert_equals "fixture-dark fixture dark" "$desired" "desired theme resolves family and mode"
assert_equals "" "$(calls chezmoi)" "plan never calls the renderer"
assert_dir_not_exists "$XDG_STATE_HOME/dot/theme-transactions" "plan opens no transaction"

# ===========================================================================
# Apply: machine-local state, targeted regeneration, transaction outcome
# ===========================================================================
test_start "apply_persists_runtime_state_in_machine_config"
reset_home
reset_calls
seed_targets
before="$(cksum <"$DATA_FILE")"
run_sync Linux fixture-light
assert_equals 0 $? "apply exits 0"
assert_file_contains "$CFG" '[data]' "machine config gains a data table"
assert_file_contains "$CFG" 'theme = "fixture-light"' "selected theme is persisted"
assert_file_contains "$CFG" 'theme_family = "fixture"' "family is persisted"
assert_file_contains "$CFG" 'theme_mode = "light"' "manual mode is persisted"
assert_equals "$before" "$(cksum <"$DATA_FILE")" "tracked repository default is untouched"
assert_equals "fixture-light" "$(sed -n 's/^theme = "\(.*\)"$/\1/p' "$CFG")" "theme key is written exactly once"
journal="$(cat "$XDG_STATE_HOME"/dot/theme-transactions/*/journal.json 2>/dev/null)"
assert_contains '"status": "succeeded"' "$journal" "transaction journal records success"
assert_equals "" "$(ls "$WORK/lock" 2>/dev/null)" "theme lock is released"

test_start "apply_regenerates_only_installed_theme_targets"
first_call="$(calls chezmoi | head -1)"
apply_call="$(calls chezmoi | grep -v -- '--dry-run' | head -1)"
assert_contains "apply --dry-run --force" "$first_call" "validation dry run precedes the apply"
assert_contains "$HOME/.config/starship.toml" "$apply_call" "Starship prompt is regenerated"
assert_contains "$HOME/.config/kitty/kitty.conf" "$apply_call" "Kitty palette is regenerated"
assert_contains "$HOME/.config/tmux/tmux.conf" "$apply_call" "tmux theme is regenerated"
assert_contains "$HOME/.codex/themes/dotfiles.tmTheme" "$apply_call" "Codex syntax theme is regenerated"
assert_equals no "$(has "alacritty" "$apply_call")" "absent targets are not rendered"
assert_equals no "$(has "iterm2" "$(calls chezmoi)")" "iTerm2 profile is Darwin-only"
assert_contains "regenerated 5 configs" "$(cat "$OUT")" "summary counts the rendered targets"

test_start "apply_is_idempotent_for_the_active_theme"
reset_calls
run_sync Linux fixture-light
assert_equals 0 $? "re-applying the active theme exits 0"
assert_contains "already active" "$(cat "$OUT")" "idempotent path is reported"
assert_equals "" "$(calls chezmoi)" "renderer is skipped"

test_start "auto_flag_persists_auto_mode"
reset_calls
run_sync Linux fixture-dark --auto
assert_equals 0 $? "auto apply exits 0"
assert_file_contains "$CFG" 'theme = "fixture-dark"' "resolved theme is persisted"
assert_file_contains "$CFG" 'theme_mode = "auto"' "auto preference replaces the manual mode"

test_start "renderer_failure_rolls_back_machine_state"
reset_calls
rm -rf "$XDG_STATE_HOME/dot/theme-transactions"
EXTRA_ENV=(FAKE_CHEZMOI_RC=1)
run_sync Linux fixture-light
rc=$?
EXTRA_ENV=()
assert_equals 1 "$rc" "failed render exits 1"
assert_contains "rolling back" "$(cat "$OUT")" "rollback is announced"
assert_file_contains "$CFG" 'theme = "fixture-dark"' "previous theme is restored"
assert_file_contains "$CFG" 'theme_mode = "auto"' "previous mode is restored"
journal="$(cat "$XDG_STATE_HOME"/dot/theme-transactions/*/journal.json 2>/dev/null)"
assert_contains '"status": "rolled_back"' "$journal" "journal records the rollback"
assert_equals "" "$(ls "$WORK/lock" 2>/dev/null)" "lock is released after rollback"

test_start "darwin_apply_refreshes_iterm2_and_mirrors_ghostty"
reset_home
reset_calls
seed_targets
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
run_sync Darwin fixture-light
assert_equals 0 $? "Darwin apply exits 0"
assert_contains "--source-path $SRC/run_onchange_22-iterm2-profile.sh.tmpl" "$(calls chezmoi)" \
  "targeted apply addresses the iTerm2 run_onchange source"
assert_equals no "$(has "Application Support" "$(calls chezmoi)")" "native Ghostty mirror is never passed to chezmoi"
assert_file_exists "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "macOS Ghostty config is created"
assert_true "cmp -s '$XDG_CONFIG_HOME/ghostty/config' '$HOME/Library/Application Support/com.mitchellh.ghostty/config'" \
  "macOS Ghostty config mirrors the XDG config"
assert_contains "mirrored config to macOS app support" "$(cat "$OUT")" "mirror is reported"

test_start "apply_coordinates_ai_cli_provider_themes"
reset_home
reset_calls
mkdir -p "$SRC/scripts/theme"
cat >"$SRC/scripts/theme/sync-ai-cli-themes.py" <<'PY'
import json, os, sys
with open(os.path.join(os.environ["CALLS"], "ai-helper"), "a") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
print(json.dumps({"providers": [
    {"provider": "codex", "status": "updated"},
    {"provider": "claude", "status": "unchanged"},
    {"provider": "gemini", "status": "disabled"},
    {"provider": "qwen", "status": "conflict"},
]}))
PY
run_sync Linux fixture-dark --force
assert_equals 0 $? "apply with AI adapter exits 0"
assert_contains "--theme fixture-dark" "$(calls ai-helper)" "adapter receives the active theme"
assert_contains "--themes-file $THEMES_FILE" "$(calls ai-helper)" "adapter receives the theme manifest"
assert_contains "--machine-config $CFG" "$(calls ai-helper)" "adapter receives the machine config"
assert_contains "checked codex, claude" "$(cat "$OUT")" "applied providers are summarised"
assert_contains "optional adapter warnings: qwen=conflict" "$(cat "$OUT")" "provider issues are surfaced as warnings"
rm -rf "$SRC/scripts"

# ===========================================================================
# Application reload functions (sourced, with shell-function stubs)
# ===========================================================================
test_start "ghostty_reloads_over_dbus_first"
reset_home
reset_calls
run_fn Linux <<'EOF'
busctl() { printf '%s\n' "$*" >>"$CALLS/busctl"; }
kill() { printf '%s\n' "$*" >>"$CALLS/kill"; }
reload_ghostty
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_contains "org.gtk.Actions Activate" "$(calls busctl)" "GTK action interface is used"
assert_contains "reload-config" "$(calls busctl)" "reload-config action is activated"
assert_equals "" "$(calls kill)" "no signal is sent when DBus succeeds"
assert_contains "DBus reload-config" "$(cat "$OUT")" "DBus reload is reported"
assert_contains "RELOADED=ghostty" "$(cat "$OUT")" "ghostty counts as reloaded"

test_start "ghostty_falls_back_to_sigusr2_on_macos_app_bundle"
reset_calls
run_fn Darwin <<'EOF'
busctl() { return 1; }
uname() { echo Darwin; }
pgrep() { case "$*" in *'Ghostty\.app'*) echo 4242 ;; *) return 1 ;; esac; }
kill() { printf '%s\n' "$*" >>"$CALLS/kill"; }
reload_ghostty
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_equals "-SIGUSR2 4242" "$(calls kill)" "app-bundle process receives SIGUSR2"
assert_contains "SIGUSR2 → PID 4242" "$(cat "$OUT")" "signal fallback is reported"
assert_contains "RELOADED=ghostty" "$(cat "$OUT")" "ghostty counts as reloaded"

test_start "ghostty_skips_when_nothing_is_running"
reset_calls
run_fn Linux <<'EOF'
busctl() { return 1; }
kill() { printf '%s\n' "$*" >>"$CALLS/kill"; }
reload_ghostty
printf 'SKIPPED=%s\n' "${SKIPPED[*]:-}"
EOF
assert_equals "" "$(calls kill)" "no signal without a target"
assert_contains "SKIPPED=ghostty" "$(cat "$OUT")" "ghostty is recorded as skipped"

test_start "kitty_reloads_macos_app_bundle_with_sigusr1"
reset_calls
run_fn Darwin <<'EOF'
pgrep() { case "$*" in *'kitty\.app'*) echo 777 ;; *) return 1 ;; esac; }
kill() { printf '%s\n' "$*" >>"$CALLS/kill"; }
reload_kitty
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_equals "-SIGUSR1 777" "$(calls kill)" "each kitty process receives SIGUSR1 once"
assert_contains "SIGUSR1 config reload" "$(cat "$OUT")" "kitty reload is reported"
assert_contains "RELOADED=kitty" "$(cat "$OUT")" "kitty counts as reloaded"

test_start "kitty_skips_when_not_running"
reset_calls
run_fn Linux <<'EOF'
kill() { printf '%s\n' "$*" >>"$CALLS/kill"; }
reload_kitty
printf 'SKIPPED=%s\n' "${SKIPPED[*]:-}"
EOF
assert_equals "" "$(calls kill)" "no signal without a kitty process"
assert_contains "SKIPPED=kitty" "$(cat "$OUT")" "kitty is recorded as skipped"

test_start "tmux_sources_config_and_redraws_every_client"
reset_calls
mkdir -p "$XDG_CONFIG_HOME/tmux"
printf 'set -g status on\n' >"$XDG_CONFIG_HOME/tmux/tmux.conf"
run_fn Linux <<'EOF'
tmux() {
  printf '%s\n' "$*" >>"$CALLS/tmux"
  case "${1:-}" in list-clients) printf '/dev/ttys001\n/dev/ttys002\n' ;; esac
}
reload_tmux
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_contains "source-file $HOME/.config/tmux/tmux.conf" "$(calls tmux)" "generated config is sourced"
assert_contains "refresh-client -t /dev/ttys001 -S" "$(calls tmux)" "first attached client is redrawn"
assert_contains "refresh-client -t /dev/ttys002 -S" "$(calls tmux)" "second attached client is redrawn"
assert_contains "RELOADED=tmux" "$(cat "$OUT")" "tmux counts as reloaded"

test_start "niri_reloads_config_before_transition"
reset_calls
run_fn Linux <<'EOF'
niri() { printf '%s\n' "$*" >>"$CALLS/niri"; }
pgrep() { [[ "$*" == "-x niri" ]]; }
reload_niri
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_equals "msg action load-config-file" "$(calls niri | head -1)" "config is reloaded first"
assert_equals "msg action do-screen-transition" "$(calls niri | sed -n 2p)" "screen transition follows"
assert_contains "config reloaded + transition" "$(cat "$OUT")" "niri reload is reported"

test_start "macos_desktop_applies_appearance_and_theme_accent"
reset_calls
run_fn Darwin <<'EOF'
uname() { echo Darwin; }
osascript() { printf '%s\n' "$*" >>"$CALLS/osascript"; }
defaults() { printf '%s\n' "$*" >>"$CALLS/defaults"; }
killall() { :; }
reload_desktop fixture-light
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_contains "set dark mode to false" "$(calls osascript)" "light theme turns dark mode off"
assert_contains "write -g AppleAccentColor -int 2" "$(calls defaults)" "accent comes from the theme's macos_accent"
assert_contains "Yellow" "$(calls defaults)" "highlight colour matches the accent"
assert_contains "macOS light, accent 2" "$(cat "$OUT")" "desktop change is reported"
assert_contains "RELOADED=desktop" "$(cat "$OUT")" "desktop counts as reloaded"

test_start "macos_desktop_defaults_to_graphite_without_accent"
reset_calls
run_fn Darwin <<'EOF'
uname() { echo Darwin; }
osascript() { printf '%s\n' "$*" >>"$CALLS/osascript"; }
defaults() { printf '%s\n' "$*" >>"$CALLS/defaults"; }
killall() { :; }
reload_desktop bare-dark
EOF
assert_contains "write -g AppleAccentColor -int -1" "$(calls defaults)" "missing macos_accent falls back to Graphite"
assert_contains "Graphite" "$(calls defaults)" "highlight colour follows the Graphite fallback"
assert_contains "set dark mode to true" "$(calls osascript)" "dark theme requests dark mode"

test_start "linux_desktop_applies_gnome_settings_and_dms_dynamic_theme"
reset_home
reset_calls
host_linux=0
[[ "$(uname -s)" == Linux ]] && host_linux=1
if [[ "$host_linux" == 1 ]]; then
  # DMS is rewritten in place with the platform's `sed -i` form, which
  # only matches the host's sed when the host is Linux.
  mkdir -p "$XDG_CONFIG_HOME/DankMaterialShell" "$XDG_STATE_HOME/DankMaterialShell"
  printf '{"currentThemeName": "stock", "currentThemeCategory": "stock"}\n' >"$XDG_CONFIG_HOME/DankMaterialShell/settings.json"
  printf '{"themeModeAutoEnabled": false, "themeModeAutoMode": "manual", "isLightMode": false}\n' >"$XDG_STATE_HOME/DankMaterialShell/session.json"
  printf 'dms() { :; }\n' >"$WORK/dms-stub.sh"
else
  : >"$WORK/dms-stub.sh"
fi
EXTRA_ENV=(XDG_CURRENT_DESKTOP=GNOME)
run_fn Linux <<EOF
gsettings() { printf '%s\n' "\$*" >>"\$CALLS/gsettings"; }
source "$WORK/dms-stub.sh"
reload_desktop fixture-dark
printf 'RELOADED=%s\n' "\${RELOADED[*]:-}"
EOF
EXTRA_ENV=()
assert_contains "set org.gnome.desktop.interface color-scheme prefer-dark" "$(calls gsettings)" "dark theme prefers dark colour scheme"
assert_contains "set org.gnome.desktop.interface gtk-theme Adwaita-dark" "$(calls gsettings)" "GTK theme comes from the theme manifest"
assert_contains "set org.gnome.desktop.interface accent-color purple" "$(calls gsettings)" "macos_accent maps to the GNOME accent"
assert_contains "gnome: dark, Adwaita-dark" "$(cat "$OUT")" "desktop change is reported"
if [[ "$host_linux" == 1 ]]; then
  assert_file_contains "$XDG_CONFIG_HOME/DankMaterialShell/settings.json" '"currentThemeName": "dynamic"' \
    "DMS settings switch to the dynamic theme in place"
  assert_file_contains "$XDG_STATE_HOME/DankMaterialShell/session.json" '"themeModeAutoEnabled": true' \
    "DMS session keeps automatic light/dark mode"
else
  printf '  · DMS in-place rewrite assertions need a Linux host (sed -i form); skipped\n'
fi

test_start "linux_browsers_follow_desktop_scheme_and_firefox_profiles_sync"
reset_home
reset_calls
mkdir -p "$XDG_CONFIG_HOME/firefox" "$HOME/.mozilla/firefox/abc.default" "$HOME/.mozilla/firefox/xyz.dev"
printf 'user_pref("layout.css.prefers-color-scheme.content-override", 0);\n' >"$XDG_CONFIG_HOME/firefox/user.js"
cp "$XDG_CONFIG_HOME/firefox/user.js" "$HOME/.mozilla/firefox/abc.default/user.js"
run_fn Linux <<'EOF'
google-chrome() { :; }
microsoft-edge() { :; }
reload_browsers fixture-dark
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
assert_contains "dark via Chrome, Edge follow desktop color-scheme; Firefox content mode synced for 1 profile(s)" \
  "$(cat "$OUT")" "detected browsers and linked Firefox profiles are summarised"
assert_contains "RELOADED=browsers" "$(cat "$OUT")" "browsers count as reloaded"

test_start "browsers_skip_when_none_are_installed"
reset_home
reset_calls
run_fn Linux <<'EOF'
reload_browsers fixture-dark
printf 'SKIPPED=%s\n' "${SKIPPED[*]:-}"
EOF
assert_contains "no supported browsers detected" "$(cat "$OUT")" "absence is reported"
assert_contains "SKIPPED=browsers" "$(cat "$OUT")" "browsers are recorded as skipped"

# Neovim: the reload must work under macOS /bin/bash 3.2 as well as the
# test's bash; `reload_nvim` once used `local -A`, which 3.2 rejects and
# which silently dropped the reload.
nvim_sock="$WORK/run/nvim.4321.0"
python3 - "$nvim_sock" <<'PY'
import socket, sys
socket.socket(socket.AF_UNIX).bind(sys.argv[1])
PY
nvim_shells=("$REAL_BASH")
[[ -x /bin/bash && ! /bin/bash -ef "$REAL_BASH" ]] && nvim_shells+=(/bin/bash)
for shell in "${nvim_shells[@]}"; do
  test_start "nvim_switches_colorscheme_over_server_socket ($("$shell" -c 'echo "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'))"
  reset_calls
  run_fn Linux "$shell" <<'EOF'
nvim() { printf '%s\n' "$*" >>"$CALLS/nvim"; }
reload_nvim fixture-dark
printf 'RELOADED=%s\n' "${RELOADED[*]:-}"
EOF
  sock_calls="$(calls nvim | grep -c -- "--server $nvim_sock --remote-expr" || true)"
  assert_equals 1 "$sock_calls" "sandbox server socket is addressed exactly once"
  assert_contains "require('tokyonight').setup({style='night'})" "$(calls nvim)" "Lua switches to the theme's colourscheme"
  assert_contains "RELOADED=nvim" "$(cat "$OUT")" "nvim counts as reloaded"
done

# Every running Neovim gets the switch, each exactly once. With a second
# server in the runtime dir, a dedupe that compared the wrong way would
# keep only the first socket (or address one twice).
nvim_sock2="$WORK/run/nvim.8765.0"
python3 - "$nvim_sock2" <<'PY'
import socket, sys
socket.socket(socket.AF_UNIX).bind(sys.argv[1])
PY
for shell in "${nvim_shells[@]}"; do
  test_start "nvim_switches_every_server_once ($("$shell" -c 'echo "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'))"
  reset_calls
  run_fn Linux "$shell" <<'EOF'
nvim() { printf '%s\n' "$*" >>"$CALLS/nvim"; }
reload_nvim fixture-dark
EOF
  assert_equals 1 "$(calls nvim | grep -c -- "--server $nvim_sock --remote-expr" || true)" "first server addressed exactly once"
  assert_equals 1 "$(calls nvim | grep -c -- "--server $nvim_sock2 --remote-expr" || true)" "second server addressed exactly once"
  assert_equals 2 "$(calls nvim | grep -c -- "--remote-expr" || true)" "no server is skipped or repeated"
done
rm -f "$nvim_sock2"

# ===========================================================================
# Rendered templates (real chezmoi renderer, fixture data)
# ===========================================================================
if [[ -n "$CHEZMOI_BIN" ]]; then
  test_start "terminal_palettes_render_opaque_with_theme_colours"
  render_template "$DEFAULTS/dot_config/kitty/kitty.conf.tmpl" linux fixture-dark "$RENDER/kitty.conf"
  assert_equals 0 $? "kitty template renders: $(cat "$RENDER/kitty.conf.err")"
  assert_file_contains "$RENDER/kitty.conf" 'background_opacity 1.0' "Kitty stays opaque"
  assert_file_contains "$RENDER/kitty.conf" 'color4  #3d7bff' "Kitty blue comes from the theme"
  render_template "$DEFAULTS/dot_config/ghostty/config.tmpl" darwin fixture-dark "$RENDER/ghostty.conf"
  assert_equals 0 $? "ghostty template renders: $(cat "$RENDER/ghostty.conf.err")"
  assert_file_contains "$RENDER/ghostty.conf" 'background-opacity = 1.0' "Ghostty stays opaque"
  assert_file_contains "$RENDER/ghostty.conf" 'palette = 4=#3d7bff' "Ghostty blue comes from the theme"
  render_template "$DEFAULTS/dot_config/alacritty/alacritty.toml.tmpl" linux fixture-dark "$RENDER/alacritty.toml"
  assert_equals 0 $? "alacritty template renders: $(cat "$RENDER/alacritty.toml.err")"
  assert_file_contains "$RENDER/alacritty.toml" 'opacity = 1.0' "Alacritty stays opaque"
  assert_file_contains "$RENDER/alacritty.toml" 'blue = "#3d7bff"' "Alacritty blue comes from the theme"
  render_template "$DEFAULTS/dot_config/wezterm/wezterm.lua.tmpl" linux fixture-dark "$RENDER/wezterm.lua"
  assert_equals 0 $? "wezterm template renders: $(cat "$RENDER/wezterm.lua.err")"
  assert_file_contains "$RENDER/wezterm.lua" 'window_background_opacity = 1.0' "WezTerm stays opaque"
  assert_file_contains "$RENDER/wezterm.lua" '"#3d7bff"' "WezTerm blue comes from the theme"
  render_template "$DEFAULTS/dot_config/foot/foot.ini.tmpl" linux fixture-dark "$RENDER/foot.ini"
  assert_equals 0 $? "foot template renders: $(cat "$RENDER/foot.ini.err")"
  assert_file_contains "$RENDER/foot.ini" 'alpha=1.0' "Foot stays opaque"
  assert_file_contains "$RENDER/foot.ini" 'regular4=3d7bff' "Foot blue comes from the theme"

  test_start "starship_renders_wallpaper_palette_from_theme"
  render_template "$DEFAULTS/dot_config/starship.toml.tmpl" linux fixture-dark "$RENDER/starship.toml"
  assert_equals 0 $? "starship template renders: $(cat "$RENDER/starship.toml.err")"
  assert_file_contains "$RENDER/starship.toml" 'palette = "wallpaper"' "prompt selects the wallpaper palette"
  assert_file_contains "$RENDER/starship.toml" 'blue = "#3d7bff"' "prompt blue comes from the active theme"

  test_start "codex_renders_wallpaper_syntax_theme"
  render_template "$DEFAULTS/dot_codex/themes/dotfiles.tmTheme.tmpl" linux fixture-dark "$RENDER/dotfiles.tmTheme"
  assert_equals 0 $? "codex template renders: $(cat "$RENDER/dotfiles.tmTheme.err")"
  assert_file_contains "$RENDER/dotfiles.tmTheme" '<key>background</key><string>#101820</string>' \
    "Codex background comes from the theme"

  test_start "tmux_renders_ai_aware_minimal_status_from_theme"
  render_template "$DEFAULTS/dot_config/tmux/tmux.conf.tmpl" linux fixture-dark "$RENDER/tmux-dark.conf"
  assert_equals 0 $? "tmux dark template renders: $(cat "$RENDER/tmux-dark.conf.err")"
  render_template "$DEFAULTS/dot_config/tmux/tmux.conf.tmpl" linux fixture-light "$RENDER/tmux-light.conf"
  assert_equals 0 $? "tmux light template renders: $(cat "$RENDER/tmux-light.conf.err")"
  assert_file_contains "$RENDER/tmux-dark.conf" 'set-environment -g COLORFGBG "15;0"' "dark panes inherit a dark appearance signal"
  assert_file_contains "$RENDER/tmux-light.conf" 'set-environment -g COLORFGBG "0;15"' "light panes inherit a light appearance signal"
  assert_file_contains "$RENDER/tmux-dark.conf" 'set -g focus-events on' "tmux receives terminal focus events"
  assert_file_contains "$RENDER/tmux-dark.conf" 'bind A display-menu -T "#[align=centre] AI CLI cockpit "' "prefix+A exposes the AI launcher"
  assert_file_contains "$RENDER/tmux-dark.conf" 'set -g @dot_session_colour "#ff8800"' "session colour is the theme accent"
  assert_file_contains "$RENDER/tmux-dark.conf" '#[fg=#{?client_prefix,#ff2255,#{@dot_session_colour}},bg=#1b2430,bold] #{?client_prefix,' \
    "session identity reacts to prefix state in the theme's error colour"
  assert_equals "1" "$(grep -c '#{?client_prefix,.* }#S ' "$RENDER/tmux-dark.conf")" \
    "session name is the primary left-side identity"
  assert_file_contains "$RENDER/tmux-dark.conf" 'set -g status-justify left' "session and windows form one compact group"
  assert_file_contains "$RENDER/tmux-dark.conf" ' #I:#W#F#{?window_zoomed_flag,' "current window shows native flags and zoom state"
  assert_file_contains "$RENDER/tmux-dark.conf" '#{?#{&&:#{==:#{@dot_status_show_system},on},#{e|>=:#{client_width},120}},#(~/.local/bin/tmux-status system)' \
    "system sample is user-configurable and disappears on narrow clients"

  test_start "macos_auto_theme_agent_renders_watch_and_if_auto"
  render_template "$PLIST_TEMPLATE" darwin fixture-dark "$RENDER/agent.plist"
  assert_equals 0 $? "LaunchAgent template renders: $(cat "$RENDER/agent.plist.err")"
  agent="$(
    python3 - "$RENDER/agent.plist" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
print(" ".join(d["ProgramArguments"]))
print(" ".join(d["WatchPaths"]))
print(d["EnvironmentVariables"]["PATH"])
PY
  )"
  assert_equals "/DOT_HOME/.local/bin/dot theme sync --if-auto" "$(printf '%s\n' "$agent" | sed -n 1p)" \
    "agent runs a sync that respects manual mode"
  assert_equals "/DOT_HOME/Library/Preferences/.GlobalPreferences.plist" "$(printf '%s\n' "$agent" | sed -n 2p)" \
    "agent watches the macOS appearance preference file"
  assert_contains "/opt/homebrew/bin" "$(printf '%s\n' "$agent" | sed -n 3p)" "agent exposes Homebrew tools under launchd"

  test_start "macos_auto_theme_installer_bootstraps_launchagent"
  render_template "$INSTALLER_TEMPLATE" darwin fixture-dark "$RENDER/install-agent.sh"
  assert_equals 0 $? "installer template renders: $(cat "$RENDER/install-agent.sh.err")"
  reset_calls
  command env -i HOME="$HOME" PATH="$STUBS/launchctl:$TOOLS" CALLS="$CALLS" \
    "$REAL_BASH" "$RENDER/install-agent.sh" >"$OUT" 2>"$ERR"
  assert_equals 0 $? "installer exits 0"
  agent_plist="$HOME/Library/LaunchAgents/com.sebastienrousseau.dot-theme-auto.plist"
  assert_contains "bootstrap gui/$(id -u) $agent_plist" "$(calls launchctl)" "agent is bootstrapped into the GUI domain"
  assert_contains "enable gui/$(id -u)/com.sebastienrousseau.dot-theme-auto" "$(calls launchctl)" "agent is enabled"
  assert_dir_exists "$HOME/Library/Logs" "agent log directory is created"
  reset_calls
  command env -i HOME="$HOME" PATH="$STUBS/launchctl:$TOOLS" CALLS="$CALLS" FAKE_LAUNCHCTL_FAIL=1 \
    "$REAL_BASH" "$RENDER/install-agent.sh" >"$OUT" 2>"$ERR"
  assert_equals 0 $? "a failed bootstrap does not fail chezmoi apply"
  assert_contains "could not bootstrap" "$(cat "$ERR")" "bootstrap failure is warned about"
  render_template "$INSTALLER_TEMPLATE" linux fixture-dark "$RENDER/install-agent-linux.sh"
  assert_equals no "$(has launchctl "$(cat "$RENDER/install-agent-linux.sh")")" "installer is inert outside macOS"
else
  printf '  · chezmoi not installed: rendered-template cases skipped\n'
fi

# ===========================================================================
# tmux helpers
# ===========================================================================
test_start "tmux_helpers_label_context_and_ai_sessions"
assert_file_exists "$TMUX_AI" "AI-aware tmux helper must exist"
assert_file_exists "$TMUX_STATUS" "multi-session tmux helper must exist"
assert_equals "Code/project" "$(bash "$TMUX_STATUS" short-path /Users/seb/Code/project)" \
  "working directory context must stay compact"
assert_equals "AI:CODEX" "$(bash "$TMUX_AI" status codex 0)" \
  "Codex sessions receive an explicit provider badge"
assert_equals "AI:CLAUDE" "$(bash "$TMUX_AI" status claude 0)" \
  "Claude sessions receive an explicit provider badge"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
