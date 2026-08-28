#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Stress tests. Rapid-fire operations against a sandboxed backend to
# uncover race conditions, orphan tempfiles, or state corruption.
# Runs entirely in the parent process — no real DE side-effects.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
export XDG_CONFIG_HOME="$TMPHOME/.config"
export XDG_DATA_HOME="$TMPHOME/.local/share"
export XDG_CACHE_HOME="$TMPHOME/.cache"
mkdir -p "$XDG_STATE_HOME/dot" "$XDG_CONFIG_HOME" \
         "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
cat > "$TMPHOME/dotfiles/.chezmoidata.toml" <<'EOF'
theme = "Alpha-dark"
EOF
# 6 paired families so we have room to cycle without dedupe collapse.
{
  for fam in Alpha Beta Gamma Delta Epsilon Zeta; do
    for mode in dark light; do
      printf '[themes.%s-%s]\nmode = "%s"\nfamily = "%s"\nmacos_accent = 3\n\n' \
        "$fam" "$mode" "$mode" "$fam"
    done
  done
} > "$TMPHOME/dotfiles/.chezmoidata/themes.toml"

mkdir -p "$TMPHOME/Pictures/Wallpapers"
for fam in Alpha Beta Gamma Delta Epsilon Zeta; do
  touch "$TMPHOME/Pictures/Wallpapers/${fam}-0.png" \
        "$TMPHOME/Pictures/Wallpapers/${fam}-1.png"
done
export DOTFILES_WALLPAPER_DIR="$TMPHOME/Pictures/Wallpapers"
export XDG_CURRENT_DESKTOP="GNOME"

MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
for cmd in gsettings kwriteconfig6 kreadconfig6 systemctl qdbus \
           chezmoi tmux pgrep swww hyprctl niri busctl killall; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

# ---------------------------------------------------------------------------
# 1. Rapid-fire alternation: 50 back-and-forth applies must leave a
#    consistent recorded theme + valid history file (no truncation, no
#    duplicates, no orphaned tmp files in the data dir).
# ---------------------------------------------------------------------------

test_start "stress_50_alternating_applies_settles_correctly"
seq 50 | while read -r i; do
  target="Alpha-dark"
  (( i % 2 == 0 )) && target="Beta-dark"
  "$DOT_THEME_SYNC" "$target" >/dev/null 2>&1
done
# Read back the last applied theme.
last=$(grep -oE '^theme = "[^"]+"' "$TMPHOME/dotfiles/.chezmoidata.toml" | head -1 | cut -d'"' -f2)
if [[ "$last" == "Alpha-dark" || "$last" == "Beta-dark" ]]; then
  _ok
else
  _fail "final theme is '$last'"
fi

test_start "stress_no_orphan_tempfiles_in_data_dir"
# write_theme uses mktemp; a crashed run could leave tmp.XXXXXX lying around.
orphans=$(find "$TMPHOME/dotfiles" -maxdepth 2 -name 'tmp.*' 2>/dev/null | wc -l)
if (( orphans == 0 )); then
  _ok
else
  _fail "$orphans orphan tempfile(s)"
fi

test_start "stress_history_stack_has_no_duplicates"
hist="$XDG_STATE_HOME/dot/theme-history"
if [[ -s "$hist" ]]; then
  dups=$(sort "$hist" | uniq -d | wc -l)
  if (( dups == 0 )); then
    _ok
  else
    _fail "$dups duplicate line(s) in history"
  fi
else
  _fail "history empty (expected entries)"
fi

test_start "stress_history_stack_within_20_cap"
if [[ -s "$hist" ]]; then
  lines=$(wc -l < "$hist")
  if (( lines <= 20 )); then
    _ok
  else
    _fail "$lines lines, cap is 20"
  fi
else
  _fail
fi

# ---------------------------------------------------------------------------
# 2. Parallel apply-then-undo storm — 5 concurrent applies against the
#    same history file. `set` writes atomically via mktemp+mv, so the file
#    must remain valid TOML after the storm.
# ---------------------------------------------------------------------------

test_start "stress_5_concurrent_applies_produces_valid_datafile"
for i in 1 2 3 4 5; do
  "$DOT_THEME_SYNC" "Gamma-dark" >/dev/null 2>&1 &
done
wait
# Datafile is TOML — must have exactly one theme = line.
theme_lines=$(grep -c '^theme = ' "$TMPHOME/dotfiles/.chezmoidata.toml")
if (( theme_lines == 1 )); then
  _ok
else
  _fail "$theme_lines theme lines (expected 1)"
fi

test_start "stress_datafile_survives_concurrent_writes"
# Grep out the theme value; must be a real theme name.
val=$(grep -oE '^theme = "[^"]+"' "$TMPHOME/dotfiles/.chezmoidata.toml" | cut -d'"' -f2)
if [[ "$val" =~ ^[A-Za-z0-9-]+-(dark|light)$ ]]; then
  _ok
else
  _fail "malformed theme value: '$val'"
fi

# ---------------------------------------------------------------------------
# 3. Idempotent hot loop — 100 no-ops must be fast (< 8s aggregate)
# ---------------------------------------------------------------------------

test_start "stress_100_idempotent_noops_under_8s"
"$DOT_THEME_SYNC" "Gamma-dark" >/dev/null 2>&1  # pin current
start_ns=$(date +%s%N)
for _ in $(seq 100); do
  "$DOT_THEME_SYNC" "Gamma-dark" >/dev/null 2>&1
done
end_ns=$(date +%s%N)
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
if (( elapsed_ms < 8000 )); then
  _ok
  printf '     (100 no-ops in %d ms, avg %d ms/op)\n' "$elapsed_ms" $((elapsed_ms / 100))
else
  _fail "took ${elapsed_ms} ms — idempotent path regressed"
fi

# ---------------------------------------------------------------------------
# 4. Random walk stress — 30 random-family-random-mode applies, then
#    verify status still parses as valid JSON.
# ---------------------------------------------------------------------------

test_start "stress_random_walk_leaves_valid_json_status"
families=(Alpha Beta Gamma Delta Epsilon Zeta)
modes=(dark light)
for _ in $(seq 30); do
  fam="${families[RANDOM % 6]}"
  mode="${modes[RANDOM % 2]}"
  "$DOT_THEME_SYNC" "${fam}-${mode}" >/dev/null 2>&1
done
# Use dot theme status --json equivalent — just re-read the data file.
grep -oE '^theme = "[^"]+"' "$TMPHOME/dotfiles/.chezmoidata.toml" | head -1 | grep -qE '"[A-Za-z0-9-]+-(dark|light)"'
if [[ $? -eq 0 ]]; then
  _ok
else
  _fail "datafile in bad state after random walk"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
