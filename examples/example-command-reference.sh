#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Complete dot command reference — one usage line per public
# command/subcommand. The list lives in examples/command-reference.txt,
# generated from lib/dot/data/help-specs.txt by
# tools/docs/generate-command-reference.sh (CI checks it is current).
set -euo pipefail

cat "$(dirname "${BASH_SOURCE[0]}")/command-reference.txt"
printf '\nCommand reference example complete.\n'
