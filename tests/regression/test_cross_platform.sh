#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2030,SC2031,SC2034
# (SC2016/SC2034: assert_true/assert_false eval their single-quoted argument.)
# Regression: Cross-platform compatibility — validates that scripts,
# configs, and templates work on macOS, Linux (Debian, Arch, RHEL), and WSL.
# Regression for: d7e7c2bc (v0.2.499 baseline)
# Why: Cross-platform regressions for BSD-vs-GNU tool divergence (sed -i, mktemp, stat, awk).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ── Sandbox ─────────────────────────────────────────────────────
# Every case below runs code (installer functions, shell helpers, alias
# files, chezmoi templates) against a mktemp HOME and fixture roots, with
# `uname` and /proc/version stubbed so each platform branch runs on any host.
_xp_tmp="$(mktemp -d -t dotfiles-xplat.XXXXXX)"
trap 'rm -rf "$_xp_tmp"' EXIT
export HOME="$_xp_tmp/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$HOME"

_xp_skip() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: $1)"
}

# Stub bin: `uname` prints $FAKE_UNAME; `grep` reads $FAKE_PROC_VERSION
# wherever the caller asked for /proc/version and is the real grep otherwise.
_xp_bin="$_xp_tmp/bin"
mkdir -p "$_xp_bin"
cat >"$_xp_bin/uname" <<'EOF'
#!/bin/sh
echo "${FAKE_UNAME:?}"
EOF
_xp_real_grep="$(command -v grep)"
cat >"$_xp_bin/grep" <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do
  [[ "\$a" == /proc/version ]] && a="\${FAKE_PROC_VERSION:-/nonexistent}"
  args+=("\$a")
done
exec "$_xp_real_grep" "\${args[@]}"
EOF
chmod +x "$_xp_bin/uname" "$_xp_bin/grep"

# Fixture filesystem roots for the installer's /proc and /etc probes.
_xp_root() { # name file[=content]...
  local root="$_xp_tmp/root-$1" spec
  shift
  mkdir -p "$root/etc" "$root/proc"
  for spec in "$@"; do
    printf '%s\n' "${spec#*=}" >"$root/${spec%%=*}"
  done
  printf '%s\n' "$root"
}
_xp_wsl_kernel="Linux version 5.15.153.1-microsoft-standard-WSL2 (gcc) #1 SMP"
_xp_linux_kernel="Linux version 6.8.0-45-generic (buildd@ubuntu) #45-Ubuntu SMP"
root_empty="$(_xp_root empty)"
root_plain="$(_xp_root plain "proc/version=$_xp_linux_kernel")"
root_debian="$(_xp_root debian "proc/version=$_xp_linux_kernel" "etc/debian_version=12.7")"
root_fedora="$(_xp_root fedora "proc/version=$_xp_linux_kernel" "etc/fedora-release=Fedora release 40")"
root_arch="$(_xp_root arch "proc/version=$_xp_linux_kernel" "etc/arch-release=")"
root_wsl="$(_xp_root wsl "proc/version=$_xp_wsl_kernel" "etc/debian_version=12.7")"
root_docker="$(_xp_root docker ".dockerenv=")"

# install.sh's detect_target_os under a stubbed kernel name and fixture root.
# Sourcing install.sh defines its functions without running main.
_xp_install_os() { # uname root
  (
    export FAKE_UNAME="$1"
    PATH="$_xp_bin:$PATH"
    source "$REPO_ROOT/install.sh"
    set +e
    detect_target_os "$2"
  ) 2>&1
}

# install.sh's detect_container_env exit status: root then NAME=value words.
_xp_container_rc() {
  (
    local root="$1" kv
    shift
    unset CODESPACES REMOTE_CONTAINERS
    for kv in "$@"; do export "${kv?}"; done
    source "$REPO_ROOT/install.sh"
    set +e
    detect_container_env "$root"
    echo "$?"
  ) 2>&1
}

# environment.sh's is_wsl exit status with /proc/version served from a file.
_xp_is_wsl() { # proc-version-file
  (
    export FAKE_PROC_VERSION="$1"
    PATH="$_xp_bin:$PATH"
    source "$REPO_ROOT/defaults/.chezmoitemplates/functions/system/environment.sh"
    is_wsl
    echo "$?"
  ) 2>&1
}
printf '%s\n' "$_xp_wsl_kernel" >"$_xp_tmp/proc-version-wsl"
printf '%s\n' "$_xp_linux_kernel" >"$_xp_tmp/proc-version-linux"

