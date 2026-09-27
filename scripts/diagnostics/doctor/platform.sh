#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by doctor.sh; inherits set -euo pipefail
# Platform section of dot doctor: OS/hardware detection, WSL, the
# platform block. Sourced by scripts/diagnostics/doctor.sh; uses its helpers
# and globals (_ok/_warn, _os_name, _arch, ...).

# --- Platform ---
_doctor_platform() {
  _section "Platform"

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
}

# --- OS-specific detection ---
# macOS: model, CPU, GPU, memory, display, packages
_doctor_detect_macos() {
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
  # Guarded like the Linux branch: without brew on PATH the pipeline
  # returns 127 under pipefail and set -e ended the whole report here.
  if command -v brew >/dev/null 2>&1; then
    _packages="$(brew list --formula 2>/dev/null | wc -l | tr -d ' ') (brew)"
  else
    _packages="n/a"
  fi
  _de="Aqua"
}

# Linux (Debian, Ubuntu, Arch, Fedora, RHEL, ...) via os-release, /sys and /proc
# CPU model and core count (lscpu, else /proc/cpuinfo)
_doctor_linux_cpu() {
  if command -v lscpu >/dev/null 2>&1; then
    _cpu="$(lscpu | awk -F': +' '/Model name/{print $2}')"
    _cpu_cores="$(lscpu | awk -F': +' '/^CPU\(s\):/{print $2}')"
  else
    _cpu="$(grep -m1 'model name' "$proc_root/cpuinfo" 2>/dev/null | cut -d: -f2 | sed 's/^ //' || uname -p)"
    _cpu_cores="$(grep -c '^processor' "$proc_root/cpuinfo" 2>/dev/null || echo "?")"
  fi
}

# First display controller from lspci
_doctor_linux_gpu() {
  if command -v lspci >/dev/null 2>&1; then
    # Headless hosts (VMs, containers, CI runners) expose no display
    # controller, so `grep` exits 1 and — under `set -euo pipefail` —
    # would abort the whole report mid-section. Absorb the miss.
    _gpu="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //' || true)"
    _gpu="${_gpu:-n/a}"
  else
    _gpu="n/a"
  fi
}

# Used / total memory (free, else /proc/meminfo)
_doctor_linux_memory() {
  if command -v free >/dev/null 2>&1; then
    _mem="$(free -b | awk '/Mem:/{printf "%.2f GiB / %.2f GiB", $3/1073741824, $2/1073741824}')"
  elif [[ -r "$proc_root/meminfo" ]]; then
    _mem_total_kb="$(awk '/MemTotal/{print $2}' "$proc_root/meminfo")"
    _mem_avail_kb="$(awk '/MemAvailable/{print $2}' "$proc_root/meminfo")"
    _mem_used_kb=$((_mem_total_kb - _mem_avail_kb))
    _mem="$(awk "BEGIN{printf \"%.2f GiB / %.2f GiB\", ${_mem_used_kb}/1048576, ${_mem_total_kb}/1048576}")"
  else
    _mem="n/a"
  fi
}

# Resolution (Wayland or X11)
_doctor_linux_resolution() {
  if command -v wlr-randr >/dev/null 2>&1; then
    _resolution="$(wlr-randr 2>/dev/null | awk '/current/{print $1; exit}' || echo "n/a")"
  elif command -v xrandr >/dev/null 2>&1; then
    _resolution="$(xrandr 2>/dev/null | awk '/\*/{print $1; exit}' || echo "n/a")"
  elif command -v xdpyinfo >/dev/null 2>&1; then
    _resolution="$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2}' || echo "n/a")"
  else
    _resolution="n/a"
  fi
}

# Installed package count (dpkg, rpm or pacman)
_doctor_linux_packages() {
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
}

_doctor_detect_linux() {
  # Linux (Debian, Ubuntu, Arch, Fedora, RHEL, etc.)
  # The file is chosen at runtime (DOT_DOCTOR_OS_RELEASE in tests).
  # shellcheck source=/dev/null
  . "$os_release_file"
  _os="${PRETTY_NAME:-$ID}"

  _host="$(cat "$sys_root/devices/virtual/dmi/id/product_name" 2>/dev/null || cat "$sys_root/firmware/devicetree/base/model" 2>/dev/null || echo "Linux")"

  _doctor_linux_cpu
  _doctor_linux_gpu
  _doctor_linux_memory
  _doctor_linux_resolution
  _doctor_linux_packages

  _de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-n/a}}"
}

# Unknown OS: what uname can tell
_doctor_detect_other() {
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
}

# WSL detection and overrides
_doctor_detect_wsl() {
  _wsl=""
  if [[ -f "$proc_root/version" ]] && grep -qi microsoft "$proc_root/version" 2>/dev/null; then
    _wsl="yes"
    _os="${_os} (WSL)"
    _de="Windows Desktop (WSL)"
    _terminal="${TERM_PROGRAM:-Windows Terminal}"
  fi
}

# The neofetch-style platform block
_doctor_print_platform() {
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
}

# WSL-only checks
_doctor_check_wsl() {
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
}

_doctor_os_specific_detection() {
  _os="" _host="" _cpu="" _cpu_cores="" _gpu="" _mem="" _resolution="" _packages="" _de=""
  os_release_file="${DOT_DOCTOR_OS_RELEASE:-/etc/os-release}"
  proc_root="${DOT_DOCTOR_PROC_ROOT:-/proc}"
  sys_root="${DOT_DOCTOR_SYS_ROOT:-/sys}"

  if [[ "$_os_name" == "Darwin" ]]; then
    _doctor_detect_macos
  elif [[ -r "$os_release_file" ]]; then
    _doctor_detect_linux
  else
    _doctor_detect_other
  fi
  _doctor_detect_wsl
  _doctor_print_platform
  if [[ -n "$_wsl" ]]; then
    _doctor_check_wsl
  fi
}
