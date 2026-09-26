#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2015,SC2016
# Security and compliance controls, exercised rather than grepped:
#
#   * defaults/dot_gitconfig.tmpl is rendered by the real chezmoi and handed
#     to git, which must refuse to merge an unsigned commit and accept one
#     signed by a key in the managed allowed_signers file.
#   * defaults/dot_config/git/allowed_signers.tmpl is rendered and every
#     entry is parsed by ssh-keygen.
#   * install/lib/package_managers.sh install_homebrew runs against a
#     stubbed curl: the pinned installer URL is fetched, a tampered payload
#     is refused, the genuine checksum runs the installer.
#   * tools/release/package-policy-bundles.sh builds a bundle in a sandbox.
#   * scripts/diagnostics/mcp-doctor.sh enforces the shipped MCP policy,
#     package lock and pins against the shipped config and tampered copies.
#
# HOME, XDG_* and every output live in a mktemp sandbox. The GitHub workflow
# checks at the end read YAML that cannot be executed outside Actions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="${BASH:-$(command -v bash)}"
CHEZMOI_BIN="$(command -v chezmoi 2>/dev/null || true)"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/security-controls.XXXXXX")" && pwd)"
trap 'rm -rf "$WORK"' EXIT
SANDBOX_HOME="$WORK/home"
mkdir -p "$SANDBOX_HOME/.config/git" "$SANDBOX_HOME/.ssh" "$WORK/stubs"
OUT="$WORK/out"
ERR="$WORK/err"

update_deps_workflow="$REPO_ROOT/.github/workflows/update-deps.yml"
sync_versions_workflow="$REPO_ROOT/.github/workflows/sync-versions.yml"
security_workflow="$REPO_ROOT/.github/workflows/security-enhanced.yml"
reliability_workflow="$REPO_ROOT/.github/workflows/reliability-gate.yml"
policy_release_workflow="$REPO_ROOT/.github/workflows/policy-bundle-release.yml"
flake_lock_file="$REPO_ROOT/flake.lock"
soup_register_file="$REPO_ROOT/docs/security/SOUP_REGISTER.md"
automation_secrets_file="$REPO_ROOT/docs/security/AUTOMATION_SECRETS.md"

pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $1"
}
fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}
refute_contains() { # <needle> <actual> <msg>
  if [[ "$2" != *"$1"* ]]; then pass "$3"; else fail "$3 (found '$1')"; fi
}

# sandboxed <cmd…> — run with only the sandbox HOME and the system PATH.
sandboxed() {
  command env -i HOME="$SANDBOX_HOME" PATH="$WORK/stubs:/usr/bin:/bin:/usr/sbin:/sbin:$(dirname "$(command -v jq)")" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" XDG_CACHE_HOME="$SANDBOX_HOME/.cache" \
    XDG_DATA_HOME="$SANDBOX_HOME/.local/share" XDG_STATE_HOME="$SANDBOX_HOME/.local/state" \
    GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1 TERM=dumb DOTFILES_SHOW_LOGO=0 LANG=C "$@"
}

# render <template> <output> <chezmoi data JSON> — the real chezmoi renderer
# against the repository source, with every state path in the sandbox.
render() {
  printf '{"data":%s}\n' "$3" >"$WORK/chezmoi.json"
  sandboxed "$CHEZMOI_BIN" --config "$WORK/chezmoi.json" --source "$REPO_ROOT" \
    --destination "$WORK/chezmoi-dest" --cache "$WORK/chezmoi-cache" \
    --persistent-state "$WORK/chezmoi-state.boltdb" \
    execute-template <"$1" >"$2" 2>"$WORK/render.err"
}

# ===========================================================================
# Git signing policy (rendered gitconfig + allowed_signers)
# ===========================================================================
if [[ -z "$CHEZMOI_BIN" ]]; then
  echo "  - chezmoi not installed: skipping the rendered git signing checks"
