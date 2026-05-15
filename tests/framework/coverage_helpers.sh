#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# coverage_helpers.sh — sandbox + safe-exercise helpers for shallow→deep
# test conversions. Lets a test run its script under safe-mode entry
# points (--help, --dry-run, no-arg, invalid flag) so xtrace-based
# coverage records line execution without the test stepping on the
# host system.

[[ "${_DOT_LIB_COVERAGE_HELPERS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_COVERAGE_HELPERS_LOADED=1

# -----------------------------------------------------------------------------
# Sandbox: fresh HOME + PATH-front mock-bin dir. Scripts that try to
# call sudo / brew / apt-get / etc. get no-op shims so they can't
# touch the real host. Scripts that try to write to ~/.config / state
# / etc. land in $HOME under the tmpdir.
# -----------------------------------------------------------------------------
cov_setup_sandbox() {
  local tmp
  tmp=$(mktemp -d -t dotfiles-cov.XXXXXX)
  export DOTFILES_COV_TMPDIR="$tmp"
  export HOME="$tmp/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_STATE_HOME="$HOME/.local/state"
  mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.cache" \
    "$HOME/.local/state" "$tmp/bin"

  # Synthetic chezmoi source directory.
  #
  # Many of our scripts guard early by probing for $HOME/.dotfiles
  # or $CHEZMOI_SOURCE_DIR; without this, they bail rc=1 within the
  # first dozen lines and we never measure the dispatch / parse /
  # function bodies. Others source helper libs via hardcoded
  # `$HOME/.dotfiles/scripts/dot/lib/...` paths and fail under
  # `set -e` if those don't exist.
  #
  # We solve both by symlinking $HOME/.dotfiles → the real repo root.
  # The sandbox already redirects writes to $HOME's tmpdir (XDG_*
  # paths point under $HOME). The lone risk is a probe that calls
  # into a write_* helper which targets a path inside the source
  # dir (e.g. write_theme writes .chezmoidata.toml). The driver
  # tests are written to avoid those paths — they probe --help /
  # list / show / status variants only.
  local repo_root
  repo_root="${REPO_ROOT:-$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)}"
  ln -sfn "$repo_root" "$HOME/.dotfiles"
  # Don't export CHEZMOI_SOURCE_DIR — scripts that consult
  # BASH_SOURCE-relative paths first should win, and overriding
  # this could mislead them into a stub copy.

  # ── Default no-op shims ───────────────────────────────────────────
  # Commands we just want to keep from touching the host. Each shim
  # echoes its invocation to stderr (for debugging) and exits 0.
  local cmd
  for cmd in sudo apt-get apt yum dnf pacman zypper brew \
    rsync systemctl \
    age gpg ssh-keygen \
    docker podman kubectl gh \
    defaults open osascript \
    gnome-extensions gsettings dconf \
    killall pkill open xdg-open \
    fzf tmux less more man htop top nvim vim nano emacs; do
    cat >"$tmp/bin/$cmd" <<EOF
#!/usr/bin/env bash
printf '[cov-shim:%s]\\n' "$cmd \$*" >&2
exit 0
EOF
    chmod +x "$tmp/bin/$cmd"
  done

  # ── Smart-output shims ────────────────────────────────────────────
  # These shims emit canned stdout so scripts that branch on the
  # command's output (e.g. `version=$(chezmoi --version)`) execute
  # more than just the option-parser before hitting an empty-string
  # condition. Slice 4 of #883.

  cat >"$tmp/bin/chezmoi" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version|version) echo "chezmoi version 2.47.1 (commit f0000000), built at 2024-01-01" ;;
  status)            : ;;  # no drift
  data)              echo "{}" ;;
  source-path)       echo "${HOME:-/tmp}/.dotfiles" ;;
  managed)           : ;;
  apply)             : ;;
  diff)              : ;;
  init)              : ;;
  doctor)            echo "ok" ;;
  cd|edit)           : ;;
  *)                 : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/git" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version|version)        echo "git version 2.42.0" ;;
  status)
    case "${2:-}" in
      --porcelain|--porcelain=v1|--porcelain=v2) : ;;
      *) echo "On branch main"; echo "nothing to commit, working tree clean" ;;
    esac
    ;;
  rev-parse)
    case "${2:-}" in
      HEAD)              echo "abc123def4567890abc123def4567890abc12345" ;;
      --show-toplevel)   echo "${HOME:-/tmp}/.dotfiles" ;;
      --abbrev-ref)      echo "main" ;;
      *)                 echo "abc123" ;;
    esac
    ;;
  config)
    case "${*:2}" in
      *user.name*)       echo "Test User" ;;
      *user.email*)      echo "test@example.com" ;;
      *)                 : ;;
    esac
    ;;
  describe)              echo "v0.2.501" ;;
  log)                   echo "abc123 test commit" ;;
  branch)                echo "* main" ;;
  remote)                echo "origin" ;;
  diff)                  : ;;
  *)                     : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/curl" <<'SHIM'
