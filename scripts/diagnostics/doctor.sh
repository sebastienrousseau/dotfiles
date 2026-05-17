#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Dotfiles Doctor.
##
## Diagnoses dotfiles environment health by checking dependencies, paths,
## and configuration integrity. Reports errors, warnings, and suggests
## remediation steps.
##
## # Usage
## dot doctor
##
## # Exit Codes
## - 0: All checks passed (may have warnings)
## - 1: Critical errors detected
##
## # Idempotency
## Safe to run repeatedly. Read-only checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/platform.sh"
# shellcheck source=../dot/lib/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/log.sh"
export DOT_COMMAND="doctor"

ui_init

# Extend PATH to include common non-standard install locations
export PATH="$HOME/.atuin/bin:$HOME/.local/bin:$PATH"

Errors=0
Warnings=0
AI_DEBUG=0

for arg in "$@"; do
  case "$arg" in
    --ai) AI_DEBUG=1 ;;
  esac
done

# --- Output helpers (delegate to shared ui.sh) ---
_ok() { ui_ok "$1" "${2:-}"; }
_fail() {
  ui_err "$1" "${2:-}"
  Errors=$((Errors + 1))
}
_warn() {
  ui_warn "$1" "${2:-}"
  Warnings=$((Warnings + 1))
}
_section() {
  echo ""
  ui_section "$1"
}

pretty_path() {
  local value="${1:-}"
  if [[ -n "$value" ]]; then
    printf '%s' "${value/#$HOME/\~}"
  fi
}

