#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Behaviour of dot_local/bin/executable_corralctl-daily-run.sh: the nightly
# job finds mise-managed corralctl without `mise activate`, hands the Gitea
# credentials to the mirror only through the environment, skips the mirror
# when Gitea is unconfigured or down, and fails the unit when the mirror
# fails. Stubs replace corralctl, curl, podman and the mirror script, and
# HOME is a scratch directory, so nothing leaves the machine.
#
# AUTO-GENERATED: false (hand-written, do not regenerate)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_corralctl-daily-run.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAKE_HOME="$WORK/home"
SHIMS="$FAKE_HOME/.local/share/mise/shims"
LBIN="$FAKE_HOME/.local/bin"
CALLS="$WORK/calls.log"

# corralctl lives only where the script must add it to PATH itself: the
# mise shims directory. The mirror script lives in ~/.local/bin, as deployed.
_stubs() {
  rm -rf "$FAKE_HOME" && mkdir -p "$SHIMS" "$LBIN" "$FAKE_HOME/.config"
  : >"$CALLS"
  printf '#!/usr/bin/env bash\necho "corralctl $*" >>"%s"\n' "$CALLS" >"$SHIMS/corralctl"
  cat >"$LBIN/corralctl-gitea-mirror.sh" <<EOF
#!/usr/bin/env bash
echo "mirror \$* url=\${GITEA_URL:-} token=\${GITEA_TOKEN:-}" >>"$CALLS"
exit \${MIRROR_RC:-0}
EOF
  cat >"$LBIN/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >>"$CALLS"
exit \${HEALTH_RC:-0}
EOF
  cat >"$LBIN/podman" <<EOF
#!/usr/bin/env bash
echo "podman \$*" >>"$CALLS"
[[ "\$1" == ps ]] && printf '%s\n' \${CONTAINERS:-}
exit 0
EOF
  chmod +x "$SHIMS/corralctl" "$LBIN"/*
}
_env_file() { printf 'GITEA_URL=http://gitea.test\nGITEA_TOKEN=test-token\n' >"$FAKE_HOME/.config/corral-sync.env"; }

# No mise activation and no ~/.local/bin on the inherited PATH: only the
# system directories, as systemd starts a user unit.
_run() { HOME="$FAKE_HOME" PATH=/usr/bin:/bin bash "$SCRIPT_FILE" 2>&1; }

test_start "daily_run_reaches_corralctl_through_mise_shims"
_stubs
out="$(_run)"
assert_equals "0" "$?" "runs without mise activate"
assert_true 'grep -q "^corralctl status $FAKE_HOME/team-rousseau-workspace/repos$" "$CALLS"' \
  "corralctl status runs over the workspace"

test_start "daily_run_skips_mirror_without_env_file"
assert_contains "corral-sync.env missing; skipping Gitea sync" "$out" "the skip is reported"
assert_false 'grep -q "^mirror" "$CALLS"' "the mirror is not run"

test_start "daily_run_mirrors_with_credentials_from_env_file"
_stubs
_env_file
out="$(_run)"
assert_equals "0" "$?" "a healthy run succeeds"
assert_true 'grep -q "^curl .*http://gitea.test/api/healthz" "$CALLS"' "Gitea health is checked first"
assert_true 'grep -qx "mirror sync url=http://gitea.test token=test-token" "$CALLS"' \
  "the mirror syncs with the env file's URL and token exported"
assert_false 'grep -q "^curl .*test-token" "$CALLS"' "the token is not on the health check's command line"

test_start "daily_run_skips_mirror_when_gitea_unreachable"
_stubs
_env_file
out="$(HEALTH_RC=7 _run)"
assert_equals "0" "$?" "an unreachable NAS does not fail the run"
assert_contains "http://gitea.test unreachable; skipping Gitea sync" "$out" "the skip is reported"
assert_false 'grep -q "^mirror" "$CALLS"' "the mirror is not run"

test_start "daily_run_fails_when_mirror_fails"
_stubs
_env_file
out="$(MIRROR_RC=1 _run)"
assert_equals "1" "$?" "a mirror that leaves Gitea short of GitHub fails the unit"
assert_false 'grep -q "corralctl daily run completed" <<<"$out"' "and is not reported as completed"

test_start "daily_run_runs_corralctl_in_container_when_up"
_stubs
out="$(CONTAINERS=rousseau-agent _run)"
assert_true 'grep -q "^podman exec rousseau-agent /workspace/bin/corralctl status /workspace/repos$" "$CALLS"' \
  "corralctl status runs inside rousseau-agent"
_stubs
out="$(CONTAINERS=other _run)"
assert_contains "rousseau-agent container is not running" "$out" "a stopped container is skipped"
assert_false 'grep -q "^podman exec" "$CALLS"' "and nothing is exec'd"

test_start "daily_run_fails_without_corralctl"
_stubs
rm "$SHIMS/corralctl"
out="$(_run)"
assert_equals "1" "$?" "a missing corralctl fails the run"
assert_contains "corralctl not found locally" "$out" "and says why"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