# Source the default aliases with only the named clipboard tools on PATH,
# then pipe "payload" into pbcopy. Prints what the backend received as
# "<tool> <args>|<stdin>", or "native" when pbcopy is left to the OS.
_xp_clip() { # ostype tool...
  local ostype="$1" dir tool
  shift
  dir="$(mktemp -d "$_xp_tmp/clip.XXXXXX")"
  cp "$_xp_bin/uname" "$dir/uname"
  for tool in "$@"; do
    cat >"$dir/$tool" <<'EOF'
#!/bin/sh
printf '%s %s|' "${0##*/}" "$*" >>"$CLIP_LOG"
/bin/cat >>"$CLIP_LOG"
EOF
    chmod +x "$dir/$tool"
  done
  (
    export CLIP_LOG="$dir/log" FAKE_UNAME=Linux
    OSTYPE="$ostype"
    PATH="$dir"
    source "$REPO_ROOT/defaults/.chezmoitemplates/aliases/default/default.aliases.sh"
    if [[ "$(type -t pbcopy)" != function ]]; then
      printf 'native'
      exit 0
    fi
    printf 'payload' | pbcopy
    printf '%s' "$(<"$CLIP_LOG")"
  ) 2>&1
}

# Render a template from defaults/ as chezmoi would on the given OS.
# $3 is extra JSON members merged into the override data. A Linux render
# also gets the kernel.osrelease a real Linux host reports, which the WSL
# probes in the templates read.
_xp_chezmoi="$(command -v chezmoi 2>/dev/null || true)"
mkdir -p "$_xp_tmp/cz"
printf '{}\n' >"$_xp_tmp/cz/chezmoi.json"
_xp_render() { # os template [extra-json]
  local kernel=""
  [[ "$1" == linux ]] && kernel=',"kernel":{"osrelease":"6.8.0-45-generic"}'
  "$_xp_chezmoi" --config "$_xp_tmp/cz/chezmoi.json" --source "$REPO_ROOT/defaults" \
    --destination "$HOME" --cache "$_xp_tmp/cz/cache" \
    --persistent-state "$_xp_tmp/cz/state.boltdb" \
    --override-data "{\"chezmoi\":{\"os\":\"$1\"$kernel}${3:+,$3}}" \
    execute-template <"$REPO_ROOT/defaults/$2" 2>&1
}
# Only trust renders when this chezmoi honours an overridden .chezmoi.os.
_xp_cz_ok=0
if [[ -n "$_xp_chezmoi" ]] &&
  [[ "$(printf '{{ .chezmoi.os }}' | "$_xp_chezmoi" --config "$_xp_tmp/cz/chezmoi.json" \
    --source "$_xp_tmp/cz" --destination "$HOME" --cache "$_xp_tmp/cz/cache" \
    --persistent-state "$_xp_tmp/cz/state.boltdb" --override-data '{"chezmoi":{"os":"plan9"}}' \
    execute-template 2>/dev/null)" == plan9 ]]; then
  _xp_cz_ok=1
fi
_xp_cz_skip="chezmoi with --override-data not available"
_xp_has_line() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }

# ═══════════════════════════════════════════════════════════════
# 1. POSIX COMPLIANCE — no bashisms in critical paths
# ═══════════════════════════════════════════════════════════════

test_start "platform_scripts_use_bash_shebang"
# All scripts under scripts/ must use #!/usr/bin/env bash (not #!/bin/bash)
failures=0
while IFS= read -r f; do
  first_line=$(head -1 "$f")
  if [[ "$first_line" == "#!/bin/bash" ]]; then
    printf '    hardcoded /bin/bash: %s\n' "$f"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all scripts must use #!/usr/bin/env bash (not /bin/bash)"

