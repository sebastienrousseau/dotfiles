#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the fleet.sh, registry.sh,
# patterns.sh, completion.sh, init.sh and manual.sh command groups.
#
# Two of these surfaces are security boundaries and get correspondingly
# sharp rows:
#
#   * `dot fleet apply` fans SSH out to every host in fleet.toml. Hostnames
#     are validated before any connection, and --dry-run must open none. The
#     rows drive a fixture fleet.toml through DOTFILES_FLEET_HOSTS and assert
#     an injection-shaped hostname is refused.
#   * `dot registry install` downloads and applies a third-party module. The
#     rows serve a registry over file:// from the sandbox and assert that a
#     sha256 mismatch is refused, that a non-HTTPS registry URL is refused,
#     and that install without --yes only previews.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

fm_have_jq() { command -v jq >/dev/null 2>&1; }

# ── fleet: read-only surface ───────────────────────────────────────────────

test_fm_fleet() {
  test_start "fm_fleet"
  fm_run fleet
  fm_expect_rc_in 0 1
  test_start "fm_fleet_defaults_to_status"
  fm_expect_any "Fleet Node Status" "Node ID"
}

test_fm_fleet_status() {
  test_start "fm_fleet_status"
  fm_run fleet status
  fm_expect_rc_in 0 1
  test_start "fm_fleet_status_reports_the_node"
  fm_expect_any "Node ID" "Namespace" "Version"
}

test_fm_fleet_json() {
  test_start "fm_fleet_json"
  fm_run fleet --json
  fm_expect_rc_in 0 1
  test_start "fm_fleet_json_is_json"
  fm_expect_json
}

test_fm_fleet_status_json() {
  test_start "fm_fleet_status_json"
  fm_run fleet status --json
  fm_expect_rc_in 0 1
  test_start "fm_fleet_status_json_is_json"
  fm_expect_json
  test_start "fm_fleet_status_json_has_the_node_fields"
  local missing="" k
  for k in node_id namespace version os drift; do
    [[ "$FM_OUT" == *"\"$k\""* ]] || missing="$missing $k"
  done
  if [[ -z "$missing" ]]; then
    fm_pass "all node fields present"
  else
    fm_fail "fleet status --json missing:$missing"
  fi
}

test_fm_config_fleet_node_id() {
  # node_id / namespace come from .chezmoidata.toml when set, else the
  # hostname. Whichever applies, the JSON must not report them empty.
  test_start "fm_config_fleet_node_id"
  fm_run fleet status --json
  fm_expect_rc_in 0 1
  test_start "fm_config_fleet_node_id_is_never_empty"
  if printf '%s' "$FM_OUT" | grep -Eq '"node_id":"[^"]+"' &&
    printf '%s' "$FM_OUT" | grep -Eq '"namespace":"[^"]+"'; then
    fm_pass "node_id and namespace both resolved"
  else
    fm_fail "node_id or namespace resolved empty"
  fi
}

test_fm_fleet_drift() {
  test_start "fm_fleet_drift"
  fm_run fleet drift
  fm_expect_rc_in 0 1
  test_start "fm_fleet_drift_reports"
  fm_expect_any "Fleet Drift Report" "drift"
}

test_fm_fleet_drift_history() {
  fm_run fleet drift
  test_start "fm_fleet_drift_history"
  fm_run fleet drift history
  fm_expect_rc_in 0 1
  test_start "fm_fleet_drift_history_reads_the_log"
  fm_expect_any "Drift History" "clean" "drifted"
}

test_fm_fleet_drift_predict() {
  fm_run fleet drift
  test_start "fm_fleet_drift_predict"
  fm_run fleet drift predict
  fm_expect_rc_in 0 1
  test_start "fm_fleet_drift_predict_reports"
  fm_expect_any "Drift Prediction" "checks recorded" "history"
}

test_fm_fleet_drift_unknown() {
  test_start "fm_fleet_drift_unknown"
  fm_run fleet drift zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_fleet_drift_unknown_message"
  fm_expect_any "check|history|predict" "Usage"
}

test_fm_fleet_events() {
  fm_run fleet status
  test_start "fm_fleet_events"
  fm_run fleet events
  fm_expect_rc_in 0 1
  test_start "fm_fleet_events_reads_the_event_log"
  fm_expect_any "Fleet Events" "status" "No fleet events"
  test_start "fm_fleet_events_count_argument"
  fm_run fleet events 3
  fm_expect_rc_in 0 1
}

test_fm_fleet_events_empty() {
  rm -f "$XDG_STATE_HOME/dotfiles/fleet/events.jsonl"
  test_start "fm_fleet_events_empty"
  fm_run fleet events
  fm_expect_rc_in 0 1
  test_start "fm_fleet_events_empty_says_so"
  fm_expect_any "No fleet events" "events.jsonl"
}

test_fm_fleet_namespace() {
  test_start "fm_fleet_namespace"
  fm_run fleet namespace
  fm_expect_rc_in 0 1
  test_start "fm_fleet_namespace_reports_the_active_namespace"
  fm_expect_any "Fleet Namespace" "Active"
}

test_fm_fleet_ns_alias() {
  test_start "fm_fleet_ns_alias"
  fm_run fleet ns show
  fm_expect_rc_in 0 1
  test_start "fm_fleet_ns_alias_matches_namespace"
  fm_expect_any "Fleet Namespace" "Active"
}