tool_source() {
  local path="${1:-}"
  if [[ "$path" == "$HOME/.local/share/mise/"* ]]; then
    echo "mise"
  elif [[ "$path" == /usr/bin/* || "$path" == /bin/* || "$path" == /usr/sbin/* || "$path" == /sbin/* ]]; then
    echo "system"
  else
    echo "custom"
  fi
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then return 0; fi
  if command -v mise &>/dev/null; then
    if mise ls --installed 2>/dev/null | grep -qE "($cmd|aqua:.*$cmd)"; then
      return 0
    fi
  fi
  return 1
}

get_cmd_path() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    command -v "$cmd"
  elif command -v mise &>/dev/null; then
    local bin_path
    bin_path=$(mise bin-paths 2>/dev/null | grep -E "/$cmd(/|$)" | head -n 1)
    if [ -n "$bin_path" ]; then
      echo "$bin_path/$cmd"
    else
      echo "$cmd"
    fi
  else
    echo "$cmd"
  fi
}

# --- Header ---
ui_header "Dotfiles Doctor"

# --- Core Shells ---
_section "Core Shells"
for cmd in zsh fish starship; do
  if check_cmd "$cmd"; then
    cmd_path="$(get_cmd_path "$cmd")"
    _ok "$cmd" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
  elif [[ "$cmd" == "fish" ]]; then
    _warn "$cmd" "optional"
  else
    _fail "$cmd" "missing"
  fi
done

if check_cmd "nu"; then
  cmd_path="$(get_cmd_path "nu")"
  _ok "nu" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
elif check_cmd "nushell"; then
  cmd_path="$(get_cmd_path "nushell")"
  _ok "nu" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
else
  _warn "nu" "optional"
fi

# --- Modern CLI Tools ---
_section "Modern CLI Tools"
for cmd in rg bat chezmoi fzf zoxide atuin yazi zellij; do
  if check_cmd "$cmd"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
  elif [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "batcat")") (batcat)"
  else
    _fail "$cmd" "missing"
  fi
done

# --- Infrastructure ---
_section "Infrastructure"
for cmd in pueue wasmtime nix sops age hyperfine; do
  if check_cmd "$cmd"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
  elif [[ "$cmd" == "nix" ]]; then
    _ok "$cmd" "optional (not installed)"
  else
    _fail "$cmd" "missing"
  fi
done

if check_cmd pueue; then
  if "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
    _ok "pueue daemon" "running"
  elif command -v pueued >/dev/null 2>&1 && pueued -d >/dev/null 2>&1 && "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
    _ok "pueue daemon" "started"
  else
    _warn "pueue daemon" "not running (pueued -d)"
  fi
fi

# --- AI CLIs ---
_section "AI CLIs"
for cmd in claude copilot gemini sgpt ollama opencode aider kiro-cli; do
  if check_cmd "$cmd"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
  else
    _warn "$cmd" "optional"
  fi
done

# --- Environment ---
_section "Environment"
if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
  _ok "XDG_CONFIG_HOME" "$(pretty_path "$XDG_CONFIG_HOME")"
else
  _warn "XDG_CONFIG_HOME" "defaulting to ~/.config"
fi

# Validate XDG paths are absolute
for var in XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME; do
  val="${!var:-}"
  if [[ -n "$val" ]] && [[ "$val" != /* ]]; then
    _warn "$var" "not absolute: $val"
  fi
done

if [[ -n "${PIPX_HOME:-}" ]]; then
  _ok "PIPX_HOME" "$(pretty_path "$PIPX_HOME")"
else
  _warn "PIPX_HOME" "not set"
fi

# --- Platform ---
_section "Platform"

platform_id="$(dot_platform_id)"
_os_name="$(uname -s)"
_kernel="$(uname -sr)"
_arch="$(uname -m)"
_user="$(whoami 2>/dev/null || echo "${USER:-unknown}")"
_hostname_val="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "unknown")"

# Shell version
_shell_name="${SHELL##*/}"
_shell_ver="$("$SHELL" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
_shell="${_shell_name}${_shell_ver:+ $_shell_ver}"

# Terminal
_terminal="${TERM_PROGRAM:-${TERM:-unknown}}"

# Uptime (portable)
if uptime -p >/dev/null 2>&1; then
  _uptime="$(uptime -p 2>/dev/null | sed 's/^up //')"
else
  _uptime="$(uptime 2>/dev/null | sed -E 's/^.* up ([^,]+(, [^,]+){0,2}), [0-9]+ users?.*$/\1/' || true)"
fi

# --- OS-specific detection ---
_os="" _host="" _cpu="" _cpu_cores="" _gpu="" _mem="" _resolution="" _packages="" _de=""

if [[ "$_os_name" == "Darwin" ]]; then
  # macOS
  _os="macOS $(sw_vers -productVersion 2>/dev/null || echo "unknown")"
  _host="$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2}' || sysctl -n hw.model 2>/dev/null || echo "Mac")"
  _cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "$_arch")"
  _cpu_cores="$(sysctl -n hw.ncpu 2>/dev/null || echo "?")"
  _gpu="$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model|Chip/{print $2; exit}' || echo "n/a")"
  _mem_total="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
  _mem_total_gb="$(awk "BEGIN{printf \"%.2f\", ${_mem_total}/1073741824}")"
  _mem_pages="$(vm_stat 2>/dev/null | awk '/Pages active/{gsub(/\./,"",$3); print $3}')"
  _mem_used_gb="$(awk "BEGIN{printf \"%.2f\", ${_mem_pages:-0}*4096/1073741824}")"
  _mem="${_mem_used_gb} GiB / ${_mem_total_gb} GiB"
  _resolution="$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Resolution/{gsub(/^ +/,""); print; exit}' | sed 's/Resolution: //' || echo "n/a")"
  _packages="$(brew list --formula 2>/dev/null | wc -l | tr -d ' ') (brew)"
  _de="Aqua"

elif [[ -r /etc/os-release ]]; then
  # Linux (Debian, Ubuntu, Arch, Fedora, RHEL, etc.)
  # shellcheck disable=SC1091
  . /etc/os-release
  _os="${PRETTY_NAME:-$ID}"

  _host="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || cat /sys/firmware/devicetree/base/model 2>/dev/null || echo "Linux")"

  if command -v lscpu >/dev/null 2>&1; then
    _cpu="$(lscpu | awk -F': +' '/Model name/{print $2}')"
    _cpu_cores="$(lscpu | awk -F': +' '/^CPU\(s\):/{print $2}')"
  else
    _cpu="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || uname -p)"
    _cpu_cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")"
  fi

  if command -v lspci >/dev/null 2>&1; then
    _gpu="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //')"
  else
    _gpu="n/a"
  fi

  if command -v free >/dev/null 2>&1; then
    _mem="$(free -b | awk '/Mem:/{printf "%.2f GiB / %.2f GiB", $3/1073741824, $2/1073741824}')"
  elif [[ -r /proc/meminfo ]]; then
    _mem_total_kb="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
    _mem_avail_kb="$(awk '/MemAvailable/{print $2}' /proc/meminfo)"
    _mem_used_kb=$((_mem_total_kb - _mem_avail_kb))
    _mem="$(awk "BEGIN{printf \"%.2f GiB / %.2f GiB\", ${_mem_used_kb}/1048576, ${_mem_total_kb}/1048576}")"
  else
    _mem="n/a"
  fi

  # Resolution (Wayland or X11)
  if command -v wlr-randr >/dev/null 2>&1; then
    _resolution="$(wlr-randr 2>/dev/null | awk '/current/{print $1; exit}' || echo "n/a")"
  elif command -v xrandr >/dev/null 2>&1; then
    _resolution="$(xrandr 2>/dev/null | awk '/\*/{print $1; exit}' || echo "n/a")"
  elif command -v xdpyinfo >/dev/null 2>&1; then
    _resolution="$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2}' || echo "n/a")"
  else
    _resolution="n/a"
  fi

  # Packages (multi-distro)
  _pkg_count=0
  _pkg_mgr="pkg"
  if command -v dpkg >/dev/null 2>&1; then
    _pkg_count="$(dpkg --get-selections 2>/dev/null | wc -l | tr -d ' ')"
    _pkg_mgr="dpkg"
  elif command -v rpm >/dev/null 2>&1; then
    _pkg_count="$(rpm -qa 2>/dev/null | wc -l | tr -d ' ')"
    _pkg_mgr="rpm"
  elif command -v pacman >/dev/null 2>&1; then
    _pkg_count="$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')"
    _pkg_mgr="pacman"
  fi
  _packages="${_pkg_count} (${_pkg_mgr})"

  _de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-n/a}}"

