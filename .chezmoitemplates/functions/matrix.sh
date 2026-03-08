# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Description:
#   matrix is a wrapper around cmatrix with a bash fallback for terminals
#   without cmatrix installed. Supports color themes and speed options.
#
################################################################################

VERSION="2.0.0"

show_help() {
  cat <<'EOH'
Matrix Effect Generator (matrix)

Usage:
  matrix [options]

Options:
  --color <name>       green (default), purple, red, blue, white, yellow
  --rainbow            Rainbow color effect
  --slow               Reduce animation speed
  --fast               Increase animation speed
  --help               Display this help menu
  --version            Display version information

Press 'q' or Ctrl+C to exit.
EOH
}

show_version() {
  echo "Matrix Effect Generator v${VERSION}"
}

matrix() {
  case "${1:-}" in
    --help)
      show_help
      return 0
      ;;
    --version)
      show_version
      return 0
      ;;
  esac

  local color="green" speed="" rainbow=false bold="-b"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --color)
        color="${2:-green}"
        shift 2
        ;;
      --rainbow)
        rainbow=true
        shift
        ;;
      --slow)
        speed="-u 8"
        shift
        ;;
      --fast)
        speed="-u 2"
        shift
        ;;
      *)
        echo "Unknown option: '$1'" >&2
        return 1
        ;;
    esac
  done

  # Prefer cmatrix if available — native C, smooth, proper signal handling
  if command -v cmatrix >/dev/null 2>&1; then
    local cmatrix_args=($bold $speed)
    if $rainbow; then
      cmatrix_args+=("-r")
    else
      case "$color" in
        green) cmatrix_args+=("-C" "green") ;;
        purple | magenta) cmatrix_args+=("-C" "magenta") ;;
        red) cmatrix_args+=("-C" "red") ;;
        blue) cmatrix_args+=("-C" "blue") ;;
        white) cmatrix_args+=("-C" "white") ;;
        yellow) cmatrix_args+=("-C" "yellow") ;;
      esac
    fi
    # Query terminal's actual background color via OSC 11 and remap
    # ANSI color 0 to match, so ncurses uses the real background
    # (preserving transparency if the terminal supports it).
    local _bg=""
    if printf '\e]11;?\e\\' >/dev/tty 2>/dev/null; then
      IFS= read -rs -t 0.1 -d $'\\' _bg </dev/tty 2>/dev/null || true
      _bg="${_bg##*rgb:}"
      [[ -n "$_bg" ]] && printf '\e]4;0;rgb:%s\e\\' "$_bg"
    fi
    cmatrix "${cmatrix_args[@]}"
    local rc=$?
    printf '\e]104;0\e\\' # Restore color 0 to terminal default
    return $rc
  fi

  # Fallback: bash + awk implementation
  local MATRIX_COLORS
  declare -A MATRIX_COLORS=(
    [green]='\033[38;5;46m' [purple]='\033[38;5;55m'
    [red]='\033[38;5;196m' [blue]='\033[38;5;33m'
    [white]='\033[38;5;15m' [yellow]='\033[38;5;226m'
  )
  local esc_color="${MATRIX_COLORS[$color]:-${MATRIX_COLORS[green]}}"
  local sleep_val=0.04
  [[ -n "$speed" ]] && case "$speed" in *8*) sleep_val=0.08 ;; *2*) sleep_val=0.02 ;; esac

  local _awk_script
  if $rainbow; then
    # shellcheck disable=SC2016
    _awk_script='{
      letters="日ﾊﾐﾋｰｳｼﾅﾐﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ";
      c=$4; if (c <= 0 || c > length(letters)) next;
      letter=substr(letters, c, 1); a[$3] = 0;
      for (x in a) {
        o = a[x]; a[x]++;
        rc = "\033[38;5;" int(rand() * 255) "m";
        if (o > 0 && x > 0) {
          printf "\033[%d;%dH%s%s%s", o, x, rc, letter, reset;
          printf "\033[%d;%dH%s%s%s", a[x], x, reset, letter, reset;
        }
        if (a[x] >= $1) a[x] = 0;
      }
    }'
  else
    # shellcheck disable=SC2016
    _awk_script='{
      letters="日ﾊﾐﾋｰｳｼﾅﾐﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ";
      c=$4; if (c <= 0 || c > length(letters)) next;
      letter=substr(letters, c, 1); a[$3] = 0;
      for (x in a) {
        o = a[x]; a[x]++;
        if (o > 0 && x > 0) {
          printf "\033[%d;%dH%s%s%s", o, x, color, letter, reset;
          printf "\033[%d;%dH%s%s%s", a[x], x, reset, letter, reset;
        }
        if (a[x] >= $1) a[x] = 0;
      }
    }'
  fi

  (
    _matrix_cleanup() {
      printf '\e[?25h'
      tput cnorm 2>/dev/null
      tput rmcup 2>/dev/null
    }
    trap '_matrix_cleanup' EXIT

    tput smcup
    printf '\e[?25l\e[0m'
    clear

    local _cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    local _rows=${LINES:-$(tput lines 2>/dev/null || echo 40)}

    # 'q' key listener — reads directly from terminal
    { while IFS= read -rsn1 _k </dev/tty 2>/dev/null; do
      [[ "$_k" == "q" || "$_k" == "Q" ]] && kill $$ 2>/dev/null && break
    done; } &

    while true; do
      echo "$_rows $_cols $((RANDOM % _cols)) $((RANDOM % 72))"
      sleep "$sleep_val"
    done | awk -v color="$esc_color" -v reset='\033[0m' "$_awk_script"
  )
}