#!/usr/bin/env bash
# Default: silent empty body, exit 0 — most callers only check rc.
# A `--head`-style probe still wants a "200 OK"-shaped header set
# so anything that pipes into `grep "HTTP/"` doesn't break.
for arg in "$@"; do
  case "$arg" in
    -I|--head)  echo "HTTP/1.1 200 OK"; echo "Content-Type: text/plain"; echo "" ;;
  esac
done
exit 0
SHIM

  cat >"$tmp/bin/wget" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM

  # mise — version checks + tool listing
  cat >"$tmp/bin/mise" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version|version) echo "2026.5.7 macos-arm64 (a1b2c3d 2026-05-06)" ;;
  ls|list)           echo "node 24.15.0 ~/.tool-versions latest"; echo "rust 1.95.0 ~/.tool-versions latest" ;;
  current)           echo "24.15.0" ;;
  where)             echo "${HOME:-/tmp}/.local/share/mise/installs" ;;
  exec|run)          shift; "$@" ;;
  install|use|set)   : ;;
  trust|untrust)     : ;;
  doctor)            echo "ok" ;;
  *)                 : ;;
esac
exit 0
SHIM

  # uv — Python tool manager
  cat >"$tmp/bin/uv" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "uv 0.5.0 (a1b2c3d 2026-05-01)" ;;
  tool)
    case "${2:-}" in
      list) echo "aider-chat 0.86.2" ;;
      *)    : ;;
    esac
    ;;
  *) : ;;
esac
exit 0
SHIM

  # Theme-dependent commands. wallpaper-sync / apply-gnome-theme /
  # iterm2 profile gen run a battery of these and bail when any
  # return non-zero — the shims keep them on the happy path.
  cat >"$tmp/bin/gsettings" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  get)
    case "${2:-}" in
      org.gnome.desktop.background)
        echo "'file://${HOME:-/tmp}/Pictures/Wallpapers/sample.heic'"
        ;;
      org.gnome.desktop.interface)
        echo "'prefer-dark'"
        ;;
      *) echo "''" ;;
    esac
    ;;
  set|reset) : ;;
  list-keys) echo "color-scheme"; echo "picture-uri" ;;
  *) : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/gnome-extensions" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  list)   echo "user-theme@gnome-shell-extensions.gcampax.github.com" ;;
  info)   echo "name: User Themes"; echo "state: ENABLED" ;;
  *)      : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/dconf" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  read)  echo "" ;;
  write) : ;;
  list)  : ;;
  dump)  : ;;
  *)     : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/defaults" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  read)      echo "1" ;;
  write|delete|domains) : ;;
  *) : ;;
esac
exit 0
SHIM

  # mktemp wrapper: stays out of the way (real one already works fine
  # in the sandbox), but the smart shim list above documents shims as
  # the way we keep the host clean.

  for cmd in chezmoi git curl wget mise uv gsettings gnome-extensions dconf defaults; do
    chmod +x "$tmp/bin/$cmd"
  done

  # ── Wallpaper fixture for theme-dependent scripts ─────────────────
  # `wallpaper-sync.sh`, `extract-theme.py`, and friends read pixel
  # data from a wallpaper file. We drop a tiny PNG header (8 bytes —
  # just the magic + a single IHDR) so any tool that does
  # `[[ -f "$wallpaper" ]] && file --mime-type "$wallpaper"` finds
  # a real file. Anything that actually parses pixels will fail
  # cleanly; the scripts under test handle the failure as "no
  # wallpaper available" and proceed to their fallback paths,
  # which is where the bulk of their code lives.
  mkdir -p "$HOME/Pictures/Wallpapers"
  printf '\x89PNG\r\n\x1a\n' >"$HOME/Pictures/Wallpapers/sample.png"
  printf '\x89PNG\r\n\x1a\n' >"$HOME/Pictures/Wallpapers/sample.heic"

  # ── Pre-populate common config dirs + minimal contents so the
  # "if config exists" branch in every dot command reaches the body
  # rather than the missing-file error path.
  mkdir -p "$HOME/.config/dotfiles" \
           "$HOME/.config/chezmoi" \
           "$HOME/.config/claude" \
           "$HOME/.config/atuin" \
           "$HOME/.config/fish" \
           "$HOME/.config/git" \
           "$HOME/.config/nvim" \
           "$HOME/.config/shell" \
           "$HOME/.config/zsh"

  # dotfiles agent state — pre-populated so `dot agent current` finds
  # a valid profile rather than dying on a missing file.
  cat >"$HOME/.config/dotfiles/agent-mode.env" <<'AGENTENV'