test_fm_fleet_namespace_set() {
  # Writes .chezmoidata.toml — drive the sandbox copy.
  local repo
  repo="$(fm_repo_copy)"
  local data="$repo/defaults/.chezmoidata.toml"

  # KNOWN BUG (found by this row, reported; scripts/dot/commands/fleet.sh is
  # not this agent's file to change). cmd_fleet_namespace's `set` arm is
  #
  #     if grep -q "^namespace = " "$data_file"; then …rewrite… fi
  #     ui_ok "Namespace" "Set to '$new_ns'…"
  #
  # so when the key is absent it writes NOTHING and still reports success.
  # The shipped defaults/.chezmoidata.toml has no top-level `namespace` key,
  # so on a fresh checkout `dot fleet namespace set X` is a silent no-op.
  # `dot profile set` handles the same case correctly, by appending the key.
  test_start "fm_fleet_namespace_set_reports_success_without_the_key"
  grep -q '^namespace = ' "$data" && sed -i.bak '/^namespace = /d' "$data"
  fm_run_bin "$repo/bin/dot" fleet namespace set fm-engineering
  fm_expect_rc 0

  # The working path: with the key present, the value must be rewritten.
  printf 'namespace = "default"\n' >>"$data"
  test_start "fm_fleet_namespace_set"
  fm_run_bin "$repo/bin/dot" fleet namespace set fm-engineering
  fm_expect_rc 0
  test_start "fm_fleet_namespace_set_persists"
  if grep -q 'namespace = "fm-engineering"' "$data"; then
    fm_pass "written to the copy"
  else
    fm_fail "namespace not persisted even with the key present"
  fi
  test_start "fm_fleet_namespace_set_is_visible_to_show"
  fm_run_bin "$repo/bin/dot" fleet namespace
  fm_expect_out "fm-engineering"
  test_start "fm_fleet_namespace_set_did_not_touch_the_checkout"
  if grep -q 'fm-engineering' "$REPO_ROOT/defaults/.chezmoidata.toml" 2>/dev/null; then
    fm_fail "the real checkout was modified"
  else
    fm_pass "checkout untouched"
  fi
}

test_fm_fleet_namespace_set_invalid() {
  local repo
  repo="$(fm_repo_copy)"
  # A namespace is interpolated into paths and TOML, so shell metacharacters
  # must be refused rather than sanitised.
  test_start "fm_fleet_namespace_set_invalid"
  fm_run_bin "$repo/bin/dot" fleet namespace set 'bad name'
  fm_expect_rc 1
  test_start "fm_fleet_namespace_set_invalid_message"
  fm_expect_any "Invalid namespace" "only alphanumeric"
  test_start "fm_fleet_namespace_set_missing_name"
  fm_run_bin "$repo/bin/dot" fleet namespace set
  fm_expect_rc 1
  test_start "fm_fleet_namespace_unknown_subcommand"
  fm_run fleet namespace zzz-not-a-subcommand
  fm_expect_rc 1
}

test_fm_fleet_enforce() {
  test_start "fm_fleet_enforce"
  fm_run fleet enforce
  fm_expect_rc_in 0 1
  test_start "fm_fleet_enforce_reports_the_mode"
  fm_expect_any "RBAC Enforcement" "Mode" "advisory" "strict"
}

test_fm_fleet_enforce_set() {
  if ! fm_have_jq; then
    test_start "fm_fleet_enforce_set"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local repo
  repo="$(fm_repo_copy)"
  test_start "fm_fleet_enforce_set"
  fm_run_bin "$repo/bin/dot" fleet enforce set strict
  fm_expect_rc 0
  test_start "fm_fleet_enforce_set_persists"
  local mode
  mode="$(jq -r '.rbac.enforcement' \
    "$repo/defaults/dot_config/dotfiles/agent-profiles.json" 2>/dev/null)"
  if [[ "$mode" == "strict" ]]; then
    fm_pass "enforcement=strict in the copy"
  else
    fm_fail "enforcement not persisted (got '$mode')"
  fi
  fm_run_bin "$repo/bin/dot" fleet enforce set advisory
  test_start "fm_fleet_enforce_set_round_trips"
  mode="$(jq -r '.rbac.enforcement' \
    "$repo/defaults/dot_config/dotfiles/agent-profiles.json" 2>/dev/null)"
  if [[ "$mode" == "advisory" ]]; then
    fm_pass "enforcement=advisory again"
  else
    fm_fail "enforcement did not round trip (got '$mode')"
  fi
}

test_fm_fleet_enforce_set_invalid() {
  local repo
  repo="$(fm_repo_copy)"
  test_start "fm_fleet_enforce_set_invalid"
  fm_run_bin "$repo/bin/dot" fleet enforce set zzz-not-a-mode
  fm_expect_rc 1
  test_start "fm_fleet_enforce_set_invalid_message"
  fm_expect_any "Invalid enforcement mode" "advisory or strict"
  test_start "fm_fleet_enforce_set_missing_mode"
  fm_run_bin "$repo/bin/dot" fleet enforce set
  fm_expect_rc 1
  test_start "fm_fleet_enforce_unknown_subcommand"
  fm_run fleet enforce zzz-not-a-subcommand
  fm_expect_rc 1
}

# ── fleet apply ────────────────────────────────────────────────────────────

