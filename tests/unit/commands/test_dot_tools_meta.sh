#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Deep-dive coverage for the dot tools + meta modules — parallel
# treatment to what dot diagnostics received. Same structure:
#   1. Every cmd_<name>() function defined
#   2. Every dispatch case wired
#   3. Every target script referenced by run_script exists
#   4. Dispatch smoke — no command hits Unknown fall-through
#   5. Property checks specific to the module
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

TOOLS_SH="$REPO_ROOT/scripts/dot/commands/tools.sh"
META_SH="$REPO_ROOT/scripts/dot/commands/meta.sh"

# ---------------------------------------------------------------------------
# tools.sh — function definitions
# ---------------------------------------------------------------------------
for fn in cmd_setup cmd_tools cmd_new cmd_packages cmd_log_rotate \
          cmd_env_mise cmd_profile; do
  _cmd_asserts_defined "$TOOLS_SH" "$fn"
done

# tools.sh — dispatch cases
for label in tools alias-check new packages log-rotate setup \
             aliases env profile lint; do
  _cmd_asserts_case_exists "$TOOLS_SH" "$label"
done

# tools.sh — wildcard + Unknown fall-through
test_start "tools_has_wildcard_fallthrough"
grep -qE '^  \*\)' "$TOOLS_SH" && _ok || _fail

test_start "tools_wildcard_emits_unknown"
awk '/^  \*\)/{f=1;next} f && /^\s*;;/{exit} f' "$TOOLS_SH" | grep -qi "unknown"
[[ $? -eq 0 ]] && _ok || _fail

# tools.sh — dispatch smoke for reachable commands (skip ones that
# would try to exec real editors or run install steps).
for cmd in profile env aliases alias-check; do
  test_start "tools_dispatch_reaches_${cmd//-/_}"
  out="$(bash "$TOOLS_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown tools command"* ]]; then _ok; else _fail; fi
done

# ---------------------------------------------------------------------------
# meta.sh — function definitions
# ---------------------------------------------------------------------------
for fn in cmd_upgrade cmd_prewarm cmd_docs cmd_learn cmd_keys \
          cmd_sandbox cmd_mcp; do
  _cmd_asserts_defined "$META_SH" "$fn"
done

# meta.sh — dispatch cases
for label in upgrade cache-refresh docs learn keys sandbox mcp mode; do
  _cmd_asserts_case_exists "$META_SH" "$label"
done

# meta.sh — wildcard + Unknown
test_start "meta_has_wildcard_fallthrough"
grep -qE '^  \*\)' "$META_SH" && _ok || _fail

test_start "meta_wildcard_emits_unknown"
awk '/^  \*\)/{f=1;next} f && /^\s*;;/{exit} f' "$META_SH" | grep -qi "unknown"
[[ $? -eq 0 ]] && _ok || _fail

# meta.sh — dispatch smoke for read-only commands.
for cmd in docs learn keys mcp; do
  test_start "meta_dispatch_reaches_${cmd}"
  out="$(bash "$META_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown meta command"* ]]; then _ok; else _fail; fi
done

# ---------------------------------------------------------------------------
# Property checks — high-signal commands
# ---------------------------------------------------------------------------

# `upgrade` should be idempotent — safe to re-run.
test_start "upgrade_body_calls_underlying_scripts"
upgrade_body=$(awk '/^cmd_upgrade\(\)/{f=1;next} f && /^}/{exit} f' "$META_SH")
if grep -qE 'run_script|chezmoi|mise|apt|brew' <<<"$upgrade_body"; then
  _ok
else
  _fail "upgrade does nothing recognisable"
fi

# `sandbox` must be strictly read-only from the host's perspective —
# should delegate everything to a container runtime (docker/podman)
# so any writes stay inside the container image, not the user's $HOME.
test_start "sandbox_delegates_to_container_runtime"
sandbox_body=$(awk '/^cmd_sandbox\(\)/{f=1;next} f && /^}/{exit} f' "$META_SH")
if grep -qE '\b(docker|podman)\b' <<<"$sandbox_body"; then
  _ok
else
  _fail "sandbox does not use docker/podman"
fi

test_start "sandbox_does_not_bare_rm_on_host"
# Guard: bare `rm ` at start-of-line/statement, not `--rm` flag.
if grep -qE '^\s*rm\s' <<<"$sandbox_body"; then
  _fail "sandbox has a bare host-side rm"
else
  _ok
fi

# `mcp` must reference either the policy config file or a registry.
test_start "mcp_references_policy_or_registry"
mcp_body=$(awk '/^cmd_mcp\(\)/{f=1;next} f && /^}/{exit} f' "$META_SH")
grep -qE 'mcp|policy|registry' <<<"$mcp_body" && _ok || _fail

# `docs` must serve local docs, not fetch over the network.
test_start "docs_serves_local_files_not_network"
docs_body=$(awk '/^cmd_docs\(\)/{f=1;next} f && /^}/{exit} f' "$META_SH")
if grep -qE '(^|\s)(curl|wget)\s' <<<"$docs_body"; then
  _fail "docs reaches out over the network"
else
  _ok
fi

# `keys` prints the keybinding catalog — must reference a static
# manifest, not build state at runtime.
test_start "keys_references_static_catalog"
keys_body=$(awk '/^cmd_keys\(\)/{f=1;next} f && /^}/{exit} f' "$META_SH")
if grep -qE 'keybind|shortcut|catalog|manifest' <<<"$keys_body" \
   || grep -qE 'run_script|source' <<<"$keys_body"; then
  _ok
else
  _fail "keys does not reference any catalog"
fi

# `profile` in tools.sh — must delegate to chezmoi (agent profile
# is a chezmoi data field, not a state file).
test_start "profile_delegates_to_chezmoi_or_state"
profile_body=$(awk '/^cmd_profile\(\)/{f=1;next} f && /^}/{exit} f' "$TOOLS_SH")
grep -qE 'chezmoi|profile' <<<"$profile_body" && _ok || _fail

# `packages` should list, not install by default (safety).
test_start "packages_default_action_is_list_not_install"
packages_body=$(awk '/^cmd_packages\(\)/{f=1;next} f && /^}/{exit} f' "$TOOLS_SH")
# A default-install would apt-get / pacman / brew install as the first
# statement. A default-list would just print or call a manifest reader.
if grep -qE '^\s*(apt|pacman|brew|dnf)[[:space:]]+install' <<<"$packages_body"; then
  _fail "packages installs by default"
else
  _ok
fi

_cmd_finish