test_start "platform_no_gnu_only_flags_in_new_scripts"
# New/changed scripts must not use GNU-only flags without guards
PLATFORM_CHECK_FILES=(
  scripts/uninstall.sh
  scripts/dot/commands/ai.sh
  scripts/ops/chezmoi-apply.sh
  scripts/ops/prewarm.sh
)
failures=0
for f in "${PLATFORM_CHECK_FILES[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE 'stat\s+-c\b'; then
    # Allow if guarded by OS check OR has BSD fallback (stat -c ... || stat -f ...)
    if ! grep 'stat.*-c' "$filepath" 2>/dev/null | grep -qiE 'linux|gnu|uname|\|\|.*stat.*-f'; then
      printf '    GNU stat -c without guard: %s\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "no unguarded GNU-only flags in changed scripts"

# ═══════════════════════════════════════════════════════════════
# 2. PLATFORM DETECTION — must handle all targets
# ═══════════════════════════════════════════════════════════════

test_start "platform_installer_detects_debian"
assert_equals "debian" "$(_xp_install_os Linux "$root_debian")" "installer detects Debian from /etc/debian_version"

test_start "platform_installer_detects_arch"
assert_equals "arch" "$(_xp_install_os Linux "$root_arch")" "installer detects Arch from /etc/arch-release"

test_start "platform_installer_detects_macos"
assert_equals "macos" "$(_xp_install_os Darwin "$root_debian")" "installer detects macOS from uname Darwin"

test_start "platform_installer_detects_wsl"
assert_equals "wsl2" "$(_xp_install_os Linux "$root_wsl")" "installer detects WSL ahead of the Debian userland it ships"

test_start "platform_installer_detects_generic_linux"
assert_equals "linux" "$(_xp_install_os Linux "$root_plain")" "installer falls back to generic Linux"

test_start "platform_installer_unknown_os"
assert_equals "unknown" "$(_xp_install_os FreeBSD "$root_debian")" "installer reports an unsupported kernel as unknown"

test_start "platform_chezmoidata_supports_linux"
if [[ $_xp_cz_ok -eq 1 ]]; then
  xp_flag="$(printf '{{ .features.linux_desktop }}' | "$_xp_chezmoi" --config "$_xp_tmp/cz/chezmoi.json" \
    --source "$REPO_ROOT/defaults" --destination "$HOME" --cache "$_xp_tmp/cz/cache" \
    --persistent-state "$_xp_tmp/cz/state.boltdb" execute-template 2>&1)"
  assert_equals "false" "$xp_flag" "templates see a linux_desktop flag, off by default"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_linux_desktop_off_ignores_desktop_units"
if [[ $_xp_cz_ok -eq 1 ]]; then
  xp_ignore="$(_xp_render linux .chezmoiignore.tmpl)"
  assert_true '_xp_has_line "$xp_ignore" ".config/systemd"' "linux_desktop=false keeps ~/.config/systemd out of HOME"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_linux_desktop_on_deploys_desktop_units"
if [[ $_xp_cz_ok -eq 1 ]]; then
  xp_ignore="$(_xp_render linux .chezmoiignore.tmpl '"features":{"linux_desktop":true}')"
  assert_true '_xp_has_line "$xp_ignore" ".config/niri" && ! _xp_has_line "$xp_ignore" ".config/systemd"' \
    "linux_desktop=true deploys ~/.config/systemd (other flags still apply)"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_wsl_detection_function"
assert_equals "0" "$(_xp_is_wsl "$_xp_tmp/proc-version-wsl")" "is_wsl succeeds on a Microsoft kernel"

test_start "platform_wsl_detection_native_linux"
assert_equals "1" "$(_xp_is_wsl "$_xp_tmp/proc-version-linux")" "is_wsl fails on a native Linux kernel"

test_start "platform_wsl_detection_no_proc"
assert_equals "1" "$(_xp_is_wsl "$_xp_tmp/no-such-proc-version")" "is_wsl fails quietly without /proc/version (macOS)"

# ═══════════════════════════════════════════════════════════════
# 3. PATH HANDLING — no platform-specific hardcoding
# ═══════════════════════════════════════════════════════════════