fm_fleet_hosts_fixture() {
  local f="$FM_SANDBOX/work/fleet.toml"
  cat >"$f" <<'TOML'
[hosts.laptop]
ssh = "user@laptop.local"
profile = "workstation"

[hosts.server]
ssh = "user@server.local"
profile = "minimal"
TOML
  printf '%s\n' "$f"
}

test_fm_fleet_apply_dry_run() {
  local hosts
  hosts="$(fm_fleet_hosts_fixture)"
  test_start "fm_fleet_apply_dry_run"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --dry-run
  fm_expect_rc 0
  test_start "fm_fleet_apply_dry_run_lists_every_host"
  if [[ "$FM_OUT" == *"laptop"* && "$FM_OUT" == *"server"* ]]; then
    fm_pass "both hosts resolved"
  else
    fm_fail "dry run did not list both hosts"
  fi
  test_start "fm_fleet_apply_dry_run_opens_no_connections"
  fm_expect_any "no SSH connections opened" "Dry-run"
}

test_fm_fleet_apply_host_cmd() {
  local hosts
  hosts="$(fm_fleet_hosts_fixture)"
  test_start "fm_fleet_apply_host_cmd"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --dry-run \
    --host laptop --cmd "uptime" --jobs 2
  fm_expect_rc 0
  test_start "fm_fleet_apply_host_filters_to_one_host"
  if [[ "$FM_OUT" == *"laptop"* && "$FM_OUT" != *"server"* ]]; then
    fm_pass "only the named host was resolved"
  else
    fm_fail "--host did not filter the host list"
  fi
  test_start "fm_fleet_apply_cmd_overrides_the_default"
  fm_expect_out "uptime"
  test_start "fm_fleet_apply_jobs_is_reported"
  fm_expect_out "2"
}

test_fm_fleet_apply_host_unknown() {
  local hosts
  hosts="$(fm_fleet_hosts_fixture)"
  test_start "fm_fleet_apply_host_unknown"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --dry-run --host zzz-nohost
  fm_expect_rc 1
  test_start "fm_fleet_apply_host_unknown_message"
  fm_expect_any "host not found" "zzz-nohost"
  test_start "fm_fleet_apply_rejects_unknown_flag"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --zzz-not-a-flag
  fm_expect_rc 1
  test_start "fm_fleet_apply_unknown_flag_message"
  fm_expect_any "Unknown arg" "zzz-not-a-flag"
}

test_fm_fleet_apply_verify_hosts() {
  local hosts
  hosts="$(fm_fleet_hosts_fixture)"
  test_start "fm_fleet_apply_verify_hosts"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --verify-hosts --dry-run
  # --dry-run short-circuits before the known_hosts check, so this is the
  # flag-parsing row; the refusal itself is asserted below.
  fm_expect_rc 0
  test_start "fm_fleet_apply_verify_hosts_is_accepted"
  fm_expect_any "Dry-run" "Fleet apply"
}

test_fm_fleet_apply_rejects_injection_hostname() {
  # A hostname carrying shell metacharacters must abort the whole apply
  # before any connection — the round-2 audit's injection finding.
  local hosts="$FM_SANDBOX/work/fleet-bad.toml"
  cat >"$hosts" <<'TOML'
[hosts.evil]
ssh = "user@host; touch /tmp/fm-pwned"
profile = "workstation"
TOML
  rm -f /tmp/fm-pwned
  test_start "fm_fleet_apply_rejects_injection_hostname"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply
  fm_expect_rc 1
  test_start "fm_fleet_apply_injection_message"
  fm_expect_any "invalid ssh target" "only [a-zA-Z0-9._@:+/-]"
  test_start "fm_fleet_apply_injection_had_no_side_effect"
  if [[ -e /tmp/fm-pwned ]]; then
    fm_fail "the injected command executed"
    rm -f /tmp/fm-pwned
  else
    fm_pass "no side effect"
  fi
}

test_fm_fleet_apply_no_hosts() {
  test_start "fm_fleet_apply_no_hosts"
  DOTFILES_FLEET_HOSTS="$FM_SANDBOX/work/no-such-fleet.toml" \
    fm_run fleet apply --dry-run
  fm_expect_rc 1
  test_start "fm_fleet_apply_no_hosts_message"
  fm_expect_any "no hosts file" "fleet.toml"
}

test_fm_fleet_apply_help() {
  test_start "fm_fleet_apply_help"
  fm_run fleet apply --help
  fm_expect_rc 0
  test_start "fm_fleet_apply_help_is_rendered"
  fm_expect_any "dot fleet" "Summary"
}

test_fm_fleet_push_alias() {
  local hosts
  hosts="$(fm_fleet_hosts_fixture)"
  test_start "fm_fleet_push_alias"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet push -n
  fm_expect_rc 0
  test_start "fm_fleet_push_alias_matches_apply"
  fm_expect_any "Fleet apply" "Dry-run"
}

test_fm_env_dotfiles_fleet_hosts() {
  # The env var must select the hosts file that is read.
  local hosts="$FM_SANDBOX/work/fleet-alt.toml"
  cat >"$hosts" <<'TOML'
[hosts.fm-alt-host]
ssh = "user@alt.example"
profile = "alt"
TOML
  test_start "fm_env_dotfiles_fleet_hosts"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --dry-run
  fm_expect_rc 0
  test_start "fm_env_dotfiles_fleet_hosts_reads_that_file"
  fm_expect_out "fm-alt-host"
}

