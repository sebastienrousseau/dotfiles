#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
install -m 0755 "${repo_root}/scripts/git-hooks/pre-push" "${repo_root}/.git/hooks/pre-push"
echo "Installed pre-push hook at ${repo_root}/.git/hooks/pre-push"