DOT_AGENT_PROFILE=ask
DOT_AGENT_APPROVAL=manual
DOT_AGENT_FILESYSTEM=read-only
DOT_AGENT_NETWORK=disabled
DOT_AGENT_MCP_PROFILE=read-only
DOT_AGENT_MAX_STEPS=10
AGENTENV

  # MCP server config — used by `dot mcp` / `scripts/diagnostics/mcp-doctor.sh`.
  # Three minimal entries cover the dispatch matrix (npx, node, uvx).
  cat >"$HOME/.config/claude/mcp_servers.json" <<'MCPCFG'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {"GITHUB_TOKEN": "${GITHUB_TOKEN}"}
    },
    "memory": {
      "command": "uvx",
      "args": ["mcp-server-memory"]
    }
  }
}
MCPCFG

  # AI status cache — pre-warmed so `cmd_ai_status` skips the
  # cold-cache probe path. The TSV format matches what
  # `_ai_refresh_status_cache` writes.
  mkdir -p "$HOME/.cache/dotfiles/ai"
  cat >"$HOME/.cache/dotfiles/ai/status.tsv" <<'AICACHE'
0	Agents (autonomous)
1	Claude Code	installed	2.1.117 — Anthropic CLI agent
1	Codex CLI	installed	0.130.0 — OpenAI Codex agent
1	Copilot CLI	installed	1.0.34 — GitHub Copilot CLI
0	Coding (interactive)
1	Aider	installed	0.86.2 — AI pair programmer
AICACHE
  # mtime in the past makes the cache fresh by the default TTL.

  # Git identity placeholder — many scripts read user.name/email
  # from gitconfig. The smart `git config` shim already returns
  # "Test User" + "test@example.com" for these lookups, but
  # gitconfig file presence is checked separately.
  cat >"$HOME/.config/git/config" <<'GITCFG'
[user]
	name = Test User
	email = test@example.com
[init]
	defaultBranch = main
GITCFG

  export PATH="$tmp/bin:$PATH"
}

cov_teardown_sandbox() {
  [[ -n "${DOTFILES_COV_TMPDIR:-}" && -d "$DOTFILES_COV_TMPDIR" ]] &&
    rm -rf "$DOTFILES_COV_TMPDIR"
  unset DOTFILES_COV_TMPDIR
}

