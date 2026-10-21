#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Generate share/man/man1/dot.1 and one dot-<domain>.1 per domain from the
# plugin manifests (ADR-020, N0.4) with tools/docs/gen_manpages.py. The
# commands come from lib/dot/data/commands.txt, the family flags and exit
# codes from schemas/cli/flags.json, and the prose of dot(1) from
# tools/docs/man/dot.1.in. The .TH date is the date of the top CHANGELOG
# heading so the output is reproducible.
#
# Usage:
#   tools/docs/generate-manpage.sh                # write share/man/man1/dot*.1
#   tools/docs/generate-manpage.sh --check        # exit 1 if a committed page is stale
#   tools/docs/generate-manpage.sh --output FILE  # write dot.1 as FILE, the domain pages beside it
#
# Exit codes:
#   0  pages written / already in sync
#   1  --check mode and drift detected
#   2  bad usage
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

case "${1:-}" in
  "") exec python3 tools/docs/gen_manpages.py ;;
  --check)
    if python3 tools/docs/gen_manpages.py --check; then
      echo "share/man/man1 is in sync"
      exit 0
    fi
    exit 1
    ;;
  --output)
    [[ $# -ge 2 ]] || {
      echo "--output needs a path" >&2
      exit 2
    }
    out_dir="$(dirname "$2")"
    python3 tools/docs/gen_manpages.py --outdir "$out_dir"
    [[ "$(basename "$2")" == dot.1 ]] || mv "$out_dir/dot.1" "$2"
    ;;
  -h | --help) sed -n '5,20p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)
    echo "unknown flag: $1" >&2
    exit 2
    ;;
esac
