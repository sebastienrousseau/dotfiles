#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/dot/lib/platform.sh
source "$repo_root/scripts/dot/lib/platform.sh"

printf 'Platform: %s\n' "$(dot_platform_id)"
printf 'Host OS: %s\n' "$(dot_host_os)"