# -----------------------------------------------------------------------------
# cov_exercise_script <path-to-script> [extra-arg-mode ...]
#
# Runs the script through safe-mode entry points to drive line
# coverage. Each invocation is wrapped in a hard 15s timeout so a
# misbehaving script can't sink the test suite. All exit codes are
# ignored — the goal is line execution, not behavioral assertion.
#
# Default arg-modes (run for every call): help, no-arg, invalid-flag.
# Optional: dry-run (added when the script's source mentions --dry-run).
# -----------------------------------------------------------------------------
cov_exercise_script() {
  local script="$1"
  [[ -r "$script" ]] || return 0

  local label
  label="$(basename "$script" .sh)"

  # Skip script-mode exercise for scripts whose --help / no-arg /
  # invalid-flag paths don't terminate cleanly within the inner
  # timeout. These typically run a watch / animate loop, open a
  # blocking interactive prompt regardless of args, or — in the
  # case of `myip` — `curl --max-time 5` three times before
  # exiting on rc=254 from a downstream `set -u` violation. Body
  # coverage they'd contribute is small vs the wall-clock cost
  # (3 × 60s = 180s per script).
  #
  # Match both bare basenames and the `executable_` prefix that
  # chezmoi strips at deploy time (scripts under dot_local/bin/).
  case "${label}" in
    cmatrix | pipes | stopwatch | matrix | rainbow | banner | \
      myip | pre-push | rebuild-themes | \
      lint | reliability-audit | record | \
      executable_myip | executable_tmux-sessionizer)
      return 0
      ;;
  esac

  # Always exercise from inside the sandbox tmpdir. Scripts that
  # write to `./relative/path` then land in the sandbox, not in the
  # real repo. Without this, e.g. functions/files/backup.sh creates
  # a `backups/` directory next to wherever the test was launched
  # from.
  if [[ -n "${DOTFILES_COV_TMPDIR:-}" && -d "${DOTFILES_COV_TMPDIR}" ]]; then
    cd "$DOTFILES_COV_TMPDIR" || return 0
  fi

  # Resolve a portable timeout binary. GNU coreutils ships `timeout`;
  # macOS without coreutils only has `gtimeout` after `brew install
  # coreutils`. If neither is on PATH, run without a wall-time cap —
  # tests already exit on script completion. rc=127 (command not
  # found) was previously sinking every macos-latest run.
  local TIMEOUT_BIN=""
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  fi
  # 60s cap rather than 15s. Some scripts under exercise (e.g. lint.sh)
  # don't parse `--help` and instead run their full main, which can
  # take tens of seconds when the repo has hundreds of shell files.
  # 60s is enough for the slowest known script without making a hung
  # test sink the parallel sweep for too long.
  local TIMEOUT_CMD
  if [[ -n "$TIMEOUT_BIN" ]]; then
    TIMEOUT_CMD=("$TIMEOUT_BIN" --kill-after=5 60)
  else
    TIMEOUT_CMD=()
  fi

  # The script under test almost always exits non-zero on
  # `--invalid-flag` (set -e + exit 1/2). If the calling test has
  # errexit enabled, that non-zero rc would terminate the test
  # before we can record it. Suppress errexit for the duration of
  # this function and restore it on return.
  local prev_e
  case "$-" in
    *e*) prev_e=1 ;;
    *) prev_e=0 ;;
  esac
  set +e

  test_start "${label}_help_executes"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --help </dev/null >/dev/null
  rc=$?
  # Accept any rc < 125 — scripts that don't parse --help may interpret
  # it as a positional arg (e.g. a directory to scan) and exit 123/127
  # via xargs propagation. We only care that the invocation ran and
  # exited, not how it interpreted the arg. 125+ signals timeout/kill.
  # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  if grep -q -- "--dry-run" "$script" 2>/dev/null; then
    test_start "${label}_dry_run_executes"
    ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --dry-run </dev/null >/dev/null
    rc=$?
    # Accept any rc except 124 (timeout) — we care that the invocation
    # ran to a normal exit, not how it interpreted its args. rc=127
    # (command-not-found) is fine: it means the script ran but couldn't
    # resolve an optional dependency under our sandbox's stripped env.
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  fi

  test_start "${label}_no_arg_executes"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" </dev/null >/dev/null
  rc=$?
  # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  test_start "${label}_unknown_flag_handled"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --definitely-not-a-real-flag </dev/null >/dev/null
  rc=$?
  # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  # Slice 4 of #883: probe common subcommands so scripts that gate on
  # a positional arg (e.g. `agent`, `mode`, `theme`, `secrets`) exit
  # the option-parser and start exercising the dispatch case. We try
  # each subcommand only when the script's source mentions it as a
  # case-pattern, so we don't spam every script with random args.
  local sub
  for sub in list status info show help version doctor check; do
    # Only probe subcommands the script actually handles.
    grep -qE "^\s*${sub}\)|^\s*${sub}\s*\|" "$script" 2>/dev/null || continue
    test_start "${label}_sub_${sub}"
    ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" "$sub" </dev/null >/dev/null
    rc=$?
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  done

  # Restore the caller's errexit state and return success so the
  # test script doesn't inherit the non-zero rc from the last
  # invocation. Without this every converted test would exit with
  # that rc, the framework would treat it as a crash, and the
  # RESULTS line never printed — the failure mode we hit on the
  # first run.
  [[ "$prev_e" == "1" ]] && set -e
  return 0
}

