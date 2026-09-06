#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Branch-driving tests for scripts/diagnostics/doctor.sh.
#
# doctor.sh is a single top-to-bottom report with ~60 independent
# probes. Each scenario below builds a private HOME + a private bin dir
# of shims, then runs doctor with PATH restricted to that bin dir plus a
# "sysbin" of symlinked coreutils. Nothing from the host (mise, brew,
# hyperfine, system_profiler, pwsh, ...) leaks in, so every branch is
# selected by the fixture, the run is deterministic, and one run takes
# ~1s instead of ~20s.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 9 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 9>&2

DOCTOR_FILE="$REPO_ROOT/scripts/diagnostics/doctor.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"

# ── sysbin: the only host binaries doctor may see ──────────────────────
SYSBIN="$TMP/sysbin"
mkdir -p "$SYSBIN"
for tool in awk sed grep tr find date stat wc head tail basename dirname \
  readlink cut sort uniq cat mkdir mktemp printf hostname whoami rm touch ls env \
  python3 timeout locale tput; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
# bench.sh is launched as `bash …`; point that at the running interpreter.
ln -sf "$BASH" "$SYSBIN/bash"

# ── per-scenario fixture helpers ───────────────────────────────────────
S_BIN=""
S_HOME=""

# _new_scenario <name>: fresh HOME + bin dir for one doctor run.
_new_scenario() {
  local name="$1"
  S_BIN="$TMP/$name/bin"
  S_HOME="$TMP/$name/home"
  mkdir -p "$S_BIN" "$S_HOME/.config" "$S_HOME/.local/bin" \
    "$S_HOME/.local/share" "$S_HOME/.cache" "$S_HOME/.local/state"
}

# _shim <name>: write stdin as an executable shim into the scenario bin.
_shim() {
  cat >"$S_BIN/$1"
  chmod +x "$S_BIN/$1"
}

# _tool <name>...: generic "installed" tool that answers --version.
_tool() {
  local t
  for t in "$@"; do
    printf '#!/usr/bin/env bash\necho "%s 1.0.0"\nexit 0\n' "$t" >"$S_BIN/$t"
    chmod +x "$S_BIN/$t"
  done
}

# _uname <os>: uname shim reporting the given kernel name.
_uname() {
  local os="$1"
  _shim uname <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  -s) echo "$os" ;;
  -sr) echo "$os 6.1.0" ;;
  -m) echo "x86_64" ;;
  -p) echo "x86_64" ;;
  *) echo "$os" ;;
esac
EOF
}

# zsh shim: version string + interactive hook-count probe.
_zsh() {
  local hooks="${1:-1 1}"
  _shim zsh <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  --version) echo "zsh 5.9 (x86_64-apple-darwin)" ;;
  -i) echo "$hooks" ;;
  *) : ;;
esac
exit 0
EOF
}

# hyperfine + jq shims drive tests/performance/bench.sh deterministically:
# jq prints the "min ms" bench.sh compares against its thresholds.
_bench() {
  local min_ms="$1"
  _shim hyperfine <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  _shim jq <<EOF
#!/usr/bin/env bash
echo "$min_ms"
EOF
}

# _run_doctor [args...]: run doctor under the scenario's PATH/HOME.
# Extra env comes from the DOC_ENV array. Sets DOC_OUT and DOC_RC.
DOC_ENV=()
DOC_OUT=""
DOC_RC=0
_run_doctor() {
  DOC_RC=0
  DOC_OUT="$(
    cd "$S_HOME" &&
      env BASH_XTRACEFD=9 PATH="$S_BIN:$SYSBIN" \
        HOME="$S_HOME" \
        XDG_CONFIG_HOME="$S_HOME/.config" \
        XDG_DATA_HOME="$S_HOME/.local/share" \
        XDG_CACHE_HOME="$S_HOME/.cache" \
        XDG_STATE_HOME="$S_HOME/.local/state" \
        SHELL="$S_BIN/zsh" \
        DOTFILES_ACCESSIBILITY=1 \
        DOT_DOCTOR_OS_RELEASE="$S_HOME/os-release" \
        DOT_DOCTOR_PROC_ROOT="$S_HOME/proc" \
        DOT_DOCTOR_SYS_ROOT="$S_HOME/sys" \
        "${DOC_ENV[@]}" \
        "$BASH" "$DOCTOR_FILE" "$@" 2>&1 |
      sed -e 's/\x1b\[[0-9;]*m//g' -e 's/  */ /g'
    exit "${PIPESTATUS[0]}"
  )" || DOC_RC=$?
}