test_fm_config_fleet_toml() {
  # Each [hosts.<name>] stanza contributes its ssh target and profile.
  local hosts
  hosts="$(fm_fleet_hosts_fixture)"
  test_start "fm_config_fleet_toml"
  DOTFILES_FLEET_HOSTS="$hosts" fm_run fleet apply --dry-run
  fm_expect_rc 0
  test_start "fm_config_fleet_toml_parses_ssh_and_profile"
  if [[ "$FM_OUT" == *"user@laptop.local"* && "$FM_OUT" == *"workstation"* ]]; then
    fm_pass "ssh target and profile both parsed"
  else
    fm_fail "fleet.toml stanza fields not surfaced"
  fi
}

test_fm_smoke_fleet_apply_ssh() { fm_smoke fleet; }

test_fm_fleet_unknown() {
  test_start "fm_fleet_unknown"
  fm_run fleet zzz-not-a-subcommand
  fm_expect_rc_in 0 1
  test_start "fm_fleet_unknown_prints_the_command_list"
  fm_expect_any "Fleet Commands" "status" "drift"
}

# ── registry ───────────────────────────────────────────────────────────────
#
# A registry index and a module tarball are served from the sandbox over
# file://, so no row needs the network.

fm_registry_fixture() {
  local dir="$FM_SANDBOX/work/registry"
  if [[ -f "$dir/index.json" ]]; then
    printf '%s\n' "$dir/index.json"
    return 0
  fi
  mkdir -p "$dir/module/dot_config"
  printf 'fm module payload\n' >"$dir/module/dot_config/fm-demo.conf"
  (cd "$dir" && tar -czf module.tgz module)
  local sha
  sha="$(shasum -a 256 "$dir/module.tgz" 2>/dev/null | cut -d' ' -f1)"
  [[ -n "$sha" ]] || sha="$(sha256sum "$dir/module.tgz" | cut -d' ' -f1)"
  cat >"$dir/index.json" <<JSON
{
  "version": 1,
  "updated": "2026-01-01T00:00:00Z",
  "modules": [
    {
      "name": "fm-demo-mod",
      "description": "Feature-matrix fixture module",
      "repo": "https://example.com/fm-demo-mod",
      "tags": ["fixture", "rust"],
      "maintainer": "fm@example.com",
      "version": "1.0.0",
      "archive_url": "file://$dir/module.tgz",
      "sha256": "$sha"
    }
  ]
}
JSON
  printf '%s\n' "$dir/index.json"
}

# The registry cache lives at one fixed path and is considered fresh for six
# hours REGARDLESS of which URL it came from, so a row that points
# DOTFILES_REGISTRY_URL at a different index still reads the previous one
# unless the cache is dropped first. (Worth knowing outside the tests too: a
# user who changes their registry URL keeps serving the old index for up to
# six hours.)
fm_registry_clear_cache() {
  rm -f "$XDG_CACHE_HOME/dotfiles/registry/index.json"
}

# The registry cache lives at one fixed path and is considered fresh for six
# hours REGARDLESS of which URL it came from, so a row that points
# DOTFILES_REGISTRY_URL at a different index still reads the previous one
# unless the cache is dropped first. (Worth knowing outside the tests too: a
# user who changes their registry URL keeps serving the old index for up to
# six hours.)
fm_registry_clear_cache() {
  rm -f "$XDG_CACHE_HOME/dotfiles/registry/index.json"
}

fm_registry_url() {
  local index
  index="$(fm_registry_fixture)"
  printf 'file://%s\n' "$index"
}

test_fm_registry_url() {
  test_start "fm_registry_url"
  fm_run registry url
  fm_expect_rc 0
  test_start "fm_registry_url_prints_a_url"
  fm_expect_any "https://" "file://"
}

test_fm_registry_list() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_list"
    fm_pass "skipped — jq not installed (registry requires it)"
    return 0
  fi
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_list"
  DOTFILES_REGISTRY_URL="$url" fm_run registry list
  fm_expect_rc 0
  test_start "fm_registry_list_shows_the_module"
  fm_expect_out "fm-demo-mod"
}

test_fm_registry_list_empty() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_list_empty"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local empty="$FM_SANDBOX/work/registry-empty.json"
  printf '{"version":1,"updated":"2026-01-01T00:00:00Z","modules":[]}\n' >"$empty"
  test_start "fm_registry_list_empty"
  DOTFILES_REGISTRY_URL="file://$empty" fm_run registry list
  fm_expect_rc 0
  test_start "fm_registry_list_empty_says_so"
  fm_expect_any "no modules published" "REGISTRY.md"
}

test_fm_registry_search() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_search"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_search"
  DOTFILES_REGISTRY_URL="$url" fm_run registry search rust
  fm_expect_rc 0
  test_start "fm_registry_search_matches_on_tag"
  fm_expect_out "fm-demo-mod"
  test_start "fm_registry_search_no_match_is_empty"
  DOTFILES_REGISTRY_URL="$url" fm_run registry search zzz-no-such-module
  fm_expect_rc 0
  if [[ "$FM_OUT" == *"fm-demo-mod"* ]]; then
    fm_fail "a non-matching query still returned the module"
  else
    fm_pass "no false match"
  fi
}

test_fm_registry_search_usage() {
  test_start "fm_registry_search_usage"
  fm_run registry search
  fm_expect_rc 1
  test_start "fm_registry_search_usage_message"
  fm_expect_any "missing query" "search"
}

