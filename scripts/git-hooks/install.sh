#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
install -m 0755 "${repo_root}/scripts/git-hooks/pre-commit" "${repo_root}/.git/hooks/pre-commit"
install -m 0755 "${repo_root}/scripts/git-hooks/pre-push" "${repo_root}/.git/hooks/pre-push"
install -m 0755 "${repo_root}/scripts/git-hooks/prepare-commit-msg" "${repo_root}/.git/hooks/prepare-commit-msg"
echo "Installed pre-commit hook at ${repo_root}/.git/hooks/pre-commit"
echo "Installed pre-push hook at ${repo_root}/.git/hooks/pre-push"
echo "Installed prepare-commit-msg hook at ${repo_root}/.git/hooks/prepare-commit-msg"
