#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Daily run of corralctl locally and in the rousseau-agent container.
# Triggered daily at 04:00 by corralctl.timer.
set -euo pipefail

# systemd starts this without `mise activate`; the shims are how a
# non-interactive context reaches mise-managed corralctl.
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
workspace="$HOME/team-rousseau-workspace/repos"

echo "=== [$(date -Iseconds)] Running corralctl locally ==="
command -v corralctl >/dev/null 2>&1 || {
  echo "ERROR: corralctl not found locally" >&2
  exit 1
}
corralctl --version
corralctl status "$workspace"

echo "=== [$(date -Iseconds)] Mirroring GitHub to NAS Gitea ==="
sync_env="$HOME/.config/corral-sync.env"
if [[ ! -r "$sync_env" ]]; then
  echo "NOTICE: $sync_env missing; skipping Gitea sync."
else
  set -a
  # shellcheck source=/dev/null
  . "$sync_env"
  set +a
  # -q: ignore ~/.config/curl/.curlrc (forces https, browser headers).
  if curl -q -sf -o /dev/null --max-time 10 "$GITEA_URL/api/healthz"; then
    # Gitea mirrors GitHub, not the working clones: the mirror tree holds
    # a forced, pruned copy of every GitHub branch and tag.
    corralctl-gitea-mirror.sh sync
  else
    echo "NOTICE: $GITEA_URL unreachable; skipping Gitea sync."
  fi
fi

echo "=== [$(date -Iseconds)] Running corralctl in rousseau-agent container ==="
if command -v podman >/dev/null 2>&1 && podman ps --format "{{.Names}}" | grep -qx "rousseau-agent"; then
  podman exec rousseau-agent /workspace/bin/corralctl --version
  podman exec rousseau-agent /workspace/bin/corralctl status /workspace/repos
else
  echo "NOTICE: rousseau-agent container is not running; skipping container execution."
fi

echo "=== [$(date -Iseconds)] corralctl daily run completed ==="
