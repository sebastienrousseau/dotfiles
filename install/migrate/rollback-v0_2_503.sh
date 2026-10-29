#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# rollback-v0_2_503.sh: retired. It was meant to revert the v0.2.503
# migration, but it never worked: it read a "current ver:" snapshot line
# the migration never writes, and it expected `chezmoi source-path` to be
# the git checkout, which under .chezmoiroot it is not (it is defaults/).
# It now changes nothing and prints the manual recovery instead.

set -euo pipefail

cat >&2 <<'EOF'
[rollback] ERROR automatic rollback of the v0.2.503 migration is no longer supported.
[rollback] To go back to v0.2.502 by hand:
[rollback]   cd ~/.dotfiles
[rollback]   git fetch --tags origin
[rollback]   git checkout v0.2.502
[rollback]   chezmoi apply
[rollback] See install/migrate/README.md (Rollback).
EOF
exit 1
