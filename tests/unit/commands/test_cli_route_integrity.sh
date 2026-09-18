#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Route-integrity ratchet for bin/dot's _dot_command_routes() table.
#
# Every `cmd|namespace` entry must resolve to something that will
# actually run when the user types `dot <cmd>`. Four ways to bind:
#   1. `<cmd>)` case label inside scripts/dot/commands/<namespace>.sh
#   2. `cmd_<name>()` function in that module
#   3. `<cmd>)` inline case in bin/dot's own dispatch block
#   4. bin/dot-<cmd> executable
#
# Also gates:
#   * Every namespace referenced is a real file under scripts/dot/commands/
#     (or one of the pseudo-namespaces bin/dot handles inline: help,
#     version, search, agents, init, registry, patterns, manual, fleet).
#   * Every entry's cmd column is a valid identifier (no spaces, no
#     ambiguity with shell metacharacters).
#   * Every `cmd_<name>()` function that exists in a module has a
#     matching route entry (catches abandoned handlers).
#
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"
source "$SCRIPT_DIR/../../framework/docs_sync_helpers.sh"

BIN_DOT="$REPO_ROOT/bin/dot"
CMD_DIR="$REPO_ROOT/scripts/dot/commands"

# Namespaces that bin/dot dispatches inline (no <ns>.sh module).
INLINE_NAMESPACES=(help version search)

_is_inline_namespace() {
  local ns="$1"
  for x in "${INLINE_NAMESPACES[@]}"; do
    [[ "$x" == "$ns" ]] && return 0
  done
  return 1
}

_module_has_case_or_function() {
  local module="$1" cmd="$2"
  local underscore="${cmd//-/_}"
  # (1) case label — bare or in alternation
  local alt_re="^  ([a-zA-Z0-9_-]+[[:space:]]*\\|[[:space:]]*)*${cmd}([[:space:]]*\\|[[:space:]]*[a-zA-Z0-9_-]+)*\\)"
  grep -qE "$alt_re" "$module" 2>/dev/null && return 0
  # (2) cmd_<name>() function
  grep -qE "^cmd_${underscore}\\(\\)" "$module" 2>/dev/null && return 0
  return 1
}

_inline_bin_dot_has_case() {
  local cmd="$1"
  local alt_re="^  ([a-zA-Z0-9_-]+[[:space:]]*\\|[[:space:]]*)*${cmd}([[:space:]]*\\|[[:space:]]*[a-zA-Z0-9_-]+)*\\)"
  grep -qE "$alt_re" "$BIN_DOT"
}

# ---------------------------------------------------------------------------
# Parse the routes table.
# ---------------------------------------------------------------------------
mapfile -t ROUTES < <(
  awk '/^_dot_command_routes\(\)/,/^\}/' "$BIN_DOT" \
    | awk -F'|' '/^[a-z][a-z0-9-]*\|[a-z]+$/ { print }'
)