# _expect <label> <needle>...: every needle must appear in DOC_OUT.
_expect() {
  local label="$1"
  shift
  local needle missing=""
  for needle in "$@"; do
    [[ "$DOC_OUT" == *"$needle"* ]] || missing="${missing}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$missing" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$missing"
    printf '%s\n' "$DOC_OUT" | tail -n "${DOCTOR_TEST_TAIL:-30}" | sed 's/^/      /'
  fi
}

# _expect_absent <label> <needle>...: no needle may appear in DOC_OUT.
_expect_absent() {
  local label="$1"
  shift
  local needle found=""
  for needle in "$@"; do
    [[ "$DOC_OUT" == *"$needle"* ]] && found="${found}\n      unexpected: $needle"
  done
  test_start "$label"
  if [[ -z "$found" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$found"
  fi
}

_linux_os_release() {
  cat >"$S_HOME/os-release" <<'EOF'
ID=fixturelinux
PRETTY_NAME="Fixture Linux 2026"
EOF
}

# =======================================================================
# S1 — macOS, everything installed and healthy: exit 0, zero warnings.
# =======================================================================
_new_scenario s1
_uname Darwin
_zsh "1 1"
_tool fish starship nu rg bat fzf zoxide atuin yazi zellij \
  pueue pueued wasmtime nix sops age \
  claude copilot kimi agy sgpt ollama opencode aider kiro-cli \
  cargo-install-update mise direnv pyenv fnm kubectl pwsh \
  sw_vers sysctl vm_stat system_profiler brew
_bench 10
_shim chezmoi <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  verify) exit 0 ;;
  managed) printf '%s\n' "$S_HOME/.config/zsh/clean.zsh" "$S_HOME/.config/absent.conf" "$S_HOME/other.txt" ;;
esac
exit 0
EOF
_shim uptime <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "-p" ]] && exit 1
echo " 10:00  up 2 days,  3:04, 2 users, load averages: 1.00 1.00 1.00"
EOF
_shim sw_vers <<'EOF'
#!/usr/bin/env bash
echo "15.0"
EOF
_shim sysctl <<'EOF'
#!/usr/bin/env bash
case "${2:-}" in
  hw.model) echo "Mac16,1" ;;
  machdep.cpu.brand_string) echo "Fixture M-series" ;;
  hw.ncpu) echo "8" ;;
  hw.memsize) echo "17179869184" ;;
  *) echo "0" ;;
esac
EOF
_shim vm_stat <<'EOF'
#!/usr/bin/env bash
echo "Pages active:                     100000."
EOF
_shim system_profiler <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  SPDisplaysDataType) printf '%s\n' "      Chipset Model: Fixture GPU" "          Resolution: 2560 x 1440" ;;
  *) echo "      Model Name: FixtureBook" ;;
esac
EOF
# dot + antigravity live where doctor expects them.
printf '#!/usr/bin/env bash\nexit 0\n' >"$S_HOME/.local/bin/dot"
printf '#!/usr/bin/env bash\nexit 0\n' >"$S_HOME/.local/bin/antigravity"
chmod +x "$S_HOME/.local/bin/dot" "$S_HOME/.local/bin/antigravity"
printf '# zshrc\n' >"$S_HOME/.zshrc"
mkdir -p "$S_HOME/.config/atuin" "$S_HOME/.config/fish" "$S_HOME/.config/zsh" \
  "$S_HOME/.config/nushell" "$S_HOME/.config/powershell" "$S_HOME/.config/shell"
{
  echo 'history_filter = ['
  for pat in token secret password apikey api_key bearer private_key ssh-rsa aws_access_key npm_ ghp_; do
    printf '  "%s",\n' "$pat"
  done
  echo ']'
} >"$S_HOME/.config/atuin/config.toml"
printf 'jorgebucaran/fisher\n' >"$S_HOME/.config/fish/fish_plugins"
printf 'eval "$(pyenv init -)"\n_lazy_load_fnm\n' >"$S_HOME/.config/zsh/tools.zsh"
printf '# clean\n' >"$S_HOME/.config/zsh/clean.zsh"
printf 'touch\n' >"$S_HOME/.config/nushell/cached_eval.nu"
printf 'Get-DotfilesCachedInit\n' >"$S_HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
# Symlinks that must be ignored by the broken-link scan.
mkdir -p "$S_HOME/.config/google-chrome-backup" "$S_HOME/.ssh"
ln -s /nonexistent "$S_HOME/.config/google-chrome-backup/lock"
ln -s /nonexistent "$S_HOME/.config/SingletonLock"
ln -s "$S_HOME/.zshrc" "$S_HOME/.config/zsh/live-link"
ln -s "$S_HOME/Library/Caches/org.swift.swiftpm" "$S_HOME/.config/swiftpm-cache"
# Fresh shell caches (tool binaries dated in the past so cache is newer).
for t in mise starship zoxide atuin fzf direnv pyenv; do
  touch -t 202001010000 "$S_BIN/$t"
  for shdir in zsh bash fish; do
    mkdir -p "$S_HOME/.cache/$shdir"
    if [[ "$shdir" == fish ]]; then
      printf '# cached\n' >"$S_HOME/.cache/fish/${t}-init.fish"
    else
      printf '# cached\n' >"$S_HOME/.cache/$shdir/${t}-init.$shdir"
    fi
  done
