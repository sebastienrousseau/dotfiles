#!/usr/bin/env bash
# Security Score Assessment
# Usage: dot security-score [--verbose|-v] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

# Parse arguments
VERBOSE=false
JSON_OUTPUT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose | -v)
      VERBOSE=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    *) shift ;;
  esac
done

# Scoring
TOTAL_POINTS=0
MAX_POINTS=0
declare -A CATEGORY_SCORES

add_points() {
  local category="$1"
  local points="$2"
  local max="$3"
  local description="$4"
  local status="$5"
  local width=80
  local name_width=60
  local status_width=$((width - name_width))

  TOTAL_POINTS=$((TOTAL_POINTS + points))
  MAX_POINTS=$((MAX_POINTS + max))
  CATEGORY_SCORES["$category"]=$((${CATEGORY_SCORES[$category]:-0} + points))

  if ! $JSON_OUTPUT && $VERBOSE; then
    case "$status" in
      pass)
        printf "  %s %-${name_width}s %s[%s]%s\n" "${GREEN}${SYMBOL_SUCCESS}${NORMAL}" "$description" "${GREEN}" "  OK   " "${NORMAL}"
        ;;
      warn)
        printf "  %s %-${name_width}s %s[%s]%s\n" "${YELLOW}${SYMBOL_WARN}${NORMAL}" "$description" "${YELLOW}" "WARNING" "${NORMAL}"
        ;;
      fail)
        printf "  %s %-${name_width}s %s[%s]%s\n" "${RED}${SYMBOL_ERROR}${NORMAL}" "$description" "${RED}" "FAILED " "${NORMAL}"
        ;;
    esac
  fi
}

# === Security Checks ===