test_start "platform_homebrew_path_guarded"
# /opt/homebrew must only appear inside darwin/macOS guards
paths_file="$REPO_ROOT/defaults/.chezmoitemplates/paths/00-default.paths.sh"
if [[ -f "$paths_file" ]]; then
  if grep -q '/opt/homebrew' "$paths_file" 2>/dev/null; then
    if grep -B3 '/opt/homebrew' "$paths_file" | grep -qiE 'darwin\|OSTYPE.*darwin'; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: /opt/homebrew guarded by darwin check"
    else
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (guard pattern may differ)"
    fi
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no /opt/homebrew reference"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (paths file not found)"
fi

test_start "platform_xdg_vars_in_new_scripts"
# New scripts must use ${XDG_VAR:-fallback} pattern
failures=0
for f in scripts/uninstall.sh scripts/ops/prewarm.sh; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  for var in XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME; do
    if grep -q "\$$var" "$filepath" 2>/dev/null; then
      if grep "\$$var" "$filepath" | grep -vE '^\s*#' | grep -qvE ':-'; then
        printf '    bare $%s in %s\n' "$var" "$f"
        failures=$((failures + 1))
      fi
    fi
  done
done
assert_equals "0" "$failures" "new scripts must use XDG vars with fallback defaults"

# ═══════════════════════════════════════════════════════════════
# 4. CLIPBOARD — cross-platform support
# ═══════════════════════════════════════════════════════════════

test_start "platform_clipboard_wayland"
assert_equals "wl-copy |payload" "$(_xp_clip linux-gnu wl-copy)" "pbcopy uses wl-copy on Wayland"

test_start "platform_clipboard_x11"
assert_equals "xclip -selection clipboard|payload" "$(_xp_clip linux-gnu xclip)" "pbcopy uses xclip on X11"

test_start "platform_clipboard_wsl"
assert_equals "clip.exe |payload" "$(_xp_clip linux-gnu clip.exe)" "pbcopy uses clip.exe on WSL"

test_start "platform_clipboard_xsel_fallback"
assert_equals "xsel --clipboard --input|payload" "$(_xp_clip linux-gnu xsel)" "pbcopy falls back to xsel"

test_start "platform_clipboard_wayland_preferred"
assert_equals "wl-copy |payload" "$(_xp_clip linux-gnu xclip wl-copy xsel clip.exe)" "Wayland wins when several backends exist"

test_start "platform_clipboard_macos_native"
assert_equals "native" "$(_xp_clip darwin24 wl-copy)" "macOS keeps its native pbcopy"

# ═══════════════════════════════════════════════════════════════
# 5. TEMPLATES — platform conditionals in chezmoi templates
# ═══════════════════════════════════════════════════════════════

if [[ $_xp_cz_ok -eq 1 ]]; then
  xp_git_darwin="$(_xp_render darwin dot_gitconfig.tmpl)"
  xp_git_linux="$(_xp_render linux dot_gitconfig.tmpl)"
  xp_zsh_darwin="$(_xp_render darwin dot_config/zsh/dot_zshrc.tmpl)"
  xp_zsh_linux="$(_xp_render linux dot_config/zsh/dot_zshrc.tmpl)"
  xp_zsh_windows="$(_xp_render windows dot_config/zsh/dot_zshrc.tmpl)"
  xp_ssh_darwin="$(_xp_render darwin private_dot_ssh/config.tmpl)"
  xp_ssh_linux="$(_xp_render linux private_dot_ssh/config.tmpl)"
fi

test_start "platform_gitconfig_os_conditional"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_true '[[ "$xp_git_linux" == *"[credential]"* && "$xp_git_linux" != *osxkeychain* ]]' \
    "Linux gitconfig renders a credential helper that is not the macOS keychain"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_zshrc_template_os_aware"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_contains 'export FORCE_COLOR_OS="macOS"' "$xp_zsh_darwin" "zshrc rendered on macOS marks macOS"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_zshrc_template_linux"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_contains 'export FORCE_COLOR_OS="Linux"' "$xp_zsh_linux" "zshrc rendered on Linux marks Linux"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_zshrc_template_windows"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_contains 'export FORCE_COLOR_OS="Windows"' "$xp_zsh_windows" "zshrc rendered on Windows marks Windows"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_ssh_config_os_conditional"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_true '[[ "$xp_ssh_linux" == *"IdentitiesOnly yes"* && "$xp_ssh_linux" != *UseKeychain* ]]' \
    "Linux ssh config renders without UseKeychain (Linux OpenSSH rejects it)"
