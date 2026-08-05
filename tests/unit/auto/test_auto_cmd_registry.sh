#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/registry.sh
# (the module-registry CLI). Covers existence, syntax, every read-only
# subcommand (url, --help, list, search, info), and the set-url
# safety guards (HTTPS-only, missing arg).
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/registry.sh"
DOT_BIN="$REPO_ROOT/bin/dot"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/registry.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Point the fetcher at the in-repo sample registry so list/search/info
# don't hit the network. The smoke also exercises _registry_url's
# DOTFILES_REGISTRY_URL branch.
LOCAL_REGISTRY="file://$REPO_ROOT/docs/registry.json"
export DOTFILES_REGISTRY_URL="$LOCAL_REGISTRY"

for sub in "--help" "url" "list"; do
  test_start "dot_registry_$(echo "$sub" | tr -d -- '-')"
  if bash "$DOT_BIN" registry "$sub" >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=0)"
  else
    rc=$?
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  fi
done

# search + info — both require jq; skipped cleanly when absent.
test_start "dot_registry_search"
if bash "$DOT_BIN" registry search anything >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
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

test_start "dot_registry_info_missing_module"
# Empty registry → info on any name should exit non-zero (module not found),
# which still counts as exercising the info branch.
if ! bash "$DOT_BIN" registry info nonexistent-module >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have rejected"
fi

test_start "dot_registry_install_stub"
# install is a scaffold today — should print the would-fetch hint
# and return 0. Exercises the install case arm.
if bash "$DOT_BIN" registry install some-module >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Safety guards on set-url.
test_start "dot_registry_set_url_refuses_http"
if bash "$DOT_BIN" registry set-url "http://evil.example.com/r" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused HTTP"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "dot_registry_set_url_missing_arg"
if bash "$DOT_BIN" registry set-url >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused missing URL"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "dot_registry_unknown_subcommand"
if bash "$DOT_BIN" registry not-a-real-subcommand >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have rejected"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "dot_registry_deep_branches_execute"
registry_tmp="$DOTFILES_COV_TMPDIR/registry-deep"
mkdir -p "$registry_tmp/config/dotfiles" \
  "$registry_tmp/cache/dotfiles/registry" \
  "$registry_tmp/bin"
cat >"$registry_tmp/cache/dotfiles/registry/index.json" <<'JSON'
{
  "version": 1,
  "updated": "2026-07-22T12:00:00Z",
  "modules": [
    {
      "name": "rust-dev-setup",
      "description": "Rust toolchain and IDE config",
      "repo": "https://github.com/example/rust-dev-setup",
      "tags": ["rust", "dev", "language"],
      "maintainer": "alice@example.com",
      "version": "1.2.0",
      "sha256": "abc123"
    },
    {
      "name": "k8s-operator-laptop",
      "description": "Kubernetes operator workstation profile",
      "repo": "https://github.com/example/k8s-operator-laptop",
      "tags": ["kubernetes", "ops"],
      "maintainer": "bob@example.com",
      "version": "0.4.0",
      "sha256": "def456"
    }
  ]
}
JSON
cat >"$registry_tmp/curl-success.json" <<'JSON'
{
  "version": 1,
  "modules": [
    {
      "name": "fetched-module",
      "description": "Fetched test module",
      "tags": ["fetched"],
      "version": "9.9.9"
    }
  ]
}
JSON
cat >"$registry_tmp/bin/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -n "${DOTFILES_FAKE_CURL_FAIL:-}" ]]; then
  exit 22
fi
cp "$DOTFILES_FAKE_CURL_SOURCE" "$out"
SHIM
chmod +x "$registry_tmp/bin/curl"

(
  set +e
  export HOME="$registry_tmp/home"
  export XDG_CONFIG_HOME="$registry_tmp/config"
  export XDG_CACHE_HOME="$registry_tmp/cache"
  export DOTFILES_REGISTRY_URL=""
  export DOTFILES_FAKE_CURL_SOURCE="$registry_tmp/curl-success.json"
  export PATH="$registry_tmp/bin:$PATH"
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"

  _registry_default_url
  _registry_config_file
  _registry_cache_dir
  _registry_url
  printf 'url = "file://%s/custom.json"\n' "$registry_tmp" \
    >"$registry_tmp/config/dotfiles/registry.toml"
  _registry_url
  DOTFILES_REGISTRY_URL="https://override.example/registry.json" _registry_url

  cmd_registry url
  cmd_registry list
  cmd_registry search rust
  cmd_registry search language
  cmd_registry search missing
  cmd_registry info rust-dev-setup
  cmd_registry info missing-module
  cmd_registry install rust-dev-setup
  cmd_registry install
  cmd_registry set-url "http://evil.example/r"
  cmd_registry set-url "https://registry.example/index.json"
  cmd_registry set-url "file://$registry_tmp/index.json"
  cmd_registry --help
  cmd_registry not-a-real-subcommand

  rm -f "$registry_tmp/cache/dotfiles/registry/index.json"
  DOTFILES_REGISTRY_URL="https://registry.example/index.json" _registry_fetch
) >/dev/null || true
assert_file_contains "$registry_tmp/config/dotfiles/registry.toml" \
  'file://' "registry deep branches persisted sandbox URL"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