test_start "route_table_has_entries"
if [[ ${#ROUTES[@]} -gt 50 ]]; then
  _ok "found ${#ROUTES[@]} routes"
else
  _fail "only ${#ROUTES[@]} routes (expected > 50)"
fi

# ---------------------------------------------------------------------------
# Every route resolves to a binding.
# ---------------------------------------------------------------------------
unresolved=()
for line in "${ROUTES[@]}"; do
  cmd="${line%%|*}"
  ns="${line##*|}"

  # (4) bin/dot-<cmd> executable — takes priority as an explicit override
  if [[ -x "$REPO_ROOT/bin/dot-${cmd}" ]]; then
    continue
  fi

  # (3) inline namespace handled directly in bin/dot
  if _is_inline_namespace "$ns"; then
    if _inline_bin_dot_has_case "$cmd" || _inline_bin_dot_has_case "$ns"; then
      continue
    fi
    unresolved+=("${cmd} -> inline ${ns}, no case in bin/dot")
    continue
  fi

  # (1)/(2) namespace module
  module="$CMD_DIR/${ns}.sh"
  if [[ ! -f "$module" ]]; then
    unresolved+=("${cmd} -> missing module ${module#$REPO_ROOT/}")
    continue
  fi
  # Self-dispatching module: cmd == ns AND bin/dot execs the module
  # directly (patterns, manual, init, registry, agents follow this
  # pattern). The module parses "$@" itself, so having no case/function
  # for its own name is expected.
  if [[ "$cmd" == "$ns" ]] && grep -qE "exec bash.*${ns}\\.sh" "$BIN_DOT"; then
    continue
  fi
  if ! _module_has_case_or_function "$module" "$cmd"; then
    unresolved+=("${cmd} -> ${ns}.sh has no case or cmd_${cmd//-/_}()")
  fi
done

test_start "every_route_resolves_to_a_binding"
if [[ ${#unresolved[@]} -eq 0 ]]; then
  _ok
else
  _fail "unresolved routes: ${unresolved[*]}"
fi

# ---------------------------------------------------------------------------
# No duplicate route entries (same cmd twice).
# ---------------------------------------------------------------------------
test_start "no_duplicate_route_entries"
dupes=()
while IFS= read -r cmd; do
  dupes+=("$cmd")
done < <(printf '%s\n' "${ROUTES[@]}" | awk -F'|' '{ print $1 }' | sort | uniq -d)
if [[ ${#dupes[@]} -eq 0 ]]; then
  _ok
else
  _fail "duplicate route entries: ${dupes[*]}"
fi

# ---------------------------------------------------------------------------
# No route command name has whitespace or shell metacharacters.
# ---------------------------------------------------------------------------
test_start "route_cmd_names_are_shell-safe"
bad=()
for line in "${ROUTES[@]}"; do
  cmd="${line%%|*}"
  [[ "$cmd" =~ ^[a-z][a-z0-9-]*$ ]] || bad+=("$cmd")
done
if [[ ${#bad[@]} -eq 0 ]]; then
  _ok
else
  _fail "unsafe cmd names: ${bad[*]}"
fi

# ---------------------------------------------------------------------------
# Every namespace referenced by any route is either an inline
# pseudo-namespace or has a matching module file.
# ---------------------------------------------------------------------------
test_start "every_namespace_exists_as_module_or_inline"
missing_ns=()
mapfile -t NAMESPACES < <(printf '%s\n' "${ROUTES[@]}" | awk -F'|' '{ print $2 }' | sort -u)
for ns in "${NAMESPACES[@]}"; do
  if _is_inline_namespace "$ns"; then
    continue
  fi
  [[ -f "$CMD_DIR/${ns}.sh" ]] || missing_ns+=("$ns")
done
if [[ ${#missing_ns[@]} -eq 0 ]]; then
  _ok
else
  _fail "missing namespace modules: ${missing_ns[*]}"
fi

# ---------------------------------------------------------------------------
# Every cmd_<name>() handler in a namespace module has a matching
# route entry. Catches abandoned handlers left behind after a
# rename or removal.
# ---------------------------------------------------------------------------
test_start "every_cmd_handler_has_a_route"
# Build the set of routed commands (both hyphen and underscore forms).
declare -A ROUTED=()
for line in "${ROUTES[@]}"; do
  cmd="${line%%|*}"
  ROUTED["$cmd"]=1
  ROUTED["${cmd//-/_}"]=1
done
# Subcommand handlers (cmd_<sub>() living inside a module that's
# reached via a routed *parent* command) are legitimate internals,
# not top-level handlers. Detect these by scanning the module's own
# case block for a matching case label.
abandoned=()
for module in "$CMD_DIR"/*.sh; do
  module_base="$(basename "$module" .sh)"
  # Precompute the set of case labels this module dispatches on —
  # any `cmd_<sub>()` whose <sub> matches one of these is an
  # internal subcommand handler and doesn't need its own route.
  mapfile -t module_labels < <(_docs_extract_from_case_block "$module")
  declare -A LABELS=()
  for l in "${module_labels[@]}"; do LABELS["${l//-/_}"]=1; done

  while IFS= read -r fn; do
    name="${fn#cmd_}"
    name="${name%()}"

    # (a) top-level routed
    [[ -n "${ROUTED[$name]:-}" ]] && continue
    hyphenated="${name//_/-}"
    [[ -n "${ROUTED[$hyphenated]:-}" ]] && continue

    # (b) subcommand handler for one of this module's case labels
    [[ -n "${LABELS[$name]:-}" ]] && continue
    # (c) leading segment matches module name: cmd_secrets_edit in
    # secrets.sh → the "edit" subcommand. Accept if the tail after
    # the module prefix matches a label OR if it's just a helper.
    if [[ "$name" == "${module_base}_"* ]]; then
      continue
    fi
    # (d) `cmd_env_*` in secrets.sh / tools.sh — the env command is
    # routed to core but its buckets are handled inline by other
    # modules. Skip anything of shape `cmd_env_*`.
    [[ "$name" == env_* ]] && continue

    abandoned+=("${module_base}.sh:${fn}")
  done < <(grep -oE '^cmd_[a-z][a-z0-9_]*\(\)' "$module")
  unset LABELS
done
if [[ ${#abandoned[@]} -eq 0 ]]; then
  _ok
else
  _fail "abandoned handlers: ${abandoned[*]}"
fi

_cmd_finish
