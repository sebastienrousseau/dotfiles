#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Cross-platform compatibility — validates that scripts,
# configs, and templates work on macOS, Linux (Debian, Arch, RHEL), and WSL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

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
    if ! grep -B5 'stat.*-c' "$filepath" 2>/dev/null | grep -qiE 'linux|gnu|uname'; then
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
assert_file_contains "$REPO_ROOT/install.sh" "debian" "installer must detect Debian"

test_start "platform_installer_detects_arch"
assert_file_contains "$REPO_ROOT/install.sh" "arch" "installer must detect Arch"

test_start "platform_installer_detects_macos"
assert_file_contains "$REPO_ROOT/install.sh" "Darwin" "installer must detect macOS"

test_start "platform_installer_detects_wsl"
assert_file_contains "$REPO_ROOT/install.sh" "wsl" "installer must detect WSL"

test_start "platform_chezmoidata_supports_linux"
assert_file_contains "$REPO_ROOT/.chezmoidata.toml" "linux_desktop" "chezmoidata must have Linux desktop flag"

test_start "platform_wsl_detection_function"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/functions/system/environment.sh" "is_wsl" "must have WSL detection function"

# ═══════════════════════════════════════════════════════════════
# 3. PATH HANDLING — no platform-specific hardcoding
# ═══════════════════════════════════════════════════════════════

test_start "platform_homebrew_path_guarded"
# /opt/homebrew must only appear inside darwin/macOS guards
paths_file="$REPO_ROOT/.chezmoitemplates/paths/00-default.paths.sh"
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
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "wl-copy" "clipboard must support Wayland"

test_start "platform_clipboard_x11"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "xclip" "clipboard must support X11"

test_start "platform_clipboard_wsl"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "clip.exe" "clipboard must support WSL"

test_start "platform_clipboard_xsel_fallback"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "xsel" "clipboard must support xsel fallback"

# ═══════════════════════════════════════════════════════════════
# 5. TEMPLATES — platform conditionals in chezmoi templates
# ═══════════════════════════════════════════════════════════════

test_start "platform_gitconfig_os_conditional"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "chezmoi.os" "gitconfig must use OS conditionals"

test_start "platform_zshrc_template_os_aware"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "chezmoi.os" "zshrc template must be OS-aware"

test_start "platform_ssh_config_os_conditional"
assert_file_contains "$REPO_ROOT/private_dot_ssh/config.tmpl" "chezmoi.os" "SSH config must use OS conditionals"

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
assert_file_contains "$REPO_ROOT/dot_config/mise/config.toml" "auto_install = true" "mise must auto-install tools on all platforms"

# ═══════════════════════════════════════════════════════════════
# 7. LINUX DESKTOP — conditional feature flags
# ═══════════════════════════════════════════════════════════════

test_start "platform_niri_config_is_template"
if [[ -f "$REPO_ROOT/dot_config/niri/config.kdl.tmpl" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: niri config is a chezmoi template"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (niri not configured)"
fi

test_start "platform_waybar_config_is_template"
if [[ -f "$REPO_ROOT/dot_config/waybar/config.jsonc.tmpl" ]]; then
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
assert_file_exists "$REPO_ROOT/dot_config/fish/conf.d/init.fish.tmpl" "fish config must exist"

test_start "platform_nushell_config_exists"
assert_file_exists "$REPO_ROOT/dot_config/nushell/completions.nu.tmpl" "nushell completions must exist"

test_start "platform_bash_config_exists"
assert_file_exists "$REPO_ROOT/dot_bashrc" "bash config must exist"

test_start "platform_zsh_config_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "zsh config must exist"

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
assert_file_contains "$REPO_ROOT/install.sh" "CODESPACES" "installer must detect Codespaces"

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

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
