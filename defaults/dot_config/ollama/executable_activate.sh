#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
cd "$HOME"
plist="$HOME/Library/LaunchAgents/com.sebastienrousseau.ollama.plist"
label="gui/$(id -u)/com.sebastienrousseau.ollama"

# --- 1. Validate the LaunchAgent before touching anything ----------------
chezmoi cat "$plist" | plutil -lint -

# --- 2. Stop any ad-hoc server not owned by launchd ----------------------
# An agent launchd has not loaded yet has no pid; `print` fails then.
agent_pid="$(launchctl print "$label" 2>/dev/null | awk '/^	pid =/ {print $3}' || true)"
for pid in $(pgrep -f "ollama serve" || true); do
  [[ "$pid" == "${agent_pid:-}" ]] && continue
  kill "$pid"
done

# --- 3. Install (or reload) the LaunchAgent ------------------------------
chezmoi apply "$plist"
if launchctl print "$label" >/dev/null 2>&1; then
  launchctl kickstart -k "$label"
else
  launchctl bootstrap "gui/$(id -u)" "$plist"
fi
for _ in $(seq 1 30); do
  ollama list >/dev/null 2>&1 && break
  sleep 1
done
launchctl print "$label" | grep -E '^\s+(state|pid) ='
ollama list

# --- 4. Benchmark: one prompt per language, thinking off -----------------
python3 -I "$HOME/.config/ollama/bench.py"
ollama ps
sysctl vm.swapusage