done
printf '# dump\n' >"$S_HOME/.zcompdump"
printf 'x' >"$S_HOME/.zcompdump.zwc"
mkdir -p "$S_HOME/.cache/dotfiles" "$S_HOME/.local/state/dotfiles"
printf '{"recorded_at": "2026-01-01T00:00:00Z"}\n' >"$S_HOME/.cache/dotfiles/perf-baseline.json"
printf '{"label":"starship","ms":40}\n{"label":"zoxide","ms":5}\nnot-json\n' \
  >"$S_HOME/.local/state/dotfiles/eval-timings.jsonl"

DOC_ENV=(PIPX_HOME="$S_HOME/.local/pipx" TERM_PROGRAM=FixtureTerm)
_run_doctor
test_start "s1_darwin_healthy_exit_0"
assert_equals 0 "$DOC_RC" "healthy macOS scenario exits 0"
_expect "s1_darwin_platform_lines" \
  "macOS 15.0" "Fixture M-series (8)" "Fixture GPU" "2560 x 1440" \
  "(brew)" "Aqua" "FixtureTerm" "zsh 5.9" "2 days"
_expect "s1_all_probes_ok" \
  "[OK] zsh" "[OK] nu" "[OK] bat" "[OK] nix" "[OK] pueue daemon" \
  "[OK] XDG_CONFIG_HOME" "[OK] PIPX_HOME" "[OK] chezmoi" "[OK] .zshrc" \
  "[OK] dot" "[OK] audit bypass" "[OK] history_filter" "[OK] antigravity wrapper" \
  "[OK] fish_plugins" "[OK] cargo-install-update" "[OK] symlinks" \
  "[OK] portability" "[OK] shell caches" "[OK] uncached slow-init tools" \
  "[OK] .zcompdump" "[OK] PATH length" "[OK] shell coverage" "[OK] zsh hooks" \
  "[OK] startup latency" "[OK] perf baseline" "[OK] perf top-tools" \
  "starship(40ms), zoxide(5ms)" "All checks passed."
_expect_absent "s1_no_warnings_or_errors" "[WARN]" "[FAIL]"

# =======================================================================
# S2 — Linux under WSL with lots of drift, run with --ai: exit 1 and the
# AI analysis hook fires through the ~/.local/bin/dot shim.
# =======================================================================
_new_scenario s2
_uname Linux
_zsh "9 9"
_tool pueue pueued batcat wasmtime age hyperfine \
  mise zoxide atuin fzf direnv pyenv pwsh \
  lscpu lspci free wlr-randr dpkg wslpath
_bench 9999
_linux_os_release
mkdir -p "$S_HOME/proc" "$S_HOME/sys/devices/virtual/dmi/id"
printf 'Linux version 6.10.0-microsoft-standard-WSL2\n' >"$S_HOME/proc/version"
printf 'FixtureBook\n' >"$S_HOME/sys/devices/virtual/dmi/id/product_name"
_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 3 hours, 2 minutes"
EOF
_shim lscpu <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "CPU(s):              4" "Model name:          Fixture CPU"
EOF
_shim lspci <<'EOF'
#!/usr/bin/env bash
echo "00:02.0 VGA compatible controller: Fixture Graphics"
EOF
_shim free <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "              total        used        free" "Mem:     8589934592  4294967296  4294967296"
EOF
_shim wlr-randr <<'EOF'
#!/usr/bin/env bash
echo "1920x1080 current"
EOF
_shim dpkg <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "bash install" "zsh install" "git install"
EOF
# starship is resolved through the mise fallback and lives in /usr/bin.
_shim mise <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  ls) echo "starship 1.20.0" ;;
  bin-paths) echo "/usr/bin/starship" ;;
