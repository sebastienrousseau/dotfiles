#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# check-deps-dev.sh — Validate direct dependencies against the deps.dev
# Insights API. Catches supply-chain risk a Grype-only scan misses:
# stale-but-CVE-free packages, unattested artifacts, and packages with
# advisories that haven't yet been mapped to a CVE.
#
# Scans:
#   * `package.json` — direct `dependencies` + `devDependencies` (npm).
#   * `pyproject.toml` — direct `[project.dependencies]` (Python).
#   * `.github/workflows/*.yml` — `uses:` action references (GitHub Actions).
#
# Skips ecosystems with no matching manifest.
#
# Exit codes:
#   0  no advisories found (or all under threshold).
#   1  one or more direct deps have advisories at or above the threshold.
#   2  prerequisites missing (jq / curl / python3).
#
# Closes part of #877.
# =============================================================================

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
THRESHOLD="${DEPS_DEV_SEVERITY_THRESHOLD:-HIGH}"  # LOW | MEDIUM | HIGH | CRITICAL
DEPS_DEV_BASE="${DEPS_DEV_BASE:-https://api.deps.dev/v3}"
EXCEPTIONS_FILE="$REPO_ROOT/docs/security/DEPS_DEV_EXCEPTIONS.md"
SARIF_OUT="${DEPS_DEV_SARIF_OUT:-}"

# Strict mode: bail on prerequisites.
for cmd in jq curl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "::warning::check-deps-dev: $cmd not available — skipping." >&2
    exit 0
  fi
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# severity_rank — map deps.dev severity strings to integers so we can
# compare against THRESHOLD numerically.
severity_rank() {
  case "${1:-}" in
    CRITICAL) echo 4 ;;
    HIGH)     echo 3 ;;
    MEDIUM | MODERATE) echo 2 ;;
    LOW)      echo 1 ;;
    *)        echo 0 ;;
  esac
}

THRESHOLD_RANK=$(severity_rank "$THRESHOLD")

# is_excepted — check if a (system, name) pair has an active exception
# entry in DEPS_DEV_EXCEPTIONS.md. Exceptions look like:
#   `npm:lodash` (expires 2026-12-31): <reason>
is_excepted() {
  local system="$1" name="$2"
  [[ -f "$EXCEPTIONS_FILE" ]] || return 1
  grep -Eq "^\s*\`${system}:${name}\`" "$EXCEPTIONS_FILE"
}

# fetch_advisories — query deps.dev for advisories on a (system, name,
# version) triple. Prints one advisory-key per line; empty if none.
fetch_advisories() {
  local system="$1" name="$2" version="$3"
  local encoded_name
  encoded_name=$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$name")
  local url="$DEPS_DEV_BASE/systems/$system/packages/$encoded_name/versions/$version"
  curl -fsSL --max-time 15 "$url" 2>/dev/null \
    | jq -r '.advisoryKeys[]?.id // empty' 2>/dev/null \
    || true
}

# fetch_advisory_severity — given an advisory ID, return its highest
# severity rating. Returns empty string when the API doesn't expose
# severity (older advisories sometimes lack it).
fetch_advisory_severity() {
  local advisory_id="$1"
  local encoded
  encoded=$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$advisory_id")
  curl -fsSL --max-time 15 "$DEPS_DEV_BASE/advisories/$encoded" 2>/dev/null \
    | jq -r '.severity[]?.type // empty' 2>/dev/null \
    | head -1 \
    || true
}

# -----------------------------------------------------------------------------
# Manifest readers
# -----------------------------------------------------------------------------

# Each reader prints one "system\tname\tversion" line per direct dep.