else
  ssh-keygen -q -t ed25519 -N '' -C signer -f "$SANDBOX_HOME/.ssh/signing" >/dev/null
  git_data="$(printf '{"git_name":"Fixture","git_email":"fixture@example.com","git_signingkey":"%s"}' \
    "$SANDBOX_HOME/.ssh/signing")"

  test_start "git_template_renders_for_a_signing_identity"
  render "$REPO_ROOT/defaults/dot_gitconfig.tmpl" "$SANDBOX_HOME/.gitconfig" "$git_data"
  assert_equals "0" "$?" "dot_gitconfig.tmpl renders: $(cat "$WORK/render.err")"

  test_start "git_template_points_to_allowed_signers"
  assert_equals "$SANDBOX_HOME/.config/git/allowed_signers" \
    "$(sandboxed git config --global --get gpg.ssh.allowedSignersFile)" \
    "git reads the managed allowed_signers path under the home directory"
  assert_equals "ssh" "$(sandboxed git config --global --get gpg.format)" "commits are signed with SSH"

  test_start "git_template_enforces_merge_signature_verification"
  assert_equals "true" "$(sandboxed git config --global --type=bool --get merge.verifySignatures)" \
    "git reports merge.verifySignatures=true"
  repo="$WORK/repo"
  sandboxed git init -q -b main "$repo"
  sandboxed git -C "$repo" commit -q --allow-empty --no-gpg-sign -m base
  sandboxed git -C "$repo" switch -q -c unsigned
  sandboxed git -C "$repo" commit -q --allow-empty --no-gpg-sign -m "unsigned change"
  sandboxed git -C "$repo" switch -q main
  if sandboxed git -C "$repo" merge -q --ff-only unsigned >"$OUT" 2>&1; then
    fail "an unsigned commit was merged"
  else
    pass "an unsigned commit is refused"
  fi
  assert_contains "signature" "$(cat "$OUT")" "the refusal is about the missing signature"

  printf 'fixture@example.com %s\n' "$(cut -d' ' -f1,2 "$SANDBOX_HOME/.ssh/signing.pub")" \
    >"$SANDBOX_HOME/.config/git/allowed_signers"
  sandboxed git -C "$repo" switch -q -c signed
  sandboxed git -C "$repo" commit -q --allow-empty -m "signed change"
  sandboxed git -C "$repo" switch -q main
  if sandboxed git -C "$repo" merge -q --ff-only signed >"$OUT" 2>&1; then
    pass "a commit signed by a trusted signer merges"
  else
    fail "a trusted signed commit was refused: $(cat "$OUT")"
  fi
  : >"$SANDBOX_HOME/.config/git/allowed_signers"
  sandboxed git -C "$repo" switch -q -c untrusted main
  sandboxed git -C "$repo" commit -q --allow-empty -m "signed but untrusted"
  sandboxed git -C "$repo" switch -q main
  if sandboxed git -C "$repo" merge -q --ff-only untrusted >"$OUT" 2>&1; then
    fail "a commit from a signer missing from allowed_signers was merged"
  else
    pass "a signer missing from allowed_signers is refused"
  fi

  test_start "allowed_signers_file_documented"
  roster="$WORK/allowed_signers"
  render "$REPO_ROOT/defaults/dot_config/git/allowed_signers.tmpl" "$roster" '{"git_email":"fixture@example.com"}'
  assert_equals "0" "$?" "allowed_signers.tmpl renders: $(cat "$WORK/render.err")"
  assert_file_contains "$roster" "Git verifies SSH-signed commits" "the rendered roster documents what it is for"

  # parse_roster <file> — every entry is "principal keytype key"; ssh-keygen
  # must accept each key. Sets entries, bad and principals.
  parse_roster() {
    entries=0 bad=0 principals=""
    while read -r principal keytype key _; do
      [[ -z "$principal" || "$principal" == \#* ]] && continue
      entries=$((entries + 1))
      principals+="$principal $keytype"$'\n'
      printf '%s %s\n' "$keytype" "$key" >"$WORK/key.pub"
      ssh-keygen -l -f "$WORK/key.pub" >/dev/null 2>&1 || bad=$((bad + 1))
    done <"$1"
  }
  parse_roster "$roster"
  assert_equals "0" "$bad" "every roster key parses with ssh-keygen ($entries entries)"
  assert_contains "action@github.com ssh-ed25519" "$principals" "the Actions bot signer is trusted"
  assert_contains "sebastian.rousseau@gmail.com ssh-ed25519" "$principals" "the maintainer signer is trusted"

  test_start "allowed_signers_adds_maintainer_keys_for_the_maintainer"
  owner_roster="$WORK/allowed_signers.owner"
  render "$REPO_ROOT/defaults/dot_config/git/allowed_signers.tmpl" "$owner_roster" \
    '{"git_email":"sebastian.rousseau@gmail.com"}'
  assert_equals "0" "$?" "allowed_signers.tmpl renders for the maintainer"
  parse_roster "$owner_roster"
  assert_equals "0" "$bad" "every maintainer roster key parses with ssh-keygen ($entries entries)"
  owner_keys="$(awk '$1 == "sebastian.rousseau@gmail.com"' "$owner_roster" | wc -l | tr -d ' ')"
  other_keys="$(awk '$1 == "sebastian.rousseau@gmail.com"' "$roster" | wc -l | tr -d ' ')"
  if ((owner_keys > other_keys)); then
    pass "the maintainer's hardware and device keys are added only on the maintainer's machine ($other_keys -> $owner_keys)"
  else
    fail "the maintainer roster ($owner_keys) is not larger than the default ($other_keys)"
  fi
fi

# ===========================================================================
# Homebrew bootstrap: pinned URL, checksum-verified installer
# ===========================================================================
MANIFEST="$REPO_ROOT/security/remote-installers.sha256"
brew_home="$WORK/brew"
mkdir -p "$brew_home"
# curl: record the URL and write a harmless installer that leaves a marker.
cat >"$WORK/stubs/curl" <<EOF
#!$REAL_BASH
out="" url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    -A) shift 2 ;;
    https://*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "\$url" >>"$brew_home/urls"
printf '#!/bin/bash\n: >"%s"\n' "$brew_home/executed" >"\$out"
EOF
chmod +x "$WORK/stubs/curl"
# brew_install [snippet] — source the library, hide any real brew, run the
# optional override snippet, then install_homebrew.
brew_install() {
  rm -f "$brew_home/urls" "$brew_home/executed"
  sandboxed DOTFILES_NONINTERACTIVE=1 "$REAL_BASH" -c '
    source "$1"
    has_brew() { return 1; }
    eval "$2"
    install_homebrew
  ' _ "$REPO_ROOT/install/lib/package_managers.sh" "${1:-}" >"$OUT" 2>&1
}

test_start "homebrew_bootstrap_fetches_a_pinned_immutable_installer"
brew_install
assert_not_equals "0" "$?" "a payload that does not match the manifest is refused"
url="$(cat "$brew_home/urls" 2>/dev/null)"
if [[ "$url" =~ ^https://raw\.githubusercontent\.com/Homebrew/install/[0-9a-f]{40}/install\.sh$ ]]; then
  pass "the installer is fetched from a commit-pinned URL"
else
  fail "the installer URL is not commit-pinned: '$url'"
fi
refute_contains "/HEAD/" "$url" "the installer URL is not the mutable HEAD"
assert_equals "1" "$(awk -v u="$url" '$2 == u' "$MANIFEST" | wc -l | tr -d ' ')" \
  "the fetched URL is pinned in security/remote-installers.sha256"
[[ -e "$brew_home/executed" ]] && fail "a tampered installer was executed" || pass "a tampered installer never runs"

test_start "homebrew_bootstrap_requires_checksum"
# Past the download check, the library's own pinned SHA-256 must still hold.
brew_install '
  download_verified_script() { printf "#!/bin/bash\n: >\"%s\"\n" "'"$brew_home"'/executed" >"$2"; }
  _dot_sha256_file() { printf "%064d\n" 0; }'
assert_not_equals "0" "$?" "install_homebrew fails on a checksum mismatch"
assert_contains "checksum mismatch" "$(cat "$OUT")" "the mismatch is reported"
[[ -e "$brew_home/executed" ]] && fail "a mismatched installer was executed" || pass "a mismatched installer never runs"

test_start "homebrew_bootstrap_runs_the_genuine_installer"
# The genuine payload hashes to whatever the manifest pins for the URL; the
# library's inline checksum must agree with it or no real install succeeds.
brew_install '
  _dot_sha256_file() {
    awk -v u="$(cat "'"$brew_home"'/urls")" '"'"'$2 == u {print $1}'"'"' "'"$MANIFEST"'"
  }'
assert_equals "0" "$?" "install_homebrew succeeds when both checksums hold: $(tail -n 1 "$OUT")"
[[ -e "$brew_home/executed" ]] && pass "the verified installer runs" || fail "the verified installer did not run"

# ===========================================================================
# Policy bundle release packaging
# ===========================================================================
test_start "policy_bundle_release_is_signed_and_attested"
assert_file_exists "$policy_release_workflow" "policy bundle release workflow exists"
assert_file_contains "$policy_release_workflow" "Verify signed source ref" "policy release verifies signed source refs"
assert_file_contains "$policy_release_workflow" "actions/attest-build-provenance" "policy release attests the bundle artifact"

test_start "policy_bundle_script_packages_a_versioned_archive"
bundle_out="$WORK/bundles"
sandboxed REPO_ROOT="$REPO_ROOT" "$REAL_BASH" "$REPO_ROOT/tools/release/package-policy-bundles.sh" \
  --output-dir "$bundle_out" --version 9.9.9 --json >"$OUT" 2>"$ERR"
assert_equals "0" "$?" "the bundle script succeeds: $(cat "$ERR")"
archive="$bundle_out/policy-bundles-9.9.9.tar.gz"
assert_file_exists "$archive" "a versioned policy-bundles archive is written"
assert_equals "$archive" "$(jq -r '.archive' "$OUT" 2>/dev/null)" "--json reports the archive"
listing="$(tar -tzf "$archive" 2>/dev/null)"
for member in dot_config/dotfiles/mcp-policy.json dot_config/dotfiles/mcp-lock.json \
  .well-known/mcp/server-card.json docs/security/MCP_POLICY.md sbom.cyclonedx.json; do
  assert_contains "policy-bundles-9.9.9/$member" "$listing" "the archive carries $member"
done
(cd "$bundle_out" && awk '{print $1}' policy-bundles-9.9.9.sha256 >"$WORK/want")
assert_equals "$(cat "$WORK/want")" "$(sandboxed "$REAL_BASH" -c 'source "$1"; _dot_sha256_file "$2"' _ \
  "$REPO_ROOT/lib/dot/verified-download.sh" "$archive")" "the .sha256 file matches the archive"

test_start "policy_bundle_script_refuses_a_missing_artifact"
fixture="$WORK/fixture-repo"
mkdir -p "$fixture/defaults/dot_config/dotfiles"
printf 'defaults\n' >"$fixture/.chezmoiroot"
printf '{"schemaVersion":"1"}\n' >"$fixture/defaults/dot_config/dotfiles/policy-bundles.json"
sandboxed REPO_ROOT="$fixture" "$REAL_BASH" "$REPO_ROOT/tools/release/package-policy-bundles.sh" \
  --output-dir "$WORK/bundles-missing" >"$OUT" 2>"$ERR"
assert_not_equals "0" "$?" "a tree without the governance artifacts is refused"
assert_contains "Missing required policy bundle artifact: dot_config/dotfiles/model-registry.json" \
  "$(cat "$ERR")" "the first missing artifact is named"
[[ -e "$WORK/bundles-missing/policy-bundles-1.tar.gz" ]] && fail "a partial archive was written" ||
  pass "no partial archive is written"

# ===========================================================================
# MCP supply chain: shipped policy, lock and pins
# ===========================================================================
MCP_CONFIG_SHIPPED="$REPO_ROOT/defaults/dot_config/claude/mcp_servers.json"
MCP_POLICY_SHIPPED="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-policy.json"
mcp_doctor() { # <config> [policy]
  sandboxed MCP_CONFIG="$1" MCP_POLICY_CONFIG="${2:-$MCP_POLICY_SHIPPED}" \
    "$REAL_BASH" "$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh" --strict >"$OUT" 2>&1
}

test_start "mcp_shipped_config_passes_the_strict_policy"
mcp_doctor "$MCP_CONFIG_SHIPPED"
assert_equals "0" "$?" "the shipped MCP config passes mcp-doctor --strict: $(tail -n 1 "$OUT")"
assert_contains "all active servers match approved package refs" "$(cat "$OUT")" \
  "every shipped server matches the approved package lock"
assert_contains "no unpinned npx packages found" "$(cat "$OUT")" "every shipped server uses a pinned release"

test_start "mcp_policy_requires_the_approved_package_lock"
jq '.mcpServers.memory.args[1] = "@modelcontextprotocol/server-memory@2026.2.0"' \
  "$MCP_CONFIG_SHIPPED" >"$WORK/mcp-drifted.json"
mcp_doctor "$WORK/mcp-drifted.json"
assert_not_equals "0" "$?" "a server pinned off the lock fails --strict"
assert_contains "memory uses @modelcontextprotocol/server-memory@2026.2.0 (approved: @modelcontextprotocol/server-memory@2026.3.0)" \
  "$(cat "$OUT")" "the lock mismatch is reported against the approved ref"
jq '.profiles[.defaultProfile].requireApprovedPackageLock = false' "$MCP_POLICY_SHIPPED" >"$WORK/mcp-policy-lax.json"
mcp_doctor "$WORK/mcp-drifted.json" "$WORK/mcp-policy-lax.json"
refute_contains "(approved:" "$(cat "$OUT")" "the lock check is driven by the shipped policy's requireApprovedPackageLock"

test_start "mcp_policy_flags_unpinned_packages"
jq '.mcpServers.memory.args[1] = "@modelcontextprotocol/server-memory"' \
  "$MCP_CONFIG_SHIPPED" >"$WORK/mcp-unpinned.json"
mcp_doctor "$WORK/mcp-unpinned.json"
assert_not_equals "0" "$?" "an unpinned server fails --strict"
assert_contains "memory uses unpinned npx package" "$(cat "$OUT")" "the unpinned server is named"

# ===========================================================================
# CI workflow controls (YAML consumed by GitHub Actions)
# ===========================================================================
test_start "update_deps_uses_signed_commits"
assert_file_contains "$update_deps_workflow" "git commit -S -m" "dependency updates use signed commits"

test_start "sync_versions_uses_signed_commits"
# `git commit -S` (signed); tolerant of additional flags such as -s (DCO
# sign-off), which the bot also needs so its auto-commit passes the
# "Check sign-off" workflow on the PR it pushes to.
assert_file_contains "$sync_versions_workflow" "git commit -S" "version sync uses signed commits"

test_start "update_deps_avoids_unverified_yq_download"
if ! grep -q "wget -qO /usr/local/bin/yq" "$update_deps_workflow"; then
  pass "yq is not installed from an unverified latest URL"
else
  fail "unverified yq latest download still present"
fi
# yq must come from the distro package manager rather than an unpinned
# download. Accept either the direct apt call or tools/ci/install-tools.sh,
# which is an apt wrapper that only ever skips work when the binary is already
# on the runner image — the provenance is identical either way.
if grep -Eq '(apt-get install|install-tools\.sh).*[[:space:]]yq([[:space:]]|$)' "$update_deps_workflow"; then
  pass "yq installed from package manager"
else
  fail "yq is not provisioned through the package manager"
fi

test_start "security_pipeline_runs_dependency_scan_on_core_events"
if ! sed -n '/dependency-scan:/,/infrastructure-scan:/p' "$security_workflow" | grep -q "if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'"; then
  pass "dependency scan is not schedule-only"
else
  fail "dependency scan is still schedule-only"
fi
assert_file_contains "$security_workflow" "anchore/grype:v" "grype uses pinned container image"
assert_file_contains "$security_workflow" "aquasec/trivy:" "trivy uses pinned container image"
assert_file_contains "$security_workflow" "GRYPE_VERSION: \"0.104.3\"" "grype version updated beyond known affected range"
assert_file_contains "$security_workflow" "TRIVY_VERSION: \"0.68.2\"" "trivy version updated beyond known affected range"

test_start "security_pipeline_runs_checkov_on_core_events"
if ! sed -n '/infrastructure-scan:/,/container-scan:/p' "$security_workflow" | grep -q "if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'"; then
  pass "checkov scan is not schedule-only"
else
  fail "checkov scan is still schedule-only"
fi

test_start "summary_jobs_present_for_branch_protection"
assert_file_contains "$security_workflow" "name: Security Summary" "security summary job present"
assert_file_contains "$reliability_workflow" "name: Reliability Summary" "reliability summary job present"

test_start "root_flake_lock_present"
assert_file_exists "$flake_lock_file" "root flake.lock exists for deterministic Nix inputs"

test_start "compliance_docs_present"
assert_file_exists "$soup_register_file" "SOUP register exists"
assert_file_exists "$automation_secrets_file" "automation secrets doc exists"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
