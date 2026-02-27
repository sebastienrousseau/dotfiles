# shellcheck shell=bash
# Logging Utilities

# Colors (respect NO_COLOR: https://no-color.org)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() {
  printf '%b\n' "${BLUE}[INFO]${NC} $1"
}

log_success() {
  printf '%b\n' "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  printf '%b\n' "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  printf '%b\n' "${RED}[ERROR]${NC} $1" >&2
}