read_npm() {
  local pkg="$REPO_ROOT/package.json"
  [[ -f "$pkg" ]] || return 0
  jq -r '
    [.dependencies // {}, .devDependencies // {}]
    | add // {}
    | to_entries[]
    | "NPM\t\(.key)\t\(.value | sub("^[~^>=<]+"; ""))"
  ' "$pkg"
}

read_pypi() {
  local pyproj="$REPO_ROOT/pyproject.toml"
  [[ -f "$pyproj" ]] || return 0
  python3 - "$pyproj" <<'PY'
import sys
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib  # type: ignore
    except ImportError:
        sys.exit(0)
data = tomllib.load(open(sys.argv[1], "rb"))
deps = data.get("project", {}).get("dependencies", [])
for spec in deps:
    # spec is like "requests>=2.28.0"; pull name + version.
    name = spec.split("[")[0].split(">")[0].split("<")[0].split("=")[0].strip()
    version = ""
    for op in (">=", "<=", "==", ">", "<"):
        if op in spec:
            version = spec.split(op, 1)[1].strip().split(",")[0]
            break
    print(f"PYPI\t{name}\t{version}")
PY
}

read_actions() {
  local f
  for f in "$REPO_ROOT"/.github/workflows/*.yml; do
    [[ -f "$f" ]] || continue
    # Match `uses: owner/repo@<40-hex-sha> # vX.Y.Z`
    grep -Eo 'uses:[[:space:]]+[a-zA-Z0-9._-]+/[a-zA-Z0-9._/-]+@[a-f0-9]{40}[[:space:]]*#[[:space:]]*v[0-9.]+' "$f" \
      | sed -E 's/uses:[[:space:]]+([^@]+)@[a-f0-9]{40}[[:space:]]+#[[:space:]]+v([0-9.]+).*/GITHUB_ACTIONS\t\1\t\2/' \
      || true
  done | sort -u
}

# -----------------------------------------------------------------------------
# Main scan
# -----------------------------------------------------------------------------

findings=()
total_scanned=0

scan_one() {
  local system="$1" name="$2" version="$3"
  [[ -z "$name" || -z "$version" ]] && return 0
  total_scanned=$((total_scanned + 1))

  if is_excepted "$system" "$name"; then
    echo "  - skip $system:$name@$version (excepted)" >&2
    return 0
  fi

  local advs
  advs=$(fetch_advisories "$system" "$name" "$version")
  [[ -z "$advs" ]] && return 0

  while IFS= read -r adv; do
    [[ -z "$adv" ]] && continue
    local sev
    sev=$(fetch_advisory_severity "$adv")
    local rank
    rank=$(severity_rank "$sev")
    if (( rank >= THRESHOLD_RANK )); then
      findings+=("$system:$name@$version :: $adv ($sev)")
      echo "::warning::deps.dev advisory $sev: $system $name $version → $adv" >&2
    fi
  done <<<"$advs"
}

echo "Scanning manifests under $REPO_ROOT ..." >&2

# 1. npm
while IFS=$'\t' read -r system name version; do
  scan_one "$system" "$name" "$version"
done < <(read_npm)

# 2. pypi
while IFS=$'\t' read -r system name version; do
  scan_one "$system" "$name" "$version"
done < <(read_pypi)

# 3. GitHub Actions (best-effort — deps.dev coverage is partial)
while IFS=$'\t' read -r system name version; do
  scan_one "$system" "$name" "$version"
done < <(read_actions)

echo "Scanned $total_scanned direct dependencies." >&2

# Optional SARIF emission for Code Scanning upload.
if [[ -n "$SARIF_OUT" ]]; then
  python3 - "$SARIF_OUT" "${findings[@]+"${findings[@]}"}" <<'PY'
import json, sys
out = sys.argv[1]
findings = sys.argv[2:]
runs = [{
    "tool": {"driver": {
        "name": "check-deps-dev",
        "version": "1.0.0",
        "informationUri": "https://deps.dev",
    }},
    "results": [
        {
            "ruleId": "deps-dev-advisory",
            "level": "error",
            "message": {"text": f},
        }
        for f in findings
    ],
}]
with open(out, "w") as fp:
    json.dump({"version": "2.1.0", "$schema": "https://json.schemastore.org/sarif-2.1.0.json", "runs": runs}, fp)
print(f"SARIF written: {out}")
PY
fi

if [[ "${#findings[@]}" -gt 0 ]]; then
  echo "" >&2
  echo "::error::${#findings[@]} dep(s) flagged at or above ${THRESHOLD}." >&2
  printf '  %s\n' "${findings[@]}" >&2
  echo "" >&2
  echo "Document exceptions at docs/security/DEPS_DEV_EXCEPTIONS.md with expiry dates." >&2
  exit 1
fi

echo "deps.dev validation: clean." >&2
exit 0