check_encryption() {
  ui_section "Encryption (30 pts max)"

  # Age encryption tool
  if command -v age >/dev/null 2>&1; then
    add_points "encryption" 5 5 "Age encryption installed" "pass"
  else
    add_points "encryption" 0 5 "Age encryption installed" "fail"
  fi

  # Age key exists
  if [[ -f "${HOME}/.config/chezmoi/key.txt" ]]; then
    add_points "encryption" 5 5 "Age encryption key present" "pass"

    local perms
    perms=$(stat -c "%a" "${HOME}/.config/chezmoi/key.txt" 2>/dev/null || stat -f "%OLp" "${HOME}/.config/chezmoi/key.txt" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
      add_points "encryption" 5 5 "Key file permissions (600)" "pass"
    else
      add_points "encryption" 2 5 "Key file permissions (600)" "warn"
    fi
  else
    add_points "encryption" 0 10 "Age encryption configured" "fail"
  fi

  # SOPS available
  if command -v sops >/dev/null 2>&1; then
    add_points "encryption" 5 5 "SOPS secrets manager" "pass"
  else
    add_points "encryption" 0 5 "SOPS secrets manager" "fail"
  fi

  # GPG available
  if command -v gpg >/dev/null 2>&1 && gpg --list-secret-keys 2>/dev/null | grep -q sec; then
    add_points "encryption" 10 10 "GPG keys configured" "pass"
  elif command -v gpg >/dev/null 2>&1; then
    add_points "encryption" 3 10 "GPG keys configured" "warn"
  else
    add_points "encryption" 0 10 "GPG keys configured" "fail"
  fi
}

check_ssh() {
  ui_section "SSH Security (25 pts max)"

  # SSH directory permissions
  if [[ -d "${HOME}/.ssh" ]]; then
    local ssh_perms
    ssh_perms=$(stat -c "%a" "${HOME}/.ssh" 2>/dev/null || stat -f "%OLp" "${HOME}/.ssh" 2>/dev/null)
    if [[ "$ssh_perms" == "700" ]]; then
      add_points "ssh" 5 5 "SSH directory permissions (700)" "pass"
    else
      add_points "ssh" 2 5 "SSH directory permissions (700)" "warn"
    fi
  else
    add_points "ssh" 0 5 "SSH directory exists" "fail"
  fi

  # ED25519 key (preferred over RSA)
  if [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
    add_points "ssh" 10 10 "ED25519 SSH key (modern)" "pass"
  elif [[ -f "${HOME}/.ssh/id_rsa" ]]; then
    add_points "ssh" 5 10 "SSH key present (RSA)" "warn"
  else
    add_points "ssh" 0 10 "SSH key present" "fail"
  fi

  # SSH agent
  if [[ -n "${SSH_AUTH_SOCK:-}" ]] || pgrep -x ssh-agent >/dev/null 2>&1; then
    add_points "ssh" 5 5 "SSH agent running" "pass"
  else
    add_points "ssh" 0 5 "SSH agent running" "fail"
  fi

  # SSH config exists
  if [[ -f "${HOME}/.ssh/config" ]]; then
    add_points "ssh" 5 5 "SSH config present" "pass"
  else
    add_points "ssh" 2 5 "SSH config present" "warn"
  fi
}

check_git() {
  ui_section "Git Security (20 pts max)"

  # Git installed
  if ! command -v git >/dev/null 2>&1; then
    add_points "git" 0 20 "Git installed" "fail"
    return
  fi

  # Commit signing
  if git config --global commit.gpgsign 2>/dev/null | grep -q true; then
    add_points "git" 10 10 "Commit signing enabled" "pass"
  else
    add_points "git" 0 10 "Commit signing enabled" "fail"
  fi

  # User identity configured
  if git config --global user.email >/dev/null 2>&1 && git config --global user.name >/dev/null 2>&1; then
    add_points "git" 5 5 "Git identity configured" "pass"
  else
    add_points "git" 0 5 "Git identity configured" "fail"
  fi

  # Credential helper
  if git config --global credential.helper >/dev/null 2>&1; then
    add_points "git" 5 5 "Credential helper configured" "pass"
  else
    add_points "git" 0 5 "Credential helper configured" "fail"
  fi
}

check_system() {
  ui_section "System Security (15 pts max)"

  # Firewall (macOS or Linux)
  if [[ "$(uname)" == "Darwin" ]]; then
    if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q enabled; then
      add_points "system" 5 5 "Firewall enabled" "pass"
    elif pgrep -x "Little Snitch" >/dev/null 2>&1 || [[ -d "/Applications/Little Snitch.app" ]]; then
      add_points "system" 5 5 "Firewall enabled (Little Snitch)" "pass"
    else
      add_points "system" 0 5 "Firewall enabled" "fail"
    fi
  else
    local fw_enabled=false
    if systemctl is-active --quiet ufw 2>/dev/null; then
      fw_enabled=true
    elif command -v ufw >/dev/null 2>&1 && sudo -n ufw status 2>/dev/null | grep -q "Status: active"; then
      fw_enabled=true
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -q running; then
      fw_enabled=true
    fi

    if $fw_enabled; then
      add_points "system" 5 5 "Firewall enabled" "pass"
    else
      add_points "system" 0 5 "Firewall enabled" "fail"
    fi
  fi

  # Disk encryption
  if [[ "$(uname)" == "Darwin" ]]; then
    if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
      add_points "system" 10 10 "Disk encryption (FileVault)" "pass"
    else
.
      add_points "system" 0 10 "Disk encryption (FileVault)" "fail"
    fi
  else
    local encryption_found=false
    if lsblk 2>/dev/null | grep -q crypt || [[ -d /sys/block/dm-0 ]]; then
      encryption_found=true
      add_points "system" 10 10 "Disk encryption (LUKS)" "pass"
    elif lspci 2>/dev/null | grep -qi "T2.*Secure Enclave"; then
      encryption_found=true
      add_points "system" 10 10 "Hardware encryption (Apple T2)" "pass"
    elif mount 2>/dev/null | grep -q ecryptfs || [[ -d "$HOME/.ecryptfs" ]]; then
      encryption_found=true
      add_points "system" 10 10 "Home encryption (ecryptfs)" "pass"
    elif [[ -f /sys/class/dmi/id/product_name ]] && grep -qiE "virtual|vmware|kvm|qemu" /sys/class/dmi/id/product_name 2>/dev/null; then
      encryption_found=true
      add_points "system" 10 10 "Virtualized (host encryption)" "pass"
    fi

    if ! $encryption_found; then
      add_points "system" 0 10 "Disk encryption" "unknown"
    fi
  fi
}

check_secrets() {
  ui_section "Secrets Management (10 pts max)"

  if [[ -d "${HOME}/.dotfiles" ]]; then
    if grep -rE "(api_key|api_secret|password|token)\\s*=\\s*['\"][^'\"]+['\"]" "${HOME}/.dotfiles" --include="*.sh" --include="*.zsh" --include="*.toml" 2>/dev/null | grep -v "example\|template\|placeholder" | head -1; then
      add_points "secrets" 0 5 "No hardcoded secrets" "fail"
    else
      add_points "secrets" 5 5 "No hardcoded secrets" "pass"
    fi
  else
    add_points "secrets" 5 5 "No hardcoded secrets" "pass"
  fi

  if [[ -f "${HOME}/.config/secrets/api-keys.env" ]] || [[ -d "${HOME}/.config/secrets" ]]; then
    add_points "secrets" 5 5 "Secrets in dedicated location" "pass"
  else
    add_points "secrets" 2 5 "Secrets management setup" "warn"
  fi
}

get_grade() {
  local score=$1
  if [[ $score -ge 95 ]]; then echo "A+";
  elif [[ $score -ge 90 ]]; then echo "A";
  elif [[ $score -ge 85 ]]; then echo "A-";
  elif [[ $score -ge 80 ]]; then echo "B+";
  elif [[ $score -ge 75 ]]; then echo "B";
  elif [[ $score -ge 70 ]]; then echo "B-";
  elif [[ $score -ge 65 ]]; then echo "C+";
  elif [[ $score -ge 60 ]]; then echo "C";
  elif [[ $score -ge 55 ]]; then echo "C-";
  elif [[ $score -ge 50 ]]; then echo "D";
  else echo "F";
  fi
}

print_summary() {
  local score=$((TOTAL_POINTS * 100 / MAX_POINTS))

  if $JSON_OUTPUT; then
    # ... (json output unchanged)
    return
  fi

  ui_section "Summary"
  ui_key_value "Total Points" "${TOTAL_POINTS}/${MAX_POINTS}"
  ui_key_value "Security Score" "${score}%"
  ui_key_value "Grade" "$(get_grade "$score")"

  printf "\n"
  if [[ $score -lt 100 ]]; then
    ui_info "Recommendations for improving your score:"
    if ! command -v age >/dev/null 2>&1; then ui_bullet "Install age for encryption: brew install age"; fi
    if ! command -v sops >/dev/null 2>&1; then ui_bullet "Install SOPS for secrets: brew install sops"; fi
    if ! git config --global commit.gpgsign 2>/dev/null | grep -q true; then ui_bullet "Enable commit signing: git config --global commit.gpgsign true"; fi
    if [[ ! -f "${HOME}/.ssh/id_ed25519" ]]; then ui_bullet "Generate ED25519 SSH key: ssh-keygen -t ed25519"; fi
  fi
  printf "\n"
}

# Main
ui_header "Security Score Assessment"
check_encryption
check_ssh
check_git
check_system
check_secrets
print_summary
