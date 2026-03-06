#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# shellcheck disable=SC2034,SC1091,SC2207
# =============================================================================
# Coverage Analyzer for Shell Scripts
# Tracks line and branch coverage without external tools
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COVERAGE_DIR="$REPO_ROOT/.coverage"

# Coverage tracking globals
declare -A LINE_COVERAGE=()
declare -A BRANCH_COVERAGE=()
declare -A FUNCTION_COVERAGE=()
declare -a COVERED_LINES=()
declare -a TOTAL_LINES=()

# Initialize coverage directory
init_coverage() {
  mkdir -p "$COVERAGE_DIR"
  >"$COVERAGE_DIR/line_coverage.log"
  >"$COVERAGE_DIR/branch_coverage.log"
  >"$COVERAGE_DIR/function_coverage.log"
}

# Instrument a script for coverage tracking
instrument_script() {
  local script_path="$1"
  local instrumented_path="${script_path}.instrumented"

  if [[ ! -f "$script_path" ]]; then
    echo "Error: Script not found: $script_path" >&2
    return 1
  fi

  echo "Instrumenting: $script_path"

  # Create instrumented version with coverage tracking
  {
    echo '#!/usr/bin/env bash'
    echo '# INSTRUMENTED VERSION FOR COVERAGE'
    echo "COVERAGE_LOG=\"$COVERAGE_DIR/line_coverage.log\""
    # Single quotes intentional: output literal shell code
    # shellcheck disable=SC2016
    echo 'track_line() { echo "$(basename "$1"):$2" >> "$COVERAGE_LOG"; }'
    echo 'track_branch() { echo "$(basename "$1"):$2:$3" >> "$COVERAGE_DIR/branch_coverage.log"; }'
    echo 'track_function() { echo "$(basename "$1"):$2" >> "$COVERAGE_DIR/function_coverage.log"; }'
    echo

    # Process original script line by line
    local line_num=0
    while IFS= read -r line; do
      ((line_num++))

      # Skip shebang and comments for first few lines
      if [[ $line_num -le 3 && ($line =~ ^#!/ || $line =~ ^[[:space:]]*#) ]]; then
        [[ $line_num -gt 1 ]] && echo "$line"
        continue
      fi

      # Add tracking for executable lines
      if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        # Empty lines and comments - no instrumentation
        echo "$line"
      elif [[ "$line" =~ ^[[:space:]]*if ]] || [[ "$line" =~ ^[[:space:]]*elif ]]; then
        # Branch conditions
        echo "track_line \"$script_path\" $line_num; track_branch \"$script_path\" $line_num \"condition\"; $line"
      elif [[ "$line" =~ ^[[:space:]]*else ]] || [[ "$line" =~ ^[[:space:]]*fi ]] || [[ "$line" =~ ^[[:space:]]*done ]]; then
        # Branch endpoints
        echo "track_line \"$script_path\" $line_num; track_branch \"$script_path\" $line_num \"endpoint\"; $line"
      elif [[ "$line" =~ ^[[:space:]]*function[[:space:]].*\(\)|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{ ]]; then
        # Function definitions
        local func_name
        func_name=$(echo "$line" | sed -E 's/.*function[[:space:]]+([^[:space:](]+).*/\1/; s/.*([a-zA-Z_][a-zA-Z0-9_]*)\(\).*/\1/')
        echo "track_line \"$script_path\" $line_num; track_function \"$script_path\" \"$func_name\"; $line"
      else
        # Regular executable lines
        echo "track_line \"$script_path\" $line_num; $line"
      fi
    done <"$script_path"
  } >"$instrumented_path"

  chmod +x "$instrumented_path"
  echo "Created instrumented version: $instrumented_path"
}

# Analyze coverage data
analyze_coverage() {
  local script_path="$1"
  local script_name
  script_name="$(basename "$script_path")"

  if [[ ! -f "$COVERAGE_DIR/line_coverage.log" ]]; then
    echo "No coverage data found. Run tests with instrumented scripts first."
    return 1
  fi

  echo "Coverage Analysis for: $script_name"
  echo "========================================"

  # Count total lines in script
  local total_lines
  total_lines=$(grep -c '^' "$script_path" || echo "0")

  # Count executable lines (non-empty, non-comment after line 3)
  local executable_lines
  executable_lines=$(awk 'NR > 3 && !/^[[:space:]]*$/ && !/^[[:space:]]*#/ { count++ } END { print count+0 }' "$script_path")

  # Count covered lines
  local covered_lines
  covered_lines=$(grep "^$script_name:" "$COVERAGE_DIR/line_coverage.log" 2>/dev/null | sort -u | wc -l || echo "0")

  # Calculate coverage percentage
  local coverage_percentage
  if [[ $executable_lines -gt 0 ]]; then
    coverage_percentage=$((covered_lines * 100 / executable_lines))
  else
    coverage_percentage=0
  fi

  echo "Total lines: $total_lines"
  echo "Executable lines: $executable_lines"
  echo "Covered lines: $covered_lines"
  echo "Coverage: $coverage_percentage%"
  echo

  # Function coverage
  if [[ -f "$COVERAGE_DIR/function_coverage.log" ]]; then
    local functions_covered
    functions_covered=$(grep "^$script_name:" "$COVERAGE_DIR/function_coverage.log" 2>/dev/null | cut -d: -f2 | sort -u | wc -l || echo "0")
    echo "Functions covered: $functions_covered"
  fi

  # Branch coverage
  if [[ -f "$COVERAGE_DIR/branch_coverage.log" ]]; then
    local branches_covered
    branches_covered=$(grep "^$script_name:" "$COVERAGE_DIR/branch_coverage.log" 2>/dev/null | sort -u | wc -l || echo "0")
    echo "Branches covered: $branches_covered"
  fi

  echo

  # Store coverage percentage for caller (exit codes are limited to 0-255)
  _COVERAGE_RESULT=$coverage_percentage
}

# Generate coverage report for multiple scripts
generate_report() {
  local scripts=("$@")
  local total_coverage=0 script_count=0

  echo "DOTFILES COVERAGE REPORT"
  echo "========================"
  echo "Generated: $(date)"
  echo

  for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
      analyze_coverage "$script"
      local script_coverage=$_COVERAGE_RESULT
      total_coverage=$((total_coverage + script_coverage))
      ((script_count++))
      echo "----------------------------------------"
    fi
  done

  if [[ $script_count -gt 0 ]]; then
    local average_coverage=$((total_coverage / script_count))
    echo
    echo "SUMMARY"
    echo "======="
    echo "Scripts analyzed: $script_count"
    echo "Average coverage: $average_coverage%"

    # Set exit code based on coverage target
    if [[ $average_coverage -ge 90 ]]; then
      echo "✓ Coverage target met (≥90%)"
      return 0
    elif [[ $average_coverage -ge 75 ]]; then
      echo "⚠ Coverage below target (75-89%)"
      return 1
    else
      echo "✗ Coverage critically low (<75%)"
      return 2
    fi
  fi
}

# Find uncovered lines in a script
find_uncovered() {
  local script_path="$1"
  local script_name
  script_name="$(basename "$script_path")"

  echo "Uncovered lines in $script_name:"
  echo "================================"

  local line_num=0
  while IFS= read -r line; do
    ((line_num++))

    # Skip first 3 lines and non-executable lines
    if [[ $line_num -le 3 ]] || [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Check if line was covered
    if ! grep -q "^$script_name:$line_num\$" "$COVERAGE_DIR/line_coverage.log" 2>/dev/null; then
      printf "%4d: %s\n" "$line_num" "$line"
    fi
  done <"$script_path"
}

# Main function
main() {
  case "${1:-}" in
    "init")
      init_coverage
      echo "Coverage tracking initialized"
      ;;
    "instrument")
      if [[ $# -ne 2 ]]; then
        echo "Usage: $0 instrument <script_path>"
        exit 1
      fi
      instrument_script "$2"
      ;;
    "analyze")
      if [[ $# -ne 2 ]]; then
        echo "Usage: $0 analyze <script_path>"
        exit 1
      fi
      analyze_coverage "$2"
      ;;
    "report")
      shift
      generate_report "$@"
      ;;
    "uncovered")
      if [[ $# -ne 2 ]]; then
        echo "Usage: $0 uncovered <script_path>"
        exit 1
      fi
      find_uncovered "$2"
      ;;
    "clean")
      rm -rf "$COVERAGE_DIR"
      echo "Coverage data cleaned"
      ;;
    "threshold")
      # Check if coverage meets threshold (for CI integration)
      local threshold="${COVERAGE_THRESHOLD:-100}"
      echo "Checking coverage against threshold: ${threshold}%"

      # Find all shell scripts to analyze
      local scripts=()
      mapfile -t scripts < <(find "$REPO_ROOT" -name "*.sh" -type f ! -path "*/.*" ! -path "*/coverage/*" ! -name "*.instrumented")

      if [[ ${#scripts[@]} -eq 0 ]]; then
        echo "No shell scripts found to analyze"
        exit 0
      fi

      # Run coverage analysis
      local total_coverage=0 script_count=0 failed_count=0
      for script in "${scripts[@]}"; do
        if analyze_coverage "$script"; then
          local script_coverage=$_COVERAGE_RESULT
          total_coverage=$((total_coverage + script_coverage))
          ((script_count++))
          if [[ $script_coverage -lt $threshold ]]; then
            ((failed_count++))
            echo "❌ $(basename "$script"): ${script_coverage}% < ${threshold}%"
          else
            echo "✅ $(basename "$script"): ${script_coverage}% >= ${threshold}%"
          fi
        fi
      done

      if [[ $script_count -gt 0 ]]; then
        local average_coverage=$((total_coverage / script_count))
        echo ""
        echo "Coverage Summary:"
        echo "=================="
        echo "Scripts analyzed: $script_count"
        echo "Average coverage: ${average_coverage}%"
        echo "Threshold: ${threshold}%"
        echo "Failed scripts: $failed_count"

        if [[ $average_coverage -ge $threshold && $failed_count -eq 0 ]]; then
          echo ""
          echo "✅ COVERAGE PASSED: All scripts meet ${threshold}% threshold"
          exit 0
        else
          echo ""
          echo "❌ COVERAGE FAILED: ${failed_count} scripts below ${threshold}% threshold"
          echo "   Average: ${average_coverage}% (required: ${threshold}%)"
          exit 1
        fi
      else
        echo "No scripts could be analyzed"
        exit 1
      fi
      ;;
    *)
      echo "Coverage Analyzer for Shell Scripts"
      echo
      echo "Usage: $0 <command> [args...]"
      echo
      echo "Commands:"
      echo "  init                   Initialize coverage tracking"
      echo "  instrument <script>    Create instrumented version of script"
      echo "  analyze <script>       Analyze coverage for script"
      echo "  report <scripts...>    Generate coverage report for multiple scripts"
      echo "  uncovered <script>     Show uncovered lines in script"
      echo "  threshold              Check coverage against COVERAGE_THRESHOLD (default: 100%)"
      echo "  clean                  Clean coverage data"
      echo
      echo "Environment Variables:"
      echo "  COVERAGE_THRESHOLD     Coverage percentage required (default: 100)"
      echo
      echo "Example workflow:"
      echo "  $0 init"
      echo "  $0 instrument scripts/backup.sh"
      echo "  # Run tests using instrumented version"
      echo "  $0 analyze scripts/backup.sh"
      echo "  COVERAGE_THRESHOLD=90 $0 threshold"
      ;;
  esac
}

main "$@"
