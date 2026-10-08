#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau

set -euo pipefail

# ripgrep does the scanning; without it every check would silently pass.
command -v rg >/dev/null 2>&1 || {
  printf 'check-remote-installers: ripgrep (rg) is required\n' >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/security/remote-installers.sha256"
# Globs below are relative to the search root, so search from the repo root.
cd "$repo_root"
failed=0

# Files that can run a download: shell, templates, CI YAML and Dockerfiles.
# --hidden reaches .github/ and .devcontainer/. Tests and docs only describe,
# except the Dockerfiles under tests/, which CI builds.
scan_globs=(--hidden --glob '*.sh' --glob '*.tmpl' --glob '*.yml' --glob '*.yaml'
  --glob 'Dockerfile*' --glob '!.git/**' --glob '!tests/**' --glob '!docs/**'
  --glob 'tests/**/Dockerfile*' --glob '!**/tools/ci/check-remote-installers.sh')

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
  done < <(rg --no-config -n -F "$url" . "${scan_globs[@]}" || true)
done <"$manifest"

# No executable path may hand downloaded bytes to an interpreter: piped
# (`curl | sh`, also after a YAML `run:` or Dockerfile `RUN`), command
# substitution (`sh -c "$(curl`) or process substitution (`bash <(curl`).
lead='^[[:space:]]*((-[[:space:]]*)?run:[[:space:]]*[|>]?[[:space:]]*|RUN[[:space:]]+)?'
pipe="${lead}(curl|wget)[^#|]*\\|[[:space:]]*(sudo[[:space:]]+)?(bash|zsh|sh)([[:space:]]|\$)"
subst='(bash|zsh|sh)[[:space:]]+-c[[:space:]]+["'"'"']?\$\([[:space:]]*(curl|wget)'
procsub='(bash|zsh|sh)[[:space:]]+<\([[:space:]]*(curl|wget)'
if rg --no-config -n -e "$pipe" -e "$subst" -e "$procsub" . "${scan_globs[@]}"; then
  printf 'Direct download-to-shell execution is forbidden.\n' >&2
  failed=1
fi

exit "$failed"
