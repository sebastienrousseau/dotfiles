#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/security/remote-installers.sha256"
failed=0

while read -r checksum url extra; do
  [[ -n "${checksum:-}" && "${checksum:0:1}" != "#" ]] || continue
  if [[ ! "$checksum" =~ ^[0-9a-f]{64}$ || -z "${url:-}" || -n "${extra:-}" ]]; then
    printf 'Invalid installer manifest entry: %s %s %s\n' "$checksum" "${url:-}" "${extra:-}" >&2
    failed=1
    continue
  fi
  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    case "$match" in
      *security/remote-installers.sha256* | *download_verified_script*) ;;
      *)
        printf 'Remote installer bypasses checksum verifier: %s\n' "$match" >&2
        failed=1
        ;;
    esac
  done < <(rg --no-config -n -F "$url" "$repo_root" --glob '*.sh' --glob '*.tmpl' --glob '!tests/**' --glob '!docs/**' || true)
done <"$manifest"

# No executable shell path may stream downloaded bytes into an interpreter.
if rg --no-config -n '^[[:space:]]*(curl|wget)[^#|]*\|[[:space:]]*(ba)?sh' "$repo_root" --glob '*.sh' --glob '*.tmpl' --glob '!tests/**' --glob '!docs/**' --glob '!tools/ci/check-remote-installers.sh'; then
  printf 'Direct download-to-shell execution is forbidden.\n' >&2
  failed=1
fi

exit "$failed"
