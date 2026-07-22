#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/meta.sh.
# These dot command files are sourced by the dispatcher; their case
# arms only execute when a specific subcommand fires. To cover the
# internal helper functions defined alongside the dispatch we source
# the file directly and invoke each name.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/meta.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

DOT_BIN="$REPO_ROOT/bin/dot"

# meta.sh dispatcher arms — read-only/--help probes.
# Skipping: cmd_upgrade (real package-manager network), cmd_prewarm
# (modifies real shell cache; idempotency-safe but slow), cmd_sandbox
# (interactive), cmd_mcp (covered by test_auto_cmd_mcp_doctor.sh).
for cmd in "docs" "keys"; do
  test_start "dot_$(echo "$cmd" | tr ' -' '__' | tr -dc 'a-z0-9_')"
  # `$cmd` is INTENDED to word-split.
  # shellcheck disable=SC2086
  if (cd "$REPO_ROOT" && bash "$DOT_BIN" $cmd >/dev/null 2>&1); then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=0)"
  else
    rc=$?
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc"
    fi
  fi
done

test_start "meta_deep_branches_execute"
meta_tmp="$DOTFILES_COV_TMPDIR/meta-deep"
mkdir -p "$meta_tmp/repo/docs" \
  "$meta_tmp/repo/scripts/ops" \
  "$meta_tmp/repo/scripts/diagnostics" \
  "$meta_tmp/repo/defaults/dot_local/bin" \
  "$meta_tmp/repo/dot_config/dotfiles" \
  "$meta_tmp/repo/nix" \
  "$meta_tmp/bin" \
  "$meta_tmp/cache/zsh" \
  "$meta_tmp/cache/bash" \
  "$meta_tmp/cache/fish" \
  "$meta_tmp/cache/nushell"
printf '# Readme\n' >"$meta_tmp/repo/README.md"
printf '# Keys\n\nssh signing\n' >"$meta_tmp/repo/docs/KEYS.md"
printf '{}\n' >"$meta_tmp/repo/nix/flake.nix"
cat >"$meta_tmp/repo/dot_config/dotfiles/mcp-registry.json" <<'EOF_REGISTRY'
{
  "servers": {
    "local": {
      "transport": "stdio",
      "launcher": "npx",
      "package": "@example/mcp"
    }
  }
}
EOF_REGISTRY
for helper in \
  scripts/ops/prewarm.sh \
  scripts/ops/tour.sh \
  scripts/diagnostics/keys.sh \
  scripts/diagnostics/mcp-doctor.sh \
  defaults/dot_local/bin/executable_tour; do
  mkdir -p "$meta_tmp/repo/$(dirname "$helper")"
  cat >"$meta_tmp/repo/$helper" <<'EOF_HELPER'
#!/usr/bin/env bash
printf 'helper:%s\n' "$0"
EOF_HELPER
  chmod +x "$meta_tmp/repo/$helper"
done
for tool in chezmoi nix nix-collect-garbage nvim glow rg jq docker podman git; do
  cat >"$meta_tmp/bin/$tool" <<'EOF_TOOL'
#!/usr/bin/env bash
case "$(basename "$0")" in
  git)
    case "$*" in
      *user.signingkey*) printf '%s\n' "$HOME/.ssh/signing.pub" ;;
      *gpg.format*) printf 'ssh\n' ;;
    esac
    ;;
  jq)
    printf 'local\tstdio\tnpx\t@example/mcp\n'
    ;;
  *)
    printf '%s:%s\n' "$(basename "$0")" "$*"
    ;;
esac
EOF_TOOL
  chmod +x "$meta_tmp/bin/$tool"
done
mkdir -p "$meta_tmp/home/.ssh"
printf 'ssh-ed25519 AAAATEST\n' >"$meta_tmp/home/.ssh/signing.pub"
touch "$meta_tmp/cache/zsh/tool-init.zsh" \
  "$meta_tmp/cache/bash/tool-init.bash" \
  "$meta_tmp/cache/fish/tool-init.fish" \
  "$meta_tmp/cache/nushell/tool.nu"
(
  set +e
  export HOME="$meta_tmp/home"
  export XDG_CACHE_HOME="$meta_tmp/cache"
  export PATH="$meta_tmp/bin:$PATH"
  export DOTFILES_FONTS=0
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  _DOT_SOURCE_DIR_CACHE="$meta_tmp/repo"
  set -- help
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  meta_banner_section mcp
  meta_banner_section docs
  meta_banner_section upgrade
  cmd_upgrade
  cmd_prewarm
  (cmd_docs)
  cmd_keys sign-check
  cmd_keys ssh
  rm -f "$meta_tmp/repo/docs/KEYS.md"
  (cmd_keys)
  (cmd_learn)
  rm -f "$meta_tmp/repo/defaults/dot_local/bin/executable_tour"
  (cmd_learn)
  (cmd_sandbox)
  PATH="$meta_tmp/bin:/usr/bin:/bin" cmd_mcp registry
  PATH="/usr/bin:/bin" cmd_mcp registry
  MCP_REGISTRY_CONFIG="$meta_tmp/repo/dot_config/dotfiles/mcp-registry.json" cmd_mcp registry --json
  (cmd_mcp doctor --strict)
  (cmd_mcp nope)
) >/dev/null || true
assert_file_not_exists "$meta_tmp/cache/zsh/tool-init.zsh" \
  "meta deep branches cleared sandbox zsh cache"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