esac
exit 0
EOF
# pueue: status fails until pueued has been started.
_shim pueue <<EOF
#!/usr/bin/env bash
[[ -f "$S_HOME/pueued.started" ]] && exit 0
exit 1
EOF
_shim pueued <<EOF
#!/usr/bin/env bash
touch "$S_HOME/pueued.started"
exit 0
EOF
# dot at the expected path; `dot doctor` must report issues for --ai.
cat >"$S_HOME/.local/bin/dot" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  doctor) echo "[FAIL] chezmoi drifted"; echo "⚠ something" ;;
  ai) echo "ai-called: $*" ;;
esac
exit 0
EOF
chmod +x "$S_HOME/.local/bin/dot"
printf '#!/usr/bin/env bash\nexit 0\n' >"$S_BIN/antigravity"
chmod +x "$S_BIN/antigravity"
mkdir -p "$S_HOME/.config/atuin" "$S_HOME/.config/fish" "$S_HOME/.config/zsh" \
  "$S_HOME/.local/state/dotfiles"
printf 'history_filter = [\n  "token"\n]\n' >"$S_HOME/.config/atuin/config.toml"
printf 'someone/else\n' >"$S_HOME/.config/fish/fish_plugins"
printf 'eval "$(pyenv init -)"\n' >"$S_HOME/.config/zsh/tools.zsh"
ln -s /nonexistent/target "$S_HOME/.config/dangling"
printf '%s bypassed audit\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  >"$S_HOME/.local/state/dotfiles/audit-bypass.log"
printf '# dump\n' >"$S_HOME/.zcompdump"
touch -t 202001010000 "$S_HOME/.zcompdump"
long_path="$S_BIN:$SYSBIN"
for i in $(seq 1 125); do long_path="$long_path:$S_HOME/pathpad/$i"; done

DOC_ENV=(XDG_CONFIG_HOME= XDG_DATA_HOME=relative/data PIPX_HOME= TERM_PROGRAM=)
# Override the restricted PATH with the padded one for this run only.
SYSBIN_SAVED="$SYSBIN"
SYSBIN="$SYSBIN:${long_path#"$S_BIN:$SYSBIN":}"
_run_doctor --ai
SYSBIN="$SYSBIN_SAVED"
test_start "s2_linux_wsl_errors_exit_1"
assert_equals 1 "$DOC_RC" "scenario with failures exits 1"
_expect "s2_linux_wsl_platform" \
  "Fixture Linux 2026 (WSL)" "FixtureBook" "Fixture CPU (4)" "Fixture Graphics" \
  "1920x1080" "3 (dpkg)" "Windows Desktop (WSL)" "Windows Terminal" \
  "3 hours, 2 minutes" "[OK] WSL bridge" "[OK] WSL filesystem"
_expect "s2_tool_resolution" \
  "[OK] starship" "/usr/bin/starship/starship (system)" "[WARN] fish" "[OK] zsh" \
  "[WARN] nu" "[OK] bat" "(batcat)" "[FAIL] chezmoi" "[OK] nix optional (not installed)" "[FAIL] sops" \
  "[OK] pueue daemon" "started" "[WARN] claude"
_expect "s2_environment_and_state" \
  "[WARN] XDG_CONFIG_HOME" "[WARN] XDG_DATA_HOME" "not absolute: relative/data" \
  "[WARN] PIPX_HOME" "[FAIL] chezmoi" "drifted" "[FAIL] .zshrc" "[OK] dot" \
  "[WARN] audit bypass" "1 push(es) bypassed" "[WARN] history_filter" "1 patterns" \
  "[WARN] antigravity wrapper" "expected ~/.local/bin/antigravity" \
  "[WARN] fish_plugins" "missing jorgebucaran/fisher" "[WARN] cargo-install-update" \
  "[WARN] symlinks" "1 broken: ~/.config/dangling" "[WARN] portability" "scan skipped"
_expect "s2_performance_warnings" \
  "[WARN] shell caches" "stale (mise, zoxide, atuin, fzf, direnv)" \
  "[WARN] uncached slow-init tools" "pyenv" "[WARN] .zcompdump" "refresh:" \
  "[WARN] .zcompdump.zwc" "[FAIL] PATH length" "likely slowing" \
  "[WARN] shell coverage" "pwsh installed" "[WARN] zsh hooks" "precmd=9 preexec=9" \
  "[WARN] startup latency" "run dot prewarm"
