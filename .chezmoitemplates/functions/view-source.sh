# shellcheck shell=bash
# view-source: Function to view the source of a website.
view-source() {
  if ! command -v curl &>/dev/null; then
    echo "[ERROR] curl is required but not installed." >&2
    return 1
  fi
  curl --connect-timeout 10 --max-time 120 -L -k -A 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:25.0) Gecko/20100101 Firefox/25.0' "$@"
}