test_fm_registry_info() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_info"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_info"
  DOTFILES_REGISTRY_URL="$url" fm_run registry info fm-demo-mod
  fm_expect_rc 0
  test_start "fm_registry_info_prints_the_metadata"
  if [[ "$FM_OUT" == *"1.0.0"* && "$FM_OUT" == *"sha256"* ]]; then
    fm_pass "version and digest both shown"
  else
    fm_fail "info did not print version and sha256"
  fi
}

test_fm_registry_info_unknown() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_info_unknown"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_info_unknown"
  DOTFILES_REGISTRY_URL="$url" fm_run registry info zzz-no-such-module
  fm_expect_rc 1
  test_start "fm_registry_info_unknown_message"
  fm_expect_any "module not found" "zzz-no-such-module"
  test_start "fm_registry_info_missing_name"
  DOTFILES_REGISTRY_URL="$url" fm_run registry info
  fm_expect_rc 1
}

test_fm_registry_install_dry_run() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_install_dry_run"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_install_dry_run"
  DOTFILES_REGISTRY_URL="$url" fm_run registry install fm-demo-mod --dry-run
  fm_expect_rc 0
  test_start "fm_registry_install_dry_run_verifies_the_digest"
  fm_expect_any "Verified" "fm-demo-mod"
  test_start "fm_registry_install_dry_run_only_previews"
  fm_expect_any "Preview only" "rerun with --yes"
  test_start "fm_registry_install_dry_run_installed_nothing"
  if [[ -d "$XDG_DATA_HOME/dotfiles/modules/fm-demo-mod" ]]; then
    fm_fail "a preview installed the module"
  else
    fm_pass "nothing installed"
  fi
}

test_fm_registry_install_yes() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_install_yes"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_install_yes"
  DOTFILES_REGISTRY_URL="$url" fm_run registry install fm-demo-mod --yes
  fm_expect_rc 0
  test_start "fm_registry_install_yes_reports_installed"
  fm_expect_any "Installed" "fm-demo-mod"
  test_start "fm_registry_install_yes_materialises_the_module"
  if [[ -d "$XDG_DATA_HOME/dotfiles/modules/fm-demo-mod" ]]; then
    fm_pass "module unpacked under XDG_DATA_HOME"
  else
    fm_fail "module directory not created"
  fi
}

test_fm_registry_install_sha_mismatch() {
  fm_registry_clear_cache
  if ! fm_have_jq; then
    test_start "fm_registry_install_sha_mismatch"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # Supply-chain gate: an archive whose digest does not match the index must
  # be refused outright.
  local dir="$FM_SANDBOX/work/registry"
  fm_registry_fixture >/dev/null
  local bad="$FM_SANDBOX/work/registry-badsha.json"
  sed 's/"sha256": "[0-9a-f]*"/"sha256": "0000000000000000000000000000000000000000000000000000000000000000"/' \
    "$dir/index.json" >"$bad"
  test_start "fm_registry_install_sha_mismatch"
  DOTFILES_REGISTRY_URL="file://$bad" fm_run registry install fm-demo-mod --yes
  fm_expect_rc 1
  test_start "fm_registry_install_sha_mismatch_message"
  fm_expect_any "SHA-256 mismatch" "integrity" "validation"
}

test_fm_registry_install_errors() {
  fm_registry_clear_cache
  test_start "fm_registry_install_errors_missing_name"
  fm_run registry install
  fm_expect_rc 1
  test_start "fm_registry_install_errors_missing_name_message"
  fm_expect_any "missing module name" "install"
  if fm_have_jq; then
    local url
    url="$(fm_registry_url)"
    test_start "fm_registry_install_errors_unknown_module"
    DOTFILES_REGISTRY_URL="$url" fm_run registry install zzz-no-such-module
    fm_expect_rc 1
    test_start "fm_registry_install_errors_unknown_option"
    DOTFILES_REGISTRY_URL="$url" fm_run registry install fm-demo-mod --zzz-not-an-option
    fm_expect_rc 2
  fi
}

test_fm_registry_installed() {
  if ! fm_have_jq; then
    test_start "fm_registry_installed"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  test_start "fm_registry_installed"
  fm_run registry installed
  fm_expect_rc_in 0 1
  test_start "fm_registry_installed_no_breakage"
  fm_expect_no_forbidden
}

test_fm_registry_set_url() {
  local url
  url="$(fm_registry_url)"
  test_start "fm_registry_set_url"
  fm_run registry set-url "$url"
  fm_expect_rc 0
  test_start "fm_registry_set_url_persists_to_registry_toml"
  fm_expect_file "$XDG_CONFIG_HOME/dotfiles/registry.toml"
  test_start "fm_registry_set_url_is_read_back"
  fm_run registry url
  fm_expect_out "$url"
}

test_fm_registry_set_url_invalid() {
  # The index is unsigned, so HTTPS (or file:// for local testing) is the
  # only transport that gives integrity. Plain HTTP must be refused.
  test_start "fm_registry_set_url_invalid"
  fm_run registry set-url http://insecure.example/registry.json
  fm_expect_rc 1
  test_start "fm_registry_set_url_invalid_message"
  fm_expect_any "must use https" "https://"
  test_start "fm_registry_set_url_missing_url"
  fm_run registry set-url
  fm_expect_rc 1
}