_expect "s2_ai_analysis_fires" \
  "error(s)" "AI Problem Analysis" "ai-called: ai claude --style hardener"

# =======================================================================
# S3 — Linux (no WSL) with the alternate probes: nushell, mise-managed
# starship, /proc/meminfo, xrandr, rpm, ghost paths, old bypass log.
# =======================================================================
_new_scenario s3
_uname Linux
_zsh "1 1"
_tool fish nushell rg bat fzf zoxide atuin yazi zellij pueue wasmtime nix \
  sops age hyperfine claude copilot kimi agy sgpt ollama opencode aider kiro-cli \
  cargo-install-update mise xrandr rpm
_bench 9999
_linux_os_release
mkdir -p "$S_HOME/proc" "$S_HOME/sys" "$S_HOME/.config/atuin" "$S_HOME/.config/zsh" \
  "$S_HOME/.local/state/dotfiles"
printf 'MemTotal:        8388608 kB\nMemAvailable:    4194304 kB\n' >"$S_HOME/proc/meminfo"
printf 'processor\t: 0\nmodel name\t: Fixture CPU\nprocessor\t: 1\n' >"$S_HOME/proc/cpuinfo"
_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 1 hour"
EOF
_shim xrandr <<'EOF'
#!/usr/bin/env bash
echo "   1600x900     60.00*+"
EOF
_shim rpm <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "bash-5.2" "zsh-5.9"
EOF
_shim mise <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  ls) echo "starship 1.20.0" ;;
  bin-paths) echo "$S_HOME/.local/share/mise/installs/starship/1.20.0/bin" ;;
esac
exit 0
EOF
_shim pueue <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_shim chezmoi <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  verify) exit 0 ;;
  managed) printf '%s\n' "$S_HOME/.config/zsh/ghost.zsh" ;;
esac
exit 0
EOF
printf 'export FOO="/Users/someone/bin"\nexport BAR="/home/other/x"\n' >"$S_HOME/.config/zsh/ghost.zsh"
printf 'other = 1\n' >"$S_HOME/.config/atuin/config.toml"
printf '2001-01-01T00:00:00Z bypassed audit\n' >"$S_HOME/.local/state/dotfiles/audit-bypass.log"
printf '# zshrc\n' >"$S_HOME/.zshrc"
printf '# dump\n' >"$S_HOME/.zcompdump"
printf 'x' >"$S_HOME/.zcompdump.zwc"
for t in mise starship zoxide atuin fzf direnv; do
  [[ -f "$S_BIN/$t" ]] && touch -t 202001010000 "$S_BIN/$t"
  for shdir in zsh bash fish; do
    mkdir -p "$S_HOME/.cache/$shdir"
    if [[ "$shdir" == fish ]]; then
      printf '# cached\n' >"$S_HOME/.cache/fish/${t}-init.fish"
    else
      printf '# cached\n' >"$S_HOME/.cache/$shdir/${t}-init.$shdir"
    fi
  done
done

DOC_ENV=(PIPX_HOME= TERM_PROGRAM=)
_run_doctor
test_start "s3_linux_alt_probes_exit_1"
assert_equals 1 "$DOC_RC" "dot missing is a failure"
_expect "s3_linux_alt_platform" \
  "Fixture Linux 2026" "Linux" "Fixture CPU (2)" "1600x900" "2 (rpm)" \
  "4.00 GiB / 8.00 GiB" "GPU: n/a" "1 hour"
_expect "s3_alt_tool_paths" \
  "[OK] starship" "(mise)" "[OK] nu" "[WARN] pueue daemon" "not running (pueued -d)" \
  "[FAIL] dot" "not found in PATH" "[OK] audit bypass" "no recent entries" \
  "[FAIL] history_filter" "no history_filter block" "[WARN] antigravity" \
  "[FAIL] fish_plugins" "[WARN] portability" "2 hardcoded paths" \
  "[OK] shell caches" "[WARN] startup latency" "caches already fresh"
_expect_absent "s3_no_wsl" "(WSL)"