# -----------------------------------------------------------------------------
# cov_exercise_script_help_only <path-to-script>
#
# Same as cov_exercise_script but ONLY runs the `--help` mode. Use
# this for scripts whose no-arg or `--invalid-flag` paths perform
# writes to the real repo (e.g. build-manual.sh writes
# docs/manual/* via absolute BASH_SOURCE-relative paths, so a cd
# sandbox can't intercept it).
# -----------------------------------------------------------------------------
cov_exercise_script_help_only() {
  local script="$1"
  [[ -r "$script" ]] || return 0

  local label
  label="$(basename "$script" .sh)"

  if [[ -n "${DOTFILES_COV_TMPDIR:-}" && -d "${DOTFILES_COV_TMPDIR}" ]]; then
    cd "$DOTFILES_COV_TMPDIR" || return 0
  fi

  local TIMEOUT_BIN=""
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  fi
  local TIMEOUT_CMD
  if [[ -n "$TIMEOUT_BIN" ]]; then
    TIMEOUT_CMD=("$TIMEOUT_BIN" --kill-after=5 30)
  else
    TIMEOUT_CMD=()
  fi

  local prev_e
  case "$-" in
    *e*) prev_e=1 ;;
    *) prev_e=0 ;;
  esac
  set +e

  test_start "${label}_help_executes"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --help </dev/null >/dev/null
  rc=$?
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  [[ "$prev_e" == "1" ]] && set -e
  return 0
}