else
  # Fallback (unknown OS)
  _os="$(uname -sr)"
  _host="unknown"
  _cpu="$(uname -p 2>/dev/null || echo "unknown")"
  _cpu_cores="?"
  _gpu="n/a"
  _mem="n/a"
  _resolution="n/a"
  _packages="n/a"
  _de="n/a"
fi

# WSL detection and overrides
_wsl=""
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
  _wsl="yes"
  _os="${_os} (WSL)"
  _de="Windows Desktop (WSL)"
  _terminal="${TERM_PROGRAM:-Windows Terminal}"
fi

# Print platform info
_C='\033[0;36m'
_W='\033[1;37m'
_N='\033[0m'
_D='\033[2m'

printf '\n'
printf '  %b%s%b@%b%s%b\n' "$_C" "$_user" "$_N" "$_C" "$_hostname_val" "$_N"
printf '  %b%s%b\n' "$_D" "$(printf '%*s' "$((${#_user} + 1 + ${#_hostname_val}))" '' | tr ' ' '-')" "$_N"
printf '  %bOS:%b         %s\n' "$_W" "$_N" "$_os"
printf '  %bHost:%b       %s\n' "$_W" "$_N" "$_host"
printf '  %bKernel:%b     %s\n' "$_W" "$_N" "$_kernel"
printf '  %bUptime:%b     %s\n' "$_W" "$_N" "${_uptime:-n/a}"
printf '  %bPackages:%b   %s\n' "$_W" "$_N" "$_packages"
printf '  %bShell:%b      %s\n' "$_W" "$_N" "$_shell"
printf '  %bResolution:%b %s\n' "$_W" "$_N" "$_resolution"
printf '  %bDE:%b         %s\n' "$_W" "$_N" "$_de"
printf '  %bTerminal:%b   %s\n' "$_W" "$_N" "$_terminal"
printf '  %bCPU:%b        %s (%s)\n' "$_W" "$_N" "$_cpu" "$_cpu_cores"
printf '  %bGPU:%b        %s\n' "$_W" "$_N" "${_gpu:-n/a}"
printf '  %bMemory:%b     %s\n' "$_W" "$_N" "$_mem"
printf '  %bArch:%b       %s\n' "$_W" "$_N" "$_arch"

if [[ -n "$_wsl" ]]; then
  echo ""
  if command -v wslpath >/dev/null 2>&1; then
    _ok "WSL bridge" "wslpath available"
  else
    _warn "WSL bridge" "wslpath missing"
  fi
  if [[ "$PWD" == /mnt/* ]]; then
    _warn "WSL filesystem" "/mnt causes IO latency"
  else
    _ok "WSL filesystem" "native"
  fi
fi

# --- State ---
_section "State"
if chezmoi verify &>/dev/null; then
  _ok "chezmoi" "synchronized"
else
  _fail "chezmoi" "drifted (run dot drift)"
fi

if [[ -f "$HOME/.zshrc" ]]; then
  _ok ".zshrc" "present"
else
  _fail ".zshrc" "missing"
fi

if command -v dot >/dev/null 2>&1; then
  dot_path="$(command -v dot)"
  if [[ "$dot_path" == "$HOME/.local/bin/dot" ]]; then
    _ok "dot" "$(pretty_path "$dot_path")"
  else
    _warn "dot" "$(pretty_path "$dot_path") (expected ~/.local/bin/dot)"
  fi
else
  _fail "dot" "not found in PATH"
fi

# --- Pre-push audit bypass log (closes #871) ---
_section "Pre-Push Audit Bypass"

bypass_log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/audit-bypass.log"
if [[ -s "$bypass_log" ]]; then
  # Count entries in the last 7 days (timestamps are ISO-8601 UTC).
  seven_days_ago=$(date -u -v-7d +%Y-%m-%dT00:00:00Z 2>/dev/null ||
    date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z 2>/dev/null ||
    echo "1970-01-01T00:00:00Z")
  recent=$(awk -v cutoff="$seven_days_ago" '$1 >= cutoff' "$bypass_log" | wc -l | tr -d ' ')
  if ((recent > 0)); then
    _warn "audit bypass" "$recent push(es) bypassed in last 7 days — see $(pretty_path "$bypass_log")"
  else
    _ok "audit bypass" "log exists; no recent entries (last 7d)"
  fi
else
  _ok "audit bypass" "clean — no pre-push audits bypassed"
fi

# --- Atuin history-filter (closes #872) ---
_section "Atuin History Filter"

atuin_cfg="$HOME/.config/atuin/config.toml"
if [[ ! -f "$atuin_cfg" ]]; then
  _warn "atuin config" "not found at $(pretty_path "$atuin_cfg")"
else
  if grep -Eq "^history_filter[[:space:]]*=" "$atuin_cfg"; then
    pattern_count=$(awk '
      /^history_filter[[:space:]]*=[[:space:]]*\[/ { inside = 1; next }
      inside && /^\]/                              { inside = 0 }
      inside && /^[[:space:]]*"/                   { count++ }
      END                                          { print count + 0 }
    ' "$atuin_cfg")
    if ((pattern_count >= 10)); then
      _ok "history_filter" "$pattern_count patterns (chezmoi-managed)"
    else
      _warn "history_filter" "$pattern_count patterns (expected ≥10 from secrets-patterns.toml)"
    fi
  else
    _fail "history_filter" "no history_filter block in $(pretty_path "$atuin_cfg") — secrets may leak into shell history"
  fi
fi

# --- Topgrade Integration ---
_section "Topgrade Integration"

if command -v antigravity >/dev/null 2>&1; then
  ag_path="$(command -v antigravity)"
  if [[ "$ag_path" == "$HOME/.local/bin/antigravity" ]]; then
    _ok "antigravity wrapper" "$(pretty_path "$ag_path")"
  else
    _warn "antigravity wrapper" "$(pretty_path "$ag_path") (expected ~/.local/bin/antigravity)"
  fi
else
  _warn "antigravity" "optional"
fi

if [[ -f "$HOME/.config/fish/fish_plugins" ]]; then
  if grep -qx "jorgebucaran/fisher" "$HOME/.config/fish/fish_plugins"; then
    _ok "fish_plugins" "contains jorgebucaran/fisher"
  else
    _warn "fish_plugins" "present but missing jorgebucaran/fisher"
  fi
else
  _fail "fish_plugins" "missing (~/.config/fish/fish_plugins)"
fi

if command -v cargo-install-update >/dev/null 2>&1; then
  _ok "cargo-install-update" "$(pretty_path "$(command -v cargo-install-update)")"
else
  _warn "cargo-install-update" "missing (install: cargo install cargo-update)"
fi

# --- Symlinks ---
broken_links=0
for root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.ssh"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' link; do
    link_name="$(basename "$link")"
    [[ "$link" == *"google-chrome-backup"* ]] && continue
    [[ "$link_name" == SingletonLock || "$link_name" == SingletonCookie || "$link_name" == SingletonSocket ]] && continue
    [[ -e "$link" ]] || broken_links=$((broken_links + 1))
  done < <(find "$root" -maxdepth 3 -type l -print0 2>/dev/null)
done

if [[ $broken_links -eq 0 ]]; then
  _ok "symlinks" "none broken"
else
  _warn "symlinks" "$broken_links broken"
fi

# --- Portability ---
ghost_paths=0
if command -v chezmoi >/dev/null 2>&1; then
  while IFS= read -r managed_path; do
    [[ "$managed_path" == "$HOME/.config/"* ]] || continue
    [[ -f "$managed_path" ]] || continue
    grep -Iq . "$managed_path" 2>/dev/null || continue

    match_count=$(
      grep -nE '"/home/(linuxbrew)?[^$]|/Users/[^$]' "$managed_path" 2>/dev/null |
        grep -v "linuxbrew" |
        grep -v "/mozilla/firefox" |
        grep -v "/google-chrome" |
        grep -v "/chromium" |
        grep -v "/chezmoi/chezmoi.toml" |
        grep -v "/bun/" |
        grep -v "/.bun/" |
        grep -v "/noctalia/" |
        grep -c -v -- "-backup/" ||
        true
    )

    ghost_paths=$((ghost_paths + ${match_count:-0}))
  done < <(chezmoi managed --path-style=absolute 2>/dev/null || true)

  if [[ $ghost_paths -gt 0 ]]; then
    _warn "portability" "$ghost_paths hardcoded paths in managed ~/.config files"
  else
    _ok "portability" "no hardcoded paths in managed ~/.config files"
  fi
else
  _warn "portability" "chezmoi not found (scan skipped)"
fi

# --- Performance ---
_section "Performance"

cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"

# 1. Shell cache freshness for tools the project already wraps in _cached_eval.
# Stale caches force runtime regeneration on next shell start.
stale_caches=0
stale_tools=""
for tool in mise starship zoxide atuin fzf direnv; do
  tool_bin="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$tool_bin" ]] || continue
  for shell_dir in zsh bash fish; do
    case "$shell_dir" in
      fish) cache_file="$cache_base/$shell_dir/${tool}-init.fish" ;;
      *) cache_file="$cache_base/$shell_dir/${tool}-init.$shell_dir" ;;
    esac
    if [[ ! -f "$cache_file" ]] || [[ "$tool_bin" -nt "$cache_file" ]]; then
      stale_caches=$((stale_caches + 1))
      case "$stale_tools" in
        *"$tool"*) ;;
        *) stale_tools="${stale_tools:+$stale_tools, }$tool" ;;
      esac
      break
    fi
  done
done
if [[ $stale_caches -eq 0 ]]; then
  _ok "shell caches" "fresh"
else
  _warn "shell caches" "stale ($stale_tools) — run dot prewarm"
fi

# 2. Slow-init tools that are present but NOT wrapped in _cached_eval.
# Each of these runs uncached on every shell start; common offenders eat
# 100-500ms apiece on a populated dev machine.
#
# Only flag tools that actually emit shell init via `<tool> init <shell>`
# (or equivalent) and would benefit from caching that output. Plain CLIs
# like gh/cargo/pnpm/yarn don't have init eval; their completions are
# cached separately under $ZSH_COMPLETIONS_DIR.
unwrapped=""
for tool in nvm fnm pyenv rbenv jenv asdf sdkman conda kubectl helm thefuck broot mcfly direnv; do
  command -v "$tool" >/dev/null 2>&1 || continue
  # If the tool is installed but no shell config sources or evals its
  # init (no `$tool env`, `$tool init`, `$tool.sh`, lazy-load stub), it
  # isn't adding startup cost — skip the warning.
  init_referenced=0
  if grep -rIlqE "\\b${tool}([[:space:]]+(env|init|hook)|\\.sh|_lazy_load_${tool}|_dot_lazy[[:space:]]+${tool})" \
    "$HOME/.config/zsh" "$HOME/.config/fish" "$HOME/.config/shell" 2>/dev/null; then
    init_referenced=1
  fi
  ((init_referenced == 0)) && continue
  # Tools we lazy-load via shell stubs don't need init-eval cache files.
  case "$tool" in
    fnm | nvm | sdkman)
      grep -rIlqE "_lazy_load_${tool}|_dot_lazy[[:space:]]+${tool}" \
        "$HOME/.config/zsh" "$HOME/.config/fish" 2>/dev/null && continue
      ;;
  esac
  found=0
  for shell_dir in zsh bash fish; do
    case "$shell_dir" in
      fish) [[ -f "$cache_base/$shell_dir/${tool}-init.fish" ]] && found=1 ;;
      *) [[ -f "$cache_base/$shell_dir/${tool}-init.$shell_dir" ]] && found=1 ;;
    esac
    ((found == 1)) && break
  done
  ((found == 0)) && unwrapped="${unwrapped:+$unwrapped, }$tool"
done
if [[ -z "$unwrapped" ]]; then
  _ok "uncached slow-init tools" "none detected"
else
  _warn "uncached slow-init tools" "$unwrapped — consider wrapping in _cached_eval"
fi

# 3. Zsh completion dump health. compinit is usually the single biggest
# cost on a zsh startup; a stale or uncompiled .zcompdump compounds it.
if command -v zsh >/dev/null 2>&1; then
  zcompdump="${HOME}/.zcompdump"
  if [[ -f "$zcompdump" ]]; then
    dump_mtime=$(stat -c %Y "$zcompdump" 2>/dev/null || stat -f %m "$zcompdump" 2>/dev/null || echo 0)
    age_days=$((($(date +%s) - dump_mtime) / 86400))
    if ((age_days > 7)); then
      _warn ".zcompdump" "${age_days}d old — refresh: rm ~/.zcompdump* && zsh -ic exit"
    else
      _ok ".zcompdump" "fresh (${age_days}d)"
    fi
    if [[ ! -f "${zcompdump}.zwc" ]]; then
      _warn ".zcompdump.zwc" "missing — completion init slower than necessary"
    fi
  fi
fi

# 4. PATH length. Each entry is searched on every command resolution.
# A mise-managed dev machine routinely adds 50+ entries (one per tool
# install path), so the warn/fail thresholds are set higher than a
# lean baseline (40) would suggest.
path_count=$(printf '%s' "${PATH:-}" | tr ':' '\n' | grep -c . || true)
if [[ "$path_count" -le 60 ]]; then
  _ok "PATH length" "$path_count entries"
elif [[ "$path_count" -le 120 ]]; then
  _warn "PATH length" "$path_count entries — consider pruning"
else
  _fail "PATH length" "$path_count entries — likely slowing every command"
fi

# 5. Shell coverage. Surface installed shells that the project's caching
# infrastructure doesn't currently maintain caches for. zsh/bash/fish/nu
# all have a `_cached_eval` analogue; pwsh does not.
shells_unmanaged=""
for sh in nu pwsh; do
  command -v "$sh" >/dev/null 2>&1 || continue
  case "$sh" in
    nu)
      [[ -f "$HOME/.config/nushell/cached_eval.nu" ]] && continue
      ;;
  esac
  shells_unmanaged="${shells_unmanaged:+$shells_unmanaged, }$sh"
done
if [[ -z "$shells_unmanaged" ]]; then
  _ok "shell coverage" "all installed shells have _cached_eval support"
else
  _warn "shell coverage" "$shells_unmanaged installed — no _cached_eval helper"
fi

# 6. Zsh hook count. Heavy precmd/preexec functions compound per-prompt.
# Probe an interactive zsh with a hard timeout so a broken zshrc doesn't
# stall doctor; skip cleanly if the probe fails.
if command -v zsh >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  hook_counts=$(timeout 5 zsh -i -c 'echo "$#precmd_functions $#preexec_functions"' 2>/dev/null || echo "")
  if [[ -n "$hook_counts" ]]; then
    read -r precmd_n preexec_n <<<"$hook_counts"
    if [[ "${precmd_n:-0}" -le 5 && "${preexec_n:-0}" -le 5 ]]; then
      _ok "zsh hooks" "precmd=$precmd_n preexec=$preexec_n"
    else
      _warn "zsh hooks" "precmd=$precmd_n preexec=$preexec_n — heavy per-prompt work"
    fi
  fi
fi

if command -v hyperfine >/dev/null 2>&1; then
  if bash "$SCRIPT_DIR/../../tests/performance/bench.sh" 2>/dev/null; then
    _ok "startup latency" "within target thresholds"
  else
    _warn "startup latency" "threshold exceeded (run dot prewarm)"
  fi
else
  _warn "hyperfine" "missing (benchmark skipped)"
fi

# 7. Baseline check + top-3 slowest tools from EVALCACHE_TIMING.
# Closes part of #863. Reads the same baseline file `dot perf` writes,
# and the same eval-timings.jsonl _cached_eval populates. Skipped
# silently when either file is absent (first-run state).
baseline_file="$cache_base/dotfiles/perf-baseline.json"
if [[ -s "$baseline_file" ]] && command -v python3 >/dev/null 2>&1; then
  baseline_age_days=$(python3 -c '
import json, sys, datetime
try:
    d = json.load(open(sys.argv[1]))
    rec = d.get("recorded_at", "")
    if not rec: print(-1); sys.exit(0)
    rec = rec.replace("Z", "+00:00")
    age = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(rec)).days
    print(age)
except Exception:
    print(-1)
' "$baseline_file" 2>/dev/null)
  if [[ "$baseline_age_days" -ge 0 ]]; then
    _ok "perf baseline" "recorded ${baseline_age_days}d ago — run \`dot perf\` to compare"
  fi
fi

timings_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/eval-timings.jsonl"
if [[ -s "$timings_file" ]] && command -v python3 >/dev/null 2>&1; then
  top_tools=$(python3 -c '
import json, sys
from collections import defaultdict
samples = defaultdict(list)
try:
    for line in open(sys.argv[1]):
        try:
            ev = json.loads(line)
            ms = int(ev.get("ms", 0) or 0)
            samples[ev.get("label", "?")].append(ms)
        except Exception:
            pass
    rows = sorted(samples.items(), key=lambda kv: sum(kv[1]) // max(len(kv[1]), 1), reverse=True)[:3]
    print(", ".join(f"{lbl}({sum(v)//max(len(v),1)}ms)" for lbl, v in rows))
except Exception:
    pass
' "$timings_file" 2>/dev/null)
  if [[ -n "$top_tools" ]]; then
    _ok "perf top-tools" "$top_tools"
  fi
fi

# --- Summary ---
dot_log info "doctor_complete" "errors=$Errors" "warnings=$Warnings"
dot_metric "doctor_errors" "$Errors" "count"
dot_metric "doctor_warnings" "$Warnings" "count"
echo ""
if [[ $Errors -eq 0 ]]; then
  if [[ $Warnings -eq 0 ]]; then
    ui_ok "Healthy" "All checks passed."
  else
    ui_ok "Healthy" "$Warnings warning(s)."
  fi
else
  ui_err "$Errors error(s)" "$Warnings warning(s). Run 'dot heal' to repair."

  if [[ $AI_DEBUG -eq 1 ]]; then
    _section "AI Problem Analysis"
    doctor_report=$(~/.local/bin/dot doctor | grep -E "(✗|⚠)")
    ai_prompt="The dotfiles diagnostic 'dot doctor' found the following issues:
---
$doctor_report
---
Suggest specific shell commands to fix these issues according to our architectural standards."
    dot cl --pattern hardener "$ai_prompt"
  fi
  exit 1
fi
echo ""