# =======================================================================
# S4 — Linux, warnings only (exit 0): dot elsewhere on PATH, atuin
# config absent, xdpyinfo + pacman probes, PATH in the warn band.
# =======================================================================
_new_scenario s4
_uname Linux
_zsh "1 1"
_tool fish starship nu rg bat fzf zoxide atuin yazi zellij pueue wasmtime nix \
  sops age dot xdpyinfo pacman
_bench 9999
_linux_os_release
mkdir -p "$S_HOME/proc" "$S_HOME/sys" "$S_HOME/.config/fish"
_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 5 minutes"
EOF
_shim xdpyinfo <<'EOF'
#!/usr/bin/env bash
echo "  dimensions:    1280x720 pixels"
EOF
_shim pacman <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "bash 5.2" "zsh 5.9" "git 2.4" "vim 9"
EOF
_shim pueue <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
_shim chezmoi <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
printf 'jorgebucaran/fisher\n' >"$S_HOME/.config/fish/fish_plugins"
printf '# zshrc\n' >"$S_HOME/.zshrc"
mid_path="$S_BIN:$SYSBIN"
for i in $(seq 1 95); do mid_path="$mid_path:$S_HOME/pathpad/$i"; done
DOC_ENV=(PIPX_HOME= TERM_PROGRAM=)
SYSBIN_SAVED="$SYSBIN"
SYSBIN="$SYSBIN:${mid_path#"$S_BIN:$SYSBIN":}"
_run_doctor
SYSBIN="$SYSBIN_SAVED"
test_start "s4_linux_warnings_only_exit_0"
assert_equals 0 "$DOC_RC" "warnings-only scenario exits 0"
_expect "s4_warning_band_probes" \
  "1280x720" "4 (pacman)" "Memory: n/a" "[WARN] dot" "(expected ~/.local/bin/dot)" \
  "[WARN] atuin config" "not found" "[WARN] PATH length" "consider pruning" \
  "[WARN] startup latency" "[OK] Healthy" "warning(s)."
_expect_absent "s4_no_failures" "[FAIL]"

# =======================================================================
# S5 — unknown OS with an empty toolbox: every "missing" branch.
# =======================================================================
_new_scenario s5
_uname FreeBSD
_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 1 day"
EOF
DOC_ENV=(PIPX_HOME= TERM_PROGRAM=)
_run_doctor
test_start "s5_unknown_os_exit_1"
assert_equals 1 "$DOC_RC" "missing core tools exit 1"
_expect "s5_unknown_os_fallback" \
  "FreeBSD 6.1.0" "Host: unknown" "CPU: x86_64 (?)" "Packages: n/a" \
  "DE: n/a" "[FAIL] zsh" "[WARN] fish" "[FAIL] starship" "[WARN] nu" \
  "[FAIL] rg" "[OK] nix" "optional (not installed)" "[FAIL] age" "[WARN] claude" \
  "[FAIL] chezmoi" "[FAIL] .zshrc" "[FAIL] dot" "[WARN] antigravity" \
  "[FAIL] fish_plugins" "[WARN] cargo-install-update" "[OK] symlinks" \
  "[WARN] portability" "[OK] shell caches" "[OK] PATH length" \
  "[WARN] hyperfine" "Run 'dot heal' to repair."

# =======================================================================
# S6 — Linux with no hardware/resolution/package tooling at all.
# =======================================================================
_new_scenario s6
_uname Linux
_linux_os_release
mkdir -p "$S_HOME/proc" "$S_HOME/sys"
_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 2 minutes"
EOF
DOC_ENV=(PIPX_HOME= TERM_PROGRAM=)
_run_doctor
test_start "s6_linux_bare_exit_1"
assert_equals 1 "$DOC_RC" "bare Linux still fails on missing core tools"
_expect "s6_linux_bare_platform" \
  "Fixture Linux 2026" "Host: Linux" "Resolution: n/a" "Packages: 0 (pkg)" \
  "Memory: n/a" "GPU: n/a"

# =======================================================================
# S7 — WSL without wslpath: the WSL-bridge warning arm.
# =======================================================================
_new_scenario s7
_uname Linux
_linux_os_release
mkdir -p "$S_HOME/proc" "$S_HOME/sys"
printf 'Linux version 6.10.0-microsoft-standard-WSL2\n' >"$S_HOME/proc/version"
_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 4 minutes"
EOF
DOC_ENV=(PIPX_HOME= TERM_PROGRAM=)
_run_doctor
_expect "s7_wsl_without_wslpath" \
  "(WSL)" "[WARN] WSL bridge" "wslpath missing" "[OK] WSL filesystem" "native"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