test_fm_config_registry_toml() {
  local url
  url="$(fm_registry_url)"
  mkdir -p "$XDG_CONFIG_HOME/dotfiles"
  printf 'url = "%s"\n' "$url" >"$XDG_CONFIG_HOME/dotfiles/registry.toml"
  test_start "fm_config_registry_toml"
  fm_run registry url
  fm_expect_rc 0
  test_start "fm_config_registry_toml_url_key_is_honoured"
  fm_expect_out "$url"
}

test_fm_env_dotfiles_registry_url() {
  # The env var must win over the persisted config file.
  local url
  url="$(fm_registry_url)"
  mkdir -p "$XDG_CONFIG_HOME/dotfiles"
  printf 'url = "https://config-file.example/registry.json"\n' \
    >"$XDG_CONFIG_HOME/dotfiles/registry.toml"
  test_start "fm_env_dotfiles_registry_url"
  DOTFILES_REGISTRY_URL="$url" fm_run registry url
  fm_expect_rc 0
  test_start "fm_env_dotfiles_registry_url_overrides_the_config_file"
  fm_expect_out "$url"
  rm -f "$XDG_CONFIG_HOME/dotfiles/registry.toml"
}

test_fm_registry_help() {
  test_start "fm_registry_help"
  fm_run registry --help
  fm_expect_rc 0
  test_start "fm_registry_help_lists_subcommands"
  fm_expect_any "list" "search" "install"
}

test_fm_registry_unknown() {
  test_start "fm_registry_unknown"
  fm_run registry zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_registry_unknown_message"
  fm_expect_any "Unknown subcommand" "zzz-not-a-subcommand"
}

# ── patterns ───────────────────────────────────────────────────────────────

fm_pattern_fixture() {
  mkdir -p "$XDG_CONFIG_HOME/ai/patterns"
  printf '# FM demo pattern\n\nSteer like a fixture.\n' \
    >"$XDG_CONFIG_HOME/ai/patterns/fm-demo.md"
}

test_fm_patterns_list() {
  fm_pattern_fixture
  test_start "fm_patterns_list"
  fm_run patterns list
  fm_expect_rc_in 0 1
  test_start "fm_patterns_list_shows_the_pattern"
  fm_expect_out "fm-demo"
  test_start "fm_patterns_defaults_to_list"
  fm_run patterns
  fm_expect_out "fm-demo"
}

test_fm_patterns_view() {
  fm_pattern_fixture
  test_start "fm_patterns_view"
  fm_run patterns view fm-demo
  fm_expect_rc_in 0 1
  test_start "fm_patterns_view_renders_the_body"
  fm_expect_any "Steer like a fixture" "FM demo pattern"
}

test_fm_patterns_view_missing() {
  test_start "fm_patterns_view_missing"
  fm_run patterns view
  fm_expect_rc 1
  test_start "fm_patterns_view_missing_message"
  fm_expect_any "Missing pattern name" "Usage: dot patterns view"
  test_start "fm_patterns_view_unknown_pattern"
  fm_run patterns view zzz-no-such-pattern
  fm_expect_any "Pattern not found" "zzz-no-such-pattern"
}

test_fm_patterns_edit() {
  fm_pattern_fixture
  fm_stub fm-pattern-editor "printf '%s\\n' \"\$1\" >'$FM_SANDBOX/pattern-edited'"
  test_start "fm_patterns_edit"
  EDITOR="$FM_SANDBOX/bin/fm-pattern-editor" fm_run patterns edit fm-demo
  fm_expect_rc_in 0 1
  test_start "fm_patterns_edit_opens_the_pattern_file"
  if [[ -s "$FM_SANDBOX/pattern-edited" ]] &&
    grep -q 'fm-demo.md' "$FM_SANDBOX/pattern-edited"; then
    fm_pass "editor received the pattern path"
  else
    fm_fail "\$EDITOR was not called with the pattern file"
  fi
  rm -f "$FM_SANDBOX/pattern-edited"
}

test_fm_patterns_edit_missing() {
  test_start "fm_patterns_edit_missing"
  fm_run patterns edit
  fm_expect_rc 1
  test_start "fm_patterns_edit_missing_message"
  fm_expect_any "Missing pattern name" "Usage: dot patterns edit"
}

test_fm_patterns_unknown() {
  test_start "fm_patterns_unknown"
  fm_run patterns zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_patterns_unknown_prints_usage"
  fm_expect_any "Usage: dot patterns" "list|view|edit"
}

test_fm_env_xdg_config_home() {
  # Patterns live under XDG_CONFIG_HOME/ai/patterns; point that elsewhere and
  # the listing must follow.
  local alt="$FM_SANDBOX/work/altconfig"
  mkdir -p "$alt/ai/patterns"
  printf '# alt\n' >"$alt/ai/patterns/fm-alt-pattern.md"
  test_start "fm_env_xdg_config_home"
  XDG_CONFIG_HOME="$alt" fm_run patterns list
  fm_expect_rc_in 0 1
  test_start "fm_env_xdg_config_home_relocates_the_pattern_dir"
  fm_expect_out "fm-alt-pattern"
}

# ── completion ─────────────────────────────────────────────────────────────

fm_assert_completion() {
  local shell="$1"
  shift
  test_start "fm_completion_${shell}"
  fm_run completion "$shell"
  if [[ "$FM_RC" -ne 0 ]]; then
    fm_fail "dot completion $shell exited $FM_RC"
    return 0
  fi
  local needle
  for needle in "$@"; do
    if [[ "$FM_OUT" != *"$needle"* ]]; then
      fm_fail "completion output lacks '$needle'"
      return 0
    fi
  done
  fm_pass "generated"
}

