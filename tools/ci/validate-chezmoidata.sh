#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Validate .chezmoidata.toml against config/chezmoidata.schema.json via taplo.
#
# Usage:
#   bash tools/ci/validate-chezmoidata.sh
#
# In CI the workflow installs taplo before invoking this script. Locally,
# install via: cargo install --locked taplo-cli  (or `brew install taplo`).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

if ! command -v taplo >/dev/null 2>&1; then
  echo "error: taplo not found in PATH" >&2
  echo "  install: cargo install --locked taplo-cli" >&2
  echo "      or: brew install taplo" >&2
  exit 127
fi

# `taplo check` reads config/taplo.toml (v0.2.503: moved out of root),
# applies the schema rule, and reports schema violations + TOML syntax errors.
taplo check --config config/taplo.toml