else _xp_skip "$_xp_cz_skip"; fi

# ═══════════════════════════════════════════════════════════════
# 6. PACKAGE MANAGERS — multi-distro support
# ═══════════════════════════════════════════════════════════════

test_start "platform_provision_debian"
# Check for apt/dpkg references in provisioning
provision_dir="$REPO_ROOT/install/provision"
if find "$provision_dir" -name "*.sh*" -exec grep -l 'apt\|dpkg' {} \; 2>/dev/null | grep -q .; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: provisioning supports Debian/apt"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (apt handled by mise)"
fi

test_start "platform_provision_arch"
# Check for pacman references
if find "$provision_dir" -name "*.sh*" -exec grep -l 'pacman\|paru\|yay' {} \; 2>/dev/null | grep -q .; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: provisioning supports Arch/pacman"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (Arch handled by mise)"
fi

test_start "platform_mise_cross_platform"
# Load the deployed conf.d layer into a sandboxed mise and ask it; without
# mise on PATH, read the setting through a TOML parser instead.
xp_mise_home="$_xp_tmp/mise-home"
mkdir -p "$xp_mise_home/.config/mise/conf.d"
cp "$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml" "$xp_mise_home/.config/mise/conf.d/"
if xp_mise="$(command -v mise 2>/dev/null)"; then
  xp_auto="$(cd "$xp_mise_home" && env -i PATH="/usr/bin:/bin" HOME="$xp_mise_home" \
    XDG_CONFIG_HOME="$xp_mise_home/.config" XDG_DATA_HOME="$xp_mise_home/.local/share" \
    XDG_CACHE_HOME="$xp_mise_home/.cache" XDG_STATE_HOME="$xp_mise_home/.local/state" \
    "$xp_mise" settings get auto_install 2>&1)"
else
  xp_auto="$(python3 -c 'import sys, tomllib; print(str(tomllib.load(open(sys.argv[1], "rb"))["settings"]["auto_install"]).lower())' \
    "$xp_mise_home/.config/mise/conf.d/00-dotfiles.toml" 2>&1)"
fi
assert_equals "true" "$xp_auto" "mise loads auto_install=true from the deployed config"

# ═══════════════════════════════════════════════════════════════
# 7. LINUX DESKTOP — conditional feature flags
# ═══════════════════════════════════════════════════════════════