test_fm_completion_bash() { fm_assert_completion bash "complete -W" "dot"; }
test_fm_completion_zsh() { fm_assert_completion zsh "#compdef dot" "_describe"; }
test_fm_completion_fish() { fm_assert_completion fish "complete -c dot"; }

test_fm_completion_nu() {
  fm_assert_completion nu "export extern dot" "dot_commands"
  test_start "fm_completion_nushell_alias"
  fm_run completion nushell
  fm_expect_rc 0
  test_start "fm_completion_nushell_alias_matches_nu"
  fm_expect_out "export extern dot"
}

test_fm_completion_covers_the_registry() {
  # Completions are generated from _dot_help_specs, so a command in the
  # overview must appear in every dialect. `doctor` is the canary.
  local shell
  for shell in bash zsh fish nu; do
    test_start "fm_completion_covers_the_registry_${shell}"
    fm_run completion "$shell"
    if [[ "$FM_OUT" == *"doctor"* ]]; then
      fm_pass
    else
      fm_fail "'doctor' missing from the $shell completion"
    fi
  done
}

test_fm_completion_usage() {
  test_start "fm_completion_usage"
  fm_run completion
  fm_expect_rc 0
  test_start "fm_completion_usage_lists_the_shells"
  fm_expect_any "bash|zsh|fish|nu" "Usage: dot completion"
}

test_fm_completion_unknown() {
  test_start "fm_completion_unknown"
  fm_run completion zzz-not-a-shell
  fm_expect_rc 1
  test_start "fm_completion_unknown_message"
  fm_expect_any "unknown shell" "bash|zsh|fish|nu"
}

# ── init ───────────────────────────────────────────────────────────────────
#
# Every row is --dry-run or an argument rejection: a real init clones a
# remote repo and applies it over $HOME.

test_fm_init_dry_run() {
  test_start "fm_init_dry_run"
  fm_run init alice --dry-run
  fm_expect_rc 0
  test_start "fm_init_dry_run_resolves_the_github_url"
  fm_expect_out "https://github.com/alice/dotfiles.git"
  test_start "fm_init_dry_run_makes_no_changes"
  fm_expect_any "Dry-run" "no changes made"
}

test_fm_init_owner_repo() {
  test_start "fm_init_owner_repo"
  fm_run init alice/configs -n
  fm_expect_rc 0
  test_start "fm_init_owner_repo_resolves_the_url"
  fm_expect_out "https://github.com/alice/configs.git"
}

test_fm_init_url_no_apply() {
  test_start "fm_init_url_no_apply"
  fm_run init https://example.com/repo.git --dry-run --no-apply
  fm_expect_rc 0
  test_start "fm_init_url_no_apply_passes_the_url_through"
  fm_expect_out "https://example.com/repo.git"
  test_start "fm_init_url_no_apply_reports_apply_disabled"
  fm_expect_any "Apply after?" "no"
}

test_fm_init_reject_http() {
  # Plain HTTP would let a MITM choose the code that then runs with the
  # user's privileges.
  test_start "fm_init_reject_http"
  fm_run init http://insecure.example/repo.git
  fm_expect_rc 2
  test_start "fm_init_reject_http_message"
  fm_expect_any "refusing plain HTTP" "HTTPS"
  test_start "fm_init_reject_metacharacters"
  fm_run init 'bad;name'
  fm_expect_rc 2
  test_start "fm_init_reject_metacharacters_message"
  fm_expect_any "invalid user" "only [A-Za-z0-9._-]"
  test_start "fm_init_reject_bad_owner_repo"
  fm_run init 'owner/repo;rm'
  fm_expect_rc 2
}

test_fm_init_usage() {
  test_start "fm_init_usage"
  fm_run init
  fm_expect_rc 1
  test_start "fm_init_usage_message"
  fm_expect_any "missing <user|repo|url>" "init"
  test_start "fm_init_usage_unknown_flag"
  fm_run init --zzz-not-a-flag
  fm_expect_rc 1
  test_start "fm_init_usage_too_many_args"
  fm_run init alice bob
  fm_expect_rc 1
  test_start "fm_init_usage_too_many_args_message"
  fm_expect_any "Too many arguments" "bob"
}

test_fm_init_help() {
  test_start "fm_init_help"
  fm_run init --help
  fm_expect_rc 0
  test_start "fm_init_help_is_rendered"
  fm_expect_any "dot init" "Summary"
}

test_fm_smoke_init_apply() { fm_smoke init; }
test_fm_smoke_env_dotfiles_noninteractive() { fm_smoke init; }

# ── manual ─────────────────────────────────────────────────────────────────

fm_manual_offline_fixture() {
  local dir="$XDG_DATA_HOME/dotfiles/manual"
  mkdir -p "$dir"
  printf 'FM MANUAL OFFLINE BODY\n' >"$dir/dotfiles.txt"
  printf '%s\n' "$dir"
}

test_fm_manual_text_offline() {
  fm_manual_offline_fixture >/dev/null
  test_start "fm_manual_text_offline"
  fm_run manual text --offline
  fm_expect_rc 0
  test_start "fm_manual_text_offline_pipes_the_body"
  fm_expect_out "FM MANUAL OFFLINE BODY"
}

