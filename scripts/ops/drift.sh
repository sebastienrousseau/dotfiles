#!/usr/bin/env bash
# Smart drift detection with automatic remediation
# Usage: dot drift [check|fix|report|watch]
#
# Analyzes configuration drift and provides:
# - Categorized drift by type and severity
# - Specific remediation suggestions
# - Auto-fix for safe changes
# - Interactive mode for review

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

# =============================================================================
# Configuration
# =============================================================================

DRIFT_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/drift.log"
DRIFT_IGNORE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/drift-ignore"

# Severity levels
declare -A SEVERITY_COLORS
SEVERITY_COLORS=(
  [critical]="$RED"
  [warning]="$YELLOW"
  [info]="$CYAN"
  [safe]="$GREEN"
)

# =============================================================================
# Drift Analysis
# =============================================================================

# Parse chezmoi status and categorize changes
analyze_drift() {
  local status_output
  status_output=$(chezmoi status 2>/dev/null || true)

  if [[ -z "$status_output" ]]; then
    return 0
  fi

  local modified=0 added=0 deleted=0 renamed=0
  local critical_files=() warning_files=() info_files=() safe_files=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local status_code="${line:0:2}"
    local file_path="${line:3}"

    # Determine change type
    case "$status_code" in
      "MM"|" M"|"M ")
        ((modified++))
        ;;
      "A "|" A")
        ((added++))
        ;;
      "D "|" D")
        ((deleted++))
        ;;
      "R"*)
        ((renamed++))
        ;;
    esac

    # Categorize by severity based on file type/location
    local severity="info"
    case "$file_path" in
      # Critical: Security-sensitive files
      *.ssh/*|*/.gnupg/*|*secrets*|*.env|*credentials*|*token*)
        severity="critical"
        ;;
      # Warning: Shell configuration
      *.zshrc*|*.bashrc*|*.profile|*/shell/*|*/zsh/*)
        severity="warning"
        ;;
      # Safe: Editor/tool configs
      */.config/nvim/*|*/.config/git/*|*/.config/starship*|*/themes/*)
        severity="safe"
        ;;
      # Info: Everything else
      *)
        severity="info"
        ;;
    esac

    case "$severity" in
      critical) critical_files+=("$status_code|$file_path") ;;
      warning) warning_files+=("$status_code|$file_path") ;;
      safe) safe_files+=("$status_code|$file_path") ;;
      *) info_files+=("$status_code|$file_path") ;;
    esac

  done <<< "$status_output"

  # Export results
  echo "DRIFT_MODIFIED=$modified"
  echo "DRIFT_ADDED=$added"
  echo "DRIFT_DELETED=$deleted"
  echo "DRIFT_RENAMED=$renamed"
  echo "DRIFT_TOTAL=$((modified + added + deleted + renamed))"
  echo "DRIFT_CRITICAL=${#critical_files[@]}"
  echo "DRIFT_WARNING=${#warning_files[@]}"
  echo "DRIFT_INFO=${#info_files[@]}"
  echo "DRIFT_SAFE=${#safe_files[@]}"

  # Store file lists for later use
  printf '%s\n' "${critical_files[@]}" > /tmp/drift_critical.$$
  printf '%s\n' "${warning_files[@]}" > /tmp/drift_warning.$$
  printf '%s\n' "${info_files[@]}" > /tmp/drift_info.$$
  printf '%s\n' "${safe_files[@]}" > /tmp/drift_safe.$$
}

# Get remediation suggestion for a specific drift
get_remediation() {
  local status_code="$1"
  local file_path="$2"

  local action=""
  local command=""
  local auto_safe=0

  case "$status_code" in
    "MM"|" M"|"M ")
      # File modified locally
      case "$file_path" in
        */.zshrc.local|*/.gitconfig.local|*/local/*)
          action="Keep local changes (expected)"
          command="chezmoi add \"$file_path\""
          auto_safe=1
          ;;
        *)
          action="Review diff and decide"
          command="chezmoi diff \"$file_path\""
          ;;
      esac
      ;;
    "A ")
      # New file in target (not in source)
      case "$file_path" in
        */cache/*|*/tmp/*|*/.cache/*|*__pycache__*)
          action="Ignore (cache file)"
          command="# Add to .chezmoiignore"
          auto_safe=1
          ;;
        *.log|*.swp|*.swo|*~)
          action="Ignore (temporary file)"
          command="# Add to .chezmoiignore"
          auto_safe=1
          ;;
        *)
          action="Add to source or ignore"
          command="chezmoi add \"$file_path\""
          ;;
      esac
      ;;
    " A")
      # New file in source (not in target)
      action="Apply to create file"
      command="chezmoi apply \"$file_path\""
      auto_safe=1
      ;;
    "D ")
      # Deleted in target
      action="Restore from source"
      command="chezmoi apply \"$file_path\""
      ;;
    " D")
      # Deleted in source
      action="File removed from dotfiles"
      command="rm \"$file_path\"  # or chezmoi forget \"$file_path\""
      ;;
    "R"*)
      action="File renamed/moved"
      command="chezmoi apply"
      ;;
    *)
      action="Unknown change type"
      command="chezmoi diff \"$file_path\""
      ;;
  esac

  echo "ACTION=$action"
  echo "COMMAND=$command"
  echo "AUTO_SAFE=$auto_safe"
}

# =============================================================================
# Commands
# =============================================================================

cmd_check() {
  ui_header "Drift Detection"
  echo ""

  if ! command -v chezmoi >/dev/null 2>&1; then
    ui_err "Error" "chezmoi not found"
    exit 1
  fi

  # Run analysis
  local analysis
  analysis=$(analyze_drift)
  eval "$analysis"

  if [[ "${DRIFT_TOTAL:-0}" -eq 0 ]]; then
    ui_ok "Clean" "No configuration drift detected"
    return 0
  fi

  # Summary
  ui_section "Summary"
  echo ""
  ui_kv "Total changes:" "$DRIFT_TOTAL"
  [[ "${DRIFT_MODIFIED:-0}" -gt 0 ]] && ui_kv "  Modified:" "$DRIFT_MODIFIED"
  [[ "${DRIFT_ADDED:-0}" -gt 0 ]] && ui_kv "  Added:" "$DRIFT_ADDED"
  [[ "${DRIFT_DELETED:-0}" -gt 0 ]] && ui_kv "  Deleted:" "$DRIFT_DELETED"
  [[ "${DRIFT_RENAMED:-0}" -gt 0 ]] && ui_kv "  Renamed:" "$DRIFT_RENAMED"
  echo ""

  # Severity breakdown
  ui_section "By Severity"
  echo ""

  if [[ "${DRIFT_CRITICAL:-0}" -gt 0 ]]; then
    ui_err "Critical" "${DRIFT_CRITICAL} security-sensitive files"
    while IFS='|' read -r code path; do
      [[ -z "$path" ]] && continue
      printf "    %s%s%s %s\n" "$RED" "$code" "$NORMAL" "$path"
    done < /tmp/drift_critical.$$
    echo ""
  fi

  if [[ "${DRIFT_WARNING:-0}" -gt 0 ]]; then
    ui_warn "Warning" "${DRIFT_WARNING} shell configuration files"
    while IFS='|' read -r code path; do
      [[ -z "$path" ]] && continue
      printf "    %s%s%s %s\n" "$YELLOW" "$code" "$NORMAL" "$path"
    done < /tmp/drift_warning.$$
    echo ""
  fi

  if [[ "${DRIFT_INFO:-0}" -gt 0 ]]; then
    ui_info "Info" "${DRIFT_INFO} general configuration files"
    if [[ "${DRIFT_INFO:-0}" -le 5 ]]; then
      while IFS='|' read -r code path; do
        [[ -z "$path" ]] && continue
        printf "    %s%s%s %s\n" "$CYAN" "$code" "$NORMAL" "$path"
      done < /tmp/drift_info.$$
    else
      head -5 /tmp/drift_info.$$ | while IFS='|' read -r code path; do
        [[ -z "$path" ]] && continue
        printf "    %s%s%s %s\n" "$CYAN" "$code" "$NORMAL" "$path"
      done
      printf "    %s... and %d more%s\n" "$GRAY" "$((DRIFT_INFO - 5))" "$NORMAL"
    fi
    echo ""
  fi

  if [[ "${DRIFT_SAFE:-0}" -gt 0 ]]; then
    ui_ok "Safe" "${DRIFT_SAFE} low-risk files (auto-fixable)"
    echo ""
  fi

  # Recommendations
  ui_section "Recommendations"
  echo ""

  if [[ "${DRIFT_CRITICAL:-0}" -gt 0 ]]; then
    ui_bullet "Review critical files manually before any changes"
    ui_bullet "Run: dot drift report --critical"
  fi

  if [[ "${DRIFT_SAFE:-0}" -gt 0 ]]; then
    ui_bullet "Auto-fix safe changes: dot drift fix --safe"
  fi

  ui_bullet "Review all changes: dot drift report"
  ui_bullet "Apply all from source: chezmoi apply"
  ui_bullet "Add local changes: chezmoi re-add"

  # Cleanup temp files
  rm -f /tmp/drift_*.$$

  # Return non-zero if drift detected
  return 1
}

cmd_report() {
  local filter="${1:-all}"

  ui_header "Drift Report"
  echo ""

  local status_output
  status_output=$(chezmoi status 2>/dev/null || true)

  if [[ -z "$status_output" ]]; then
    ui_ok "Clean" "No drift to report"
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local status_code="${line:0:2}"
    local file_path="${line:3}"

    # Apply filter
    case "$filter" in
      critical)
        case "$file_path" in
          *.ssh/*|*/.gnupg/*|*secrets*|*.env|*credentials*|*token*) ;;
          *) continue ;;
        esac
        ;;
      warning)
        case "$file_path" in
          *.zshrc*|*.bashrc*|*.profile|*/shell/*|*/zsh/*) ;;
          *) continue ;;
        esac
        ;;
      safe)
        case "$file_path" in
          */.config/nvim/*|*/.config/git/*|*/.config/starship*|*/themes/*) ;;
          *) continue ;;
        esac
        ;;
    esac

    # Get remediation
    local remediation
    remediation=$(get_remediation "$status_code" "$file_path")
    eval "$remediation"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%sFile:%s %s\n" "$BOLD" "$NORMAL" "$file_path"
    printf "%sStatus:%s %s\n" "$BOLD" "$NORMAL" "$status_code"
    printf "%sAction:%s %s\n" "$BOLD" "$NORMAL" "$ACTION"
    printf "%sCommand:%s %s\n" "$BOLD" "$NORMAL" "$COMMAND"
    if [[ "$AUTO_SAFE" -eq 1 ]]; then
      printf "%sAuto-fix:%s Yes (safe to auto-remediate)\n" "$BOLD" "$NORMAL"
    fi
    echo ""

    # Show diff for modified files
    if [[ "$status_code" =~ M ]]; then
      echo "Diff preview:"
      chezmoi diff "$file_path" 2>/dev/null | head -20 || true
      echo ""
    fi

  done <<< "$status_output"
}

cmd_fix() {
  local mode="${1:-interactive}"

  ui_header "Drift Remediation"
  echo ""

  local status_output
  status_output=$(chezmoi status 2>/dev/null || true)

  if [[ -z "$status_output" ]]; then
    ui_ok "Clean" "No drift to fix"
    return 0
  fi

  local fixed=0
  local skipped=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local status_code="${line:0:2}"
    local file_path="${line:3}"

    # Get remediation
    local remediation
    remediation=$(get_remediation "$status_code" "$file_path")
    eval "$remediation"

    # Determine if we should auto-fix
    local should_fix=0

    case "$mode" in
      --safe|safe)
        # Only fix auto-safe items
        [[ "$AUTO_SAFE" -eq 1 ]] && should_fix=1
        ;;
      --all|all)
        # Fix everything except critical
        case "$file_path" in
          *.ssh/*|*/.gnupg/*|*secrets*|*.env|*credentials*|*token*)
            should_fix=0
            ;;
          *)
            should_fix=1
            ;;
        esac
        ;;
      --force|force)
        # Fix everything
        should_fix=1
        ;;
      interactive|*)
        # Interactive mode with gum if available
        if [[ "$UI_ENABLED" -eq 1 ]]; then
          echo ""
          printf "%sFile:%s %s\n" "$BOLD" "$NORMAL" "$file_path"
          printf "%sAction:%s %s\n" "$BOLD" "$NORMAL" "$ACTION"

          if gum confirm "Apply fix: $COMMAND"; then
            should_fix=1
          else
            should_fix=0
          fi
        else
          # Fallback: skip in non-interactive
          should_fix=0
        fi
        ;;
    esac

    if [[ "$should_fix" -eq 1 ]]; then
      # Apply the fix
      case "$status_code" in
        " A")
          # New in source, apply to target
          if chezmoi apply "$file_path" 2>/dev/null; then
            ui_ok "Fixed" "$file_path"
            ((fixed++))
          else
            ui_err "Failed" "$file_path"
          fi
          ;;
        "D ")
          # Deleted in target, restore
          if chezmoi apply "$file_path" 2>/dev/null; then
            ui_ok "Restored" "$file_path"
            ((fixed++))
          else
            ui_err "Failed" "$file_path"
          fi
          ;;
        "MM"|" M"|"M ")
          # Modified - apply source version
          if chezmoi apply "$file_path" 2>/dev/null; then
            ui_ok "Applied" "$file_path"
            ((fixed++))
          else
            ui_err "Failed" "$file_path"
          fi
          ;;
        *)
          ui_info "Skipped" "$file_path (manual review needed)"
          ((skipped++))
          ;;
      esac
    else
      ((skipped++))
    fi

  done <<< "$status_output"

  echo ""
  ui_section "Summary"
  ui_kv "Fixed:" "$fixed"
  ui_kv "Skipped:" "$skipped"

  if [[ $skipped -gt 0 ]]; then
    echo ""
    ui_info "Tip" "Run 'dot drift report' to review skipped files"
  fi
}

cmd_watch() {
  ui_header "Drift Watch Mode"
  echo ""
  ui_info "Monitoring" "Checking for drift every 60 seconds (Ctrl+C to stop)"
  echo ""

  while true; do
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local status_output
    status_output=$(chezmoi status 2>/dev/null || true)

    if [[ -z "$status_output" ]]; then
      printf "\r%s[%s]%s Clean - no drift detected" "$GREEN" "$timestamp" "$NORMAL"
    else
      local count
      count=$(echo "$status_output" | wc -l | tr -d ' ')
      printf "\r%s[%s]%s Drift detected: %d files changed" "$YELLOW" "$timestamp" "$NORMAL" "$count"

      # Log drift events
      mkdir -p "$(dirname "$DRIFT_LOG")"
      echo "[$timestamp] Drift detected: $count files" >> "$DRIFT_LOG"
    fi

    sleep 60
  done
}

# =============================================================================
# Help
# =============================================================================

show_help() {
  cat <<EOF
Usage: dot drift [COMMAND] [OPTIONS]

Smart drift detection with automatic remediation.

Commands:
  check       Analyze drift and show summary (default)
  report      Detailed report with remediation suggestions
  fix         Apply fixes to drifted files
  watch       Continuous monitoring mode

Options for 'report':
  --critical  Only show critical (security) files
  --warning   Only show warning (shell config) files
  --safe      Only show safe (low-risk) files

Options for 'fix':
  --safe      Only fix auto-safe changes
  --all       Fix all except critical files
  --force     Fix everything (use with caution!)
  (default)   Interactive mode with prompts

Examples:
  dot drift                    # Check for drift
  dot drift check              # Same as above
  dot drift report             # Full report with suggestions
  dot drift report --critical  # Only security-sensitive files
  dot drift fix --safe         # Auto-fix safe changes only
  dot drift fix                # Interactive fix mode
  dot drift watch              # Continuous monitoring

Severity Levels:
  Critical  Security files (.ssh, .gnupg, secrets)
  Warning   Shell configuration (.zshrc, .bashrc)
  Info      General configuration files
  Safe      Editor/tool configs (auto-fixable)
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
  local cmd="${1:-check}"
  shift || true

  case "$cmd" in
    -h|--help|help)
      show_help
      ;;
    check)
      cmd_check
      ;;
    report)
      cmd_report "$@"
      ;;
    fix)
      cmd_fix "$@"
      ;;
    watch)
      cmd_watch
      ;;
    *)
      echo "Unknown command: $cmd"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