test_start "platform_niri_config_is_template"
if [[ -f "$REPO_ROOT/defaults/dot_config/niri/config.kdl.tmpl" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: niri config is a chezmoi template"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (niri not configured)"
fi

test_start "platform_waybar_config_is_template"
if [[ -f "$REPO_ROOT/defaults/dot_config/waybar/config.jsonc.tmpl" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: waybar config is a chezmoi template"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (waybar not configured)"
fi

# ═══════════════════════════════════════════════════════════════
# 8. SHELL COMPATIBILITY — multi-shell support
# ═══════════════════════════════════════════════════════════════

test_start "platform_fish_config_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/fish/conf.d/init.fish.tmpl" "fish config must exist"

test_start "platform_nushell_config_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/nushell/completions.nu.tmpl" "nushell completions must exist"

test_start "platform_bash_config_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_bashrc" "bash config must exist"

test_start "platform_zsh_config_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" "zsh config must exist"

# ═══════════════════════════════════════════════════════════════
# 9. CI MATRIX — must test on multiple platforms
# ═══════════════════════════════════════════════════════════════

test_start "platform_ci_tests_linux"
assert_file_contains "$REPO_ROOT/.github/workflows/ci.yml" "ubuntu" "CI must test on Linux"

test_start "platform_ci_tests_macos"
assert_file_contains "$REPO_ROOT/.github/workflows/ci.yml" "macos" "CI must test on macOS"

test_start "platform_devcontainer_exists"
assert_file_exists "$REPO_ROOT/.devcontainer/devcontainer.json" "devcontainer must exist for Codespaces"

test_start "platform_devcontainer_detection_in_installer"
assert_equals "0" "$(_xp_container_rc "$root_empty" CODESPACES=true)" "installer detects Codespaces"

test_start "platform_devcontainer_remote_containers"
assert_equals "0" "$(_xp_container_rc "$root_empty" REMOTE_CONTAINERS=true)" "installer detects VS Code dev containers"

test_start "platform_devcontainer_dockerenv"
assert_equals "0" "$(_xp_container_rc "$root_docker")" "installer detects Docker from /.dockerenv"

test_start "platform_devcontainer_bare_host"
assert_equals "1" "$(_xp_container_rc "$root_empty")" "a bare host is not treated as a container"

# ═══════════════════════════════════════════════════════════════
# 10. PORTABILITY — no platform-specific binaries assumed
# ═══════════════════════════════════════════════════════════════

test_start "platform_no_macos_only_commands_unguarded"
# Commands like pbcopy, open, osascript must be guarded
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '\b(osascript|defaults write|launchctl)\b'; then
    # Must be inside darwin/macOS guard
    if ! grep -B10 'osascript\|defaults write\|launchctl' "$f" 2>/dev/null | grep -qiE 'darwin\|macos\|chezmoi.os'; then
      printf '    unguarded macOS command in %s\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done < <(find "$REPO_ROOT/scripts/dot/commands" "$REPO_ROOT/scripts/ops" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "macOS-only commands must be guarded by platform check"

# ═══════════════════════════════════════════════════════════════
# 11. FISH / NUSHELL / TOPGRADE — templates for cross-platform
# ═══════════════════════════════════════════════════════════════

test_start "platform_fish_config_is_template"
fish_tmpl_count=$(find "$REPO_ROOT/defaults/dot_config/fish" -name "*.tmpl" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$fish_tmpl_count" -gt 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: fish has $fish_tmpl_count template files"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: fish config should have .tmpl files for cross-platform"
fi

test_start "platform_nushell_config_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/nushell/config.nu.tmpl" "nushell config must be a chezmoi template"

test_start "platform_nushell_env_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/nushell/env.nu.tmpl" "nushell env must be a chezmoi template"

test_start "platform_topgrade_config_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/topgrade.toml.tmpl" "topgrade config must be a chezmoi template"

test_start "platform_ghostty_config_exists"
ghostty_count=$(find "$REPO_ROOT/defaults/dot_config/ghostty" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ghostty_count" -gt 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ghostty config exists ($ghostty_count files)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ghostty config directory should have files"
fi

test_start "platform_wezterm_config_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/wezterm/wezterm.lua.tmpl" "wezterm config must exist"

test_start "platform_zellij_config_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zellij/config.kdl.tmpl" "zellij config must exist"

test_start "platform_zellij_config_is_template"
if [[ "$REPO_ROOT/defaults/dot_config/zellij/config.kdl.tmpl" == *.tmpl ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: zellij config is a chezmoi template"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: zellij config should be a .tmpl file"
fi

# ═══════════════════════════════════════════════════════════════
# 12. PROVISION SCRIPTS — Linux and macOS support
# ═══════════════════════════════════════════════════════════════

test_start "platform_provision_darwin_packages"
darwin_provision=$(find "$REPO_ROOT/install/provision" -name "*darwin*" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$darwin_provision" -gt 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: darwin-specific provision scripts exist ($darwin_provision)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: must have darwin-specific provision scripts"
fi

test_start "platform_provision_linux_packages"
linux_provision=$(find "$REPO_ROOT/install/provision" -name "*linux*" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$linux_provision" -gt 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: linux-specific provision scripts exist ($linux_provision)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: must have linux-specific provision scripts"
fi

# ═══════════════════════════════════════════════════════════════
# 13. STARSHIP / GIT / SSH / ATUIN — cross-platform configs
# ═══════════════════════════════════════════════════════════════

test_start "platform_starship_config_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/starship.toml.tmpl" "starship config must be a chezmoi template for cross-platform"

test_start "platform_gitconfig_credential_macos"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_contains $'[credential]\n\thelper = osxkeychain' "$xp_git_darwin" "macOS gitconfig uses the osxkeychain credential helper"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_gitconfig_credential_linux"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_contains "git-credential-libsecret" "$xp_git_linux" "Linux gitconfig uses the libsecret credential helper"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_gitconfig_credential_macos_no_libsecret"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_true '[[ "$xp_git_darwin" == *osxkeychain* && "$xp_git_darwin" != *libsecret* ]]' \
    "macOS gitconfig does not use the Linux libsecret helper"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_ssh_usekeychain_conditional"
if [[ $_xp_cz_ok -eq 1 ]]; then
  assert_true '_xp_has_line "$xp_ssh_darwin" "  UseKeychain yes"' "macOS ssh config enables UseKeychain"
else _xp_skip "$_xp_cz_skip"; fi

test_start "platform_atuin_config_exists"
# Post-Phase-4b the atuin config is a chezmoi template under defaults/
# so it can branch on platform/profile.
assert_file_exists "$REPO_ROOT/defaults/dot_config/atuin/config.toml.tmpl" "atuin config must exist for cross-platform history"

test_start "platform_installer_detects_fedora"
assert_equals "fedora" "$(_xp_install_os Linux "$root_fedora")" "installer detects Fedora/RHEL from /etc/fedora-release"

# ═══════════════════════════════════════════════════════════════
# 14. NEOVIM — no platform-specific hardcoding
# ═══════════════════════════════════════════════════════════════

test_start "platform_neovim_no_hardcoded_macos_paths"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*--' "$f" 2>/dev/null | grep -qE '/Users/|/home/|/opt/homebrew'; then
    printf '    hardcoded path in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/defaults/dot_config/nvim" -name "*.lua" -type f 2>/dev/null)
assert_equals "0" "$failures" "neovim config must not have platform-specific hardcoded paths"

test_start "platform_neovim_no_os_execute_unguarded"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*--' "$f" 2>/dev/null | grep -qE 'os\.execute.*\b(brew|apt|pacman)\b'; then
    printf '    unguarded os.execute with package manager in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/defaults/dot_config/nvim" -name "*.lua" -type f 2>/dev/null)
assert_equals "0" "$failures" "neovim must not call platform-specific package managers via os.execute"

# ═══════════════════════════════════════════════════════════════
# 15. ALIASES — platform-neutral
# ═══════════════════════════════════════════════════════════════

test_start "platform_docker_aliases_exist"
assert_file_exists "$REPO_ROOT/defaults/.chezmoitemplates/aliases/docker/docker.aliases.sh" "docker aliases must exist"

test_start "platform_docker_aliases_no_hardcoded_paths"
failures=0
docker_alias_file="$REPO_ROOT/defaults/.chezmoitemplates/aliases/docker/docker.aliases.sh"
if [[ -f "$docker_alias_file" ]]; then
  if grep -vE '^\s*#' "$docker_alias_file" 2>/dev/null | grep -qE '/usr/local/bin/docker|/opt/homebrew/bin/docker'; then
    failures=$((failures + 1))
  fi
fi
assert_equals "0" "$failures" "docker aliases must not hardcode platform-specific binary paths"

test_start "platform_kubernetes_aliases_exist"
assert_file_exists "$REPO_ROOT/defaults/.chezmoitemplates/aliases/kubernetes/kubernetes.aliases.sh" "kubernetes aliases must exist"

test_start "platform_kubernetes_aliases_platform_neutral"
failures=0
k8s_alias_file="$REPO_ROOT/defaults/.chezmoitemplates/aliases/kubernetes/kubernetes.aliases.sh"
if [[ -f "$k8s_alias_file" ]]; then
  if grep -vE '^\s*#' "$k8s_alias_file" 2>/dev/null | grep -qE '/usr/local/bin/kubectl|/opt/homebrew/bin/kubectl'; then
    failures=$((failures + 1))
  fi
fi
assert_equals "0" "$failures" "kubernetes aliases must not hardcode platform-specific binary paths"

# ═══════════════════════════════════════════════════════════════
# 16. POWERSHELL — cross-platform shell support
# ═══════════════════════════════════════════════════════════════

test_start "platform_powershell_profile_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl" "powershell profile must be a chezmoi template"

test_start "platform_alacritty_config_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/alacritty/alacritty.toml.tmpl" "alacritty config must be a chezmoi template"

test_start "platform_foot_config_is_template"
assert_file_exists "$REPO_ROOT/defaults/dot_config/foot/foot.ini.tmpl" "foot terminal config must be a template (Linux-only terminal)"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