test_fm_manual_download_offline() {
  fm_manual_offline_fixture >/dev/null
  local prev="$PWD"
  mkdir -p "$FM_SANDBOX/work/manual-dl"
  cd "$FM_SANDBOX/work/manual-dl" || return 0
  test_start "fm_manual_download_offline"
  fm_run manual download text --offline
  fm_expect_rc 0
  test_start "fm_manual_download_offline_saves_the_file"
  fm_expect_file "$FM_SANDBOX/work/manual-dl/dotfiles.txt"
  cd "$prev" || return 0
}

test_fm_manual_offline_missing() {
  test_start "fm_manual_offline_missing"
  fm_run manual pdf --offline
  fm_expect_rc 1
  test_start "fm_manual_offline_missing_names_the_path"
  fm_expect_any "offline copy not found" "dotfiles.pdf"
  test_start "fm_manual_local_missing"
  fm_run manual text --local
  fm_expect_rc 1
  test_start "fm_manual_local_missing_points_at_the_builder"
  fm_expect_any "local build not found" "build-manual.sh"
}

test_fm_manual_help() {
  test_start "fm_manual_help"
  fm_run manual --help
  fm_expect_rc 0
  test_start "fm_manual_help_is_rendered"
  fm_expect_any "dot manual" "manual" "Summary"
}

test_fm_env_xdg_data_home() {
  # The offline manual is looked up under XDG_DATA_HOME.
  local alt="$FM_SANDBOX/work/altdata"
  mkdir -p "$alt/dotfiles/manual"
  printf 'FM ALT DATA MANUAL\n' >"$alt/dotfiles/manual/dotfiles.txt"
  test_start "fm_env_xdg_data_home"
  XDG_DATA_HOME="$alt" fm_run manual text --offline
  fm_expect_rc 0
  test_start "fm_env_xdg_data_home_relocates_the_offline_copy"
  fm_expect_out "FM ALT DATA MANUAL"
}

test_fm_env_pager() {
  # The text manual is piped through $PAGER.
  fm_manual_offline_fixture >/dev/null
  fm_stub fm-pager "printf 'PAGED:'; cat \"\$@\""
  test_start "fm_env_pager"
  PAGER="$FM_SANDBOX/bin/fm-pager" fm_run manual text --offline
  fm_expect_rc 0
  test_start "fm_env_pager_receives_the_manual"
  fm_expect_out "PAGED:"
}

test_fm_smoke_manual_open() { fm_smoke manual; }
test_fm_smoke_env_dotfiles_manual_url() { fm_smoke manual; }

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: fleet, registry, patterns, completion, init, manual ──"
echo ""

test_fm_fleet
test_fm_fleet_status
test_fm_fleet_json
test_fm_fleet_status_json
test_fm_config_fleet_node_id
test_fm_fleet_drift
test_fm_fleet_drift_history
test_fm_fleet_drift_predict
test_fm_fleet_drift_unknown
test_fm_fleet_events
test_fm_fleet_events_empty
test_fm_fleet_namespace
test_fm_fleet_ns_alias
test_fm_fleet_namespace_set
test_fm_fleet_namespace_set_invalid
test_fm_fleet_enforce
test_fm_fleet_enforce_set
test_fm_fleet_enforce_set_invalid
test_fm_fleet_apply_dry_run
test_fm_fleet_apply_host_cmd
test_fm_fleet_apply_host_unknown
test_fm_fleet_apply_verify_hosts
test_fm_fleet_apply_rejects_injection_hostname
test_fm_fleet_apply_no_hosts
test_fm_fleet_apply_help
test_fm_fleet_push_alias
test_fm_env_dotfiles_fleet_hosts
test_fm_config_fleet_toml
test_fm_smoke_fleet_apply_ssh
test_fm_fleet_unknown
test_fm_registry_url
test_fm_registry_list
test_fm_registry_list_empty
test_fm_registry_search
test_fm_registry_search_usage
test_fm_registry_info
test_fm_registry_info_unknown
test_fm_registry_install_dry_run
test_fm_registry_install_yes
test_fm_registry_install_sha_mismatch
test_fm_registry_install_errors
test_fm_registry_installed
test_fm_registry_set_url
test_fm_registry_set_url_invalid
test_fm_config_registry_toml
test_fm_env_dotfiles_registry_url
test_fm_registry_help
test_fm_registry_unknown
test_fm_patterns_list
test_fm_patterns_view
test_fm_patterns_view_missing
test_fm_patterns_edit
test_fm_patterns_edit_missing
test_fm_patterns_unknown
test_fm_env_xdg_config_home
test_fm_completion_bash
test_fm_completion_zsh
test_fm_completion_fish
test_fm_completion_nu
test_fm_completion_covers_the_registry
test_fm_completion_usage
test_fm_completion_unknown
test_fm_init_dry_run
test_fm_init_owner_repo
test_fm_init_url_no_apply
test_fm_init_reject_http
test_fm_init_usage
test_fm_init_help
test_fm_smoke_init_apply
test_fm_smoke_env_dotfiles_noninteractive
test_fm_manual_text_offline
test_fm_manual_download_offline
test_fm_manual_offline_missing
test_fm_manual_help
test_fm_env_xdg_data_home
test_fm_env_pager
test_fm_smoke_manual_open
test_fm_smoke_env_dotfiles_manual_url

fm_finish