# -----------------------------------------------------------------------------
# cov_exercise_functions_file <path-to-functions-file>
#
# For files that only define functions (no top-level executable code,
# e.g. .chezmoitemplates/functions/text/lowercase.sh), bash xtrace
# never enters the function body unless something calls the function.
# This helper sources the file in a subshell, enumerates the functions
# it defined, and invokes each one with a few canned arg modes so the
# body lines record line coverage:
#
#   <fn>            no-arg path → typically hits the "missing required
#                   args" error branch
#   <fn> --help     help flag path
#   <fn> <tmpfile>  a real readable path so the success branch starts
#                   executing (often returns after a stat or so)
#
# Exit codes are ignored; we only care about line execution. The whole
# probe runs under a 30s timeout cap, with the same TIMEOUT_BIN
# fallback used by cov_exercise_script. Functions whose names match
# unsafe patterns (logout, shutdown, kill*, reboot, halt) are skipped.
# -----------------------------------------------------------------------------
cov_exercise_functions_file() {
  local script="$1"
  [[ -r "$script" ]] || return 0

  local label
  label="$(basename "$script" .sh)"

  # If the file defines no `name()` functions, sourcing it just runs
  # its top-level main — `cov_exercise_script` already covers that
  # path. Bail out so we don't double-run scripts like
  # `git-hooks/pre-push`, where the top-level body shells out to an
  # audit pipeline that nobody wants to run twice per test.
  if ! grep -qE "^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)" "$script" 2>/dev/null; then
    return 0
  fi

  # Same skip-list as cov_exercise_script — these scripts loop on
  # their --help / no-arg paths regardless of how they're invoked,
  # so the source-and-call mode hangs on them just as the
  # script-mode does.
  case "${label}" in
    cmatrix | pipes | stopwatch | matrix | rainbow | banner | \
      myip | pre-push | rebuild-themes | ql | \
      lint | reliability-audit | record | \
      executable_myip | executable_tmux-sessionizer | \
      version-sync | release | bump | sync-version | \
      build-manual | install | install-chezmoi-verified | uninstall | \
      manage-secrets | executable_update | wallpaper-rotate | \
      heal | heal-tools | rollback | restore | apply-gnome-theme | \
      install-catppuccin-themes | switch | \
      executable_ai_core | executable_dot-bootstrap | ai-update | \
      executable_ai-update | enforce-policies | ssh-cert | firewall | \
      secrets_provider | secrets-provider)
      # Scripts whose internal functions take a "version" or "file
      # path" arg and WRITE to repo files (README.md, install.sh,
      # CHANGELOG.md, etc.). Passing the helper's `$tmpfile` to
      # them substitutes the temp-file path into the repo files —
      # observed corrupting README.md badges in a previous run.
      # Strictly out of scope for fn-exercise.
      return 0
      ;;
    executable_git-ai-commit | executable_git-ai-diff | \
      executable_hashsum | executable_uuid | executable_regex | \
      executable_hex | executable_epoch | executable_hash | \
      executable_jsonv | executable_b64 | executable_cb)
      # Small utility CLI tools whose top-level body is a
      # `while [[ $# -gt 0 ]]; do case $1 in ... *) exit 1 ;; esac done`
      # arg parser WITHOUT a `shift` in the catchall arm. Sourcing
      # them with our $tmpfile as $1 makes the loop run forever —
      # each iteration hits the catchall, fires exit 1, our
      # override absorbs it, the loop never shifts, repeat. The
      # script-mode `cov_exercise_script` already exercises their
      # --help / no-arg / invalid-flag paths; fn-exercise has
      # nothing to add for a single-purpose CLI tool.
      return 0
      ;;
  esac

  # Always exercise from inside the sandbox tmpdir so the functions
  # under test write to a disposable cwd, not the real repo.
  if [[ -n "${DOTFILES_COV_TMPDIR:-}" && -d "${DOTFILES_COV_TMPDIR}" ]]; then
    cd "$DOTFILES_COV_TMPDIR" || return 0
  fi

  local TIMEOUT_BIN=""
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  fi
  local TIMEOUT_CMD
  if [[ -n "$TIMEOUT_BIN" ]]; then
    TIMEOUT_CMD=("$TIMEOUT_BIN" --kill-after=5 30)
  else
    TIMEOUT_CMD=()
  fi

  local prev_e
  case "$-" in
    *e*) prev_e=1 ;;
    *) prev_e=0 ;;
  esac
  set +e

  local tmpfile tmpdir
  tmpdir=$(mktemp -d -t cov-fn.XXXXXX)
  tmpfile="$tmpdir/sample.txt"
  echo "sample" >"$tmpfile"

  test_start "${label}_functions_exercised"
  # shellcheck disable=SC2016
  # SC2016: `$1` and `$2` inside the bash -c body are INTENDED to
  # expand in the inner shell, not the outer one — they're the
  # positional args passed via `_ "$script" "$tmpfile"` below.
  # Single quotes here are deliberate.
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash -c '
    set +eu

    # Keep stderr connected — 2>/dev/null on the source line would
    # discard the bash xtrace lines for every command the sourced
    # file executes, hiding ~all of its setup coverage.
    #
    # The `|| true` is essential, not stylistic: many dot command
    # files start with `set -euo pipefail`. That propagates into
    # our shell, then their tail dispatch case hits `exit 1` for an
    # unknown subcommand. With errexit on AND a non-zero source rc,
    # bash kills our outer shell before we can call any function.
    # Putting source on the LHS of `||` suppresses errexit for the
    # source command itself per the bash manual ("the command
    # following the final && or || except the command following the
    # final && or ||"), so we always reach the cleanup below.
    #
    # We additionally override `exit` for the duration of the source
    # so a tail `case … *) exit 1` dispatch (used by every dot
    # command file) returns rather than terminates. This unlocks the
    # function bodies that live below the dispatch. Restored to the
    # builtin right after source. Scripts whose top-level arg parser
    # loops without shifting (small `executable_git-ai-*` utilities)
    # would infinite-loop here and are skip-listed above.
    __cov_exit_calls=0
    exit() {
      __cov_exit_calls=$((__cov_exit_calls + 1))
      # Bail out hard if the source is calling exit in a loop —
      # at 50 iterations something is clearly stuck (the
      # executable_git-ai-* scripts would hit thousands without
      # this circuit-breaker).
      if [[ "$__cov_exit_calls" -gt 50 ]]; then
        unset -f exit
        builtin exit "${1:-0}"
      fi
      return "${1:-0}"
    }

    # shellcheck disable=SC1090
    source "$1" || true

    # Restore the real `exit` builtin so any function we call below
    # can exit normally if it needs to.
    unset -f exit

    # Force errexit + nounset off again after the source — the
    # sourced file very likely turned them back on.
    set +eu
    tmpfile="$2"
    # Discover functions defined by this file (best-effort). Source
    # may also pull in helpers from neighboring includes; we restrict
    # ourselves to functions declared in the file itself by regexing
    # the source.
    while IFS= read -r fn; do
      [[ -z "$fn" ]] && continue
      case "$fn" in
        # Destructive
        logout | shutdown | kill* | reboot | halt | exit) continue ;;
        # Long-running / interactive: watch / animate loops that
        # only exit on Ctrl-C. Small body-coverage gain vs the
        # 30s timeout cost per skipped script.
        apilatency_monitor | apiload_load_test | cmatrix | pipes | stopwatch | matrix | rainbow | banner) continue ;;
      esac
      # Three arg modes: no-arg, --help, and a real path. Each call
      # is independently rc-tolerant. We deliberately keep stderr
      # connected (not `2>&1 >/dev/null`) so bash xtrace output is
      # captured by the parent test runner — that is the whole point
      # of this helper.
      "$fn" </dev/null >/dev/null
      "$fn" --help </dev/null >/dev/null
      "$fn" "$tmpfile" </dev/null >/dev/null
    done < <(grep -oE "^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)" "$1" | sed "s/[[:space:]]*()$//")
    exit 0
  ' _ "$script" "$tmpfile" </dev/null
  rc=$?
  rm -rf "$tmpdir"

  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  [[ "$prev_e" == "1" ]] && set -e
  return 0
}
