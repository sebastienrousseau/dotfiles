#!/usr/bin/env bash
# Linux System Tuning (opt-in)
# Managed by chezmoi - https://github.com/sebastienrousseau/dotfiles
#
# Usage: DOTFILES_TUNING=1 DOTFILES_PROFILE=laptop ./linux.sh
# Profiles: laptop, desktop, server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Linux Tuning"

if [[ "${DOTFILES_TUNING:-0}" != "1" ]]; then
  ui_warn "Tuning" "disabled. Re-run with DOTFILES_TUNING=1"
  exit 0
fi

PROFILE="${DOTFILES_PROFILE:-laptop}"

if [[ "$PROFILE" != "laptop" && "$PROFILE" != "desktop" && "$PROFILE" != "server" ]]; then
  ui_err "DOTFILES_PROFILE" "must be laptop, desktop, or server (got: $PROFILE)"
  exit 1
fi

ui_info "Applying tuning" "$PROFILE profile"

apply_sysctl() {
  local key="$1"
  local value="$2"
  if command -v sudo >/dev/null; then
    ui_info "Setting" "$key = $value"
    sudo sysctl -w "$key=$value" >/dev/null 2>&1 || ui_warn "Failed to set" "$key"
  fi
}

if ! command -v sudo >/dev/null; then
  ui_warn "sudo" "not available; skipping sysctl tuning"
  exit 0
fi

# =============================================================================
# File System Tuning
# =============================================================================
ui_header "File system settings"

# Increase inotify watchers for IDEs and file sync tools
apply_sysctl "fs.inotify.max_user_watches" "524288"
apply_sysctl "fs.inotify.max_user_instances" "512"

# Increase file descriptor limits
apply_sysctl "fs.file-max" "2097152"

# =============================================================================
# Memory Tuning - vm.swappiness
# =============================================================================
ui_header "Memory settings"

case "$PROFILE" in
  laptop)
    # Laptop: Balance between RAM and battery (moderate swappiness)
    apply_sysctl "vm.swappiness" "10"
    apply_sysctl "vm.vfs_cache_pressure" "50"
    apply_sysctl "vm.dirty_ratio" "15"
    apply_sysctl "vm.dirty_background_ratio" "5"
    ;;
  desktop)
    # Desktop: Prefer RAM over swap (low swappiness, more RAM usage)
    apply_sysctl "vm.swappiness" "5"
    apply_sysctl "vm.vfs_cache_pressure" "50"
    apply_sysctl "vm.dirty_ratio" "20"
    apply_sysctl "vm.dirty_background_ratio" "5"
    ;;
  server)
    # Server: Minimal swapping for consistent performance
    apply_sysctl "vm.swappiness" "1"
    apply_sysctl "vm.vfs_cache_pressure" "100"
    apply_sysctl "vm.dirty_ratio" "10"
    apply_sysctl "vm.dirty_background_ratio" "3"
    ;;
esac

# =============================================================================
# Network Tuning - TCP Keepalive
# =============================================================================
ui_header "TCP keepalive settings"

# TCP keepalive: Detect dead connections faster
# Default: 7200s (2 hours) - we reduce to 60s for faster detection
apply_sysctl "net.ipv4.tcp_keepalive_time" "60"

# Interval between keepalive probes (default: 75s)
apply_sysctl "net.ipv4.tcp_keepalive_intvl" "10"

# Number of keepalive probes before connection is dropped (default: 9)
apply_sysctl "net.ipv4.tcp_keepalive_probes" "6"

# Enable TCP Fast Open for faster connections
apply_sysctl "net.ipv4.tcp_fastopen" "3"

# Increase TCP buffer sizes for better throughput
apply_sysctl "net.core.rmem_max" "16777216"
apply_sysctl "net.core.wmem_max" "16777216"
apply_sysctl "net.ipv4.tcp_rmem" "4096 87380 16777216"
apply_sysctl "net.ipv4.tcp_wmem" "4096 65536 16777216"

# Connection tracking and queueing
apply_sysctl "net.core.somaxconn" "4096"
apply_sysctl "net.core.netdev_max_backlog" "4096"

# Reuse TIME_WAIT sockets for new connections
apply_sysctl "net.ipv4.tcp_tw_reuse" "1"

# Reduce FIN timeout for faster connection cleanup
apply_sysctl "net.ipv4.tcp_fin_timeout" "15"

# =============================================================================
# Security Tuning
# =============================================================================
ui_header "Security settings"

# Disable IP source routing
apply_sysctl "net.ipv4.conf.all.accept_source_route" "0"
apply_sysctl "net.ipv4.conf.default.accept_source_route" "0"

# Ignore ICMP redirects
apply_sysctl "net.ipv4.conf.all.accept_redirects" "0"
apply_sysctl "net.ipv4.conf.default.accept_redirects" "0"

# Ignore bogus ICMP errors
apply_sysctl "net.ipv4.icmp_ignore_bogus_error_responses" "1"

# Enable SYN flood protection
apply_sysctl "net.ipv4.tcp_syncookies" "1"

# =============================================================================
# Persist Settings
# =============================================================================
ui_header "Persisting sysctl settings"

if command -v sudo >/dev/null; then
  sudo tee /etc/sysctl.d/99-dotfiles.conf >/dev/null <<'EOF'
# Dotfiles system tuning - auto-generated
# https://github.com/sebastienrousseau/dotfiles

# File system
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
fs.file-max = 2097152

# Memory (adjust vm.swappiness per profile)
vm.vfs_cache_pressure = 50

# TCP Keepalive
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_fastopen = 3

# TCP Performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Security
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
EOF
fi

ui_ok "Linux tuning complete" "$PROFILE profile"
ui_info "Note" "Some settings require a reboot"
