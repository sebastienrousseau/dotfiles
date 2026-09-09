#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Verify workstation attestation evidence with the WebAssembly verifier.
##
## Runs `lib/wasm-tools` built for `wasm32-wasip1` under `wasmtime` and feeds
## it an evidence record on stdin. The module has no filesystem, no network
## and no environment: it reads the document, applies the policy and writes a
## verdict. Nothing about the verdict depends on the tools installed on the
## machine under review — which is the point, since that machine is the one
## making the claims.
##
## Usage: dot attest --verify [--json|-j] [--max-age SECS] [FILE]
##        dot attest --json | bash scripts/diagnostics/attest-verify.sh
##
## Exit codes: 0 every check passed, 1 a check failed, 2 the evidence or the
## toolchain was unusable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export REPO_ROOT

# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

CRATE_DIR="$REPO_ROOT/lib/wasm-tools"
WASM_TARGET="wasm32-wasip1"
DEFAULT_MODULE="$CRATE_DIR/target/$WASM_TARGET/release/dot-sys.wasm"

JSON_MODE=0
MAX_AGE=""
EVIDENCE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json | -j)
      JSON_MODE=1
      shift
      ;;
    --max-age | -a)
      MAX_AGE="${2:-}"
      shift 2
      ;;
    --verify | -V)
      # Accepted so the flag can be forwarded verbatim from `dot attest`.
      shift
      ;;
    --help | -h)
      cat <<'USAGE'
Usage: dot attest --verify [--json|-j] [--max-age SECS] [FILE]

Runs the wasm32-wasip1 build of lib/wasm-tools under wasmtime and checks an
evidence record against the workstation policy. Reads FILE, or stdin, or a
fresh `dot attest --json` when given neither.

  --json, -j        emit the machine-readable verdict
  --max-age SECS    freshness window for `generated_at` (`any` to lift it)
  --help, -h        print this text

Exit codes: 0 every check passed, 1 a check failed, 2 unusable input or
toolchain.
USAGE
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "attest-verify: unknown option $1" >&2
      exit 2
      ;;
    *)
      EVIDENCE_FILE="$1"
      shift
      ;;
  esac
done

# Resolve the WebAssembly runtime. `wasmtime` is pinned in mise.toml, shipped
# by flake.nix and the Brewfile, and checked by `dot doctor`.
WASMTIME_BIN="${WASMTIME:-wasmtime}"
if ! command -v "$WASMTIME_BIN" >/dev/null 2>&1; then
  echo "attest-verify: no WebAssembly runtime found (looked for '$WASMTIME_BIN')." >&2
  echo "attest-verify: install it with 'mise install wasmtime' or set WASMTIME." >&2
  exit 2
fi

# Resolve the module, building it on demand when a Rust toolchain is present.
MODULE="${DOT_SYS_WASM:-$DEFAULT_MODULE}"
if [[ ! -f "$MODULE" ]]; then
  if [[ -n "${DOT_SYS_WASM:-}" ]]; then
    echo "attest-verify: DOT_SYS_WASM points at a missing file: $MODULE" >&2
    exit 2
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "attest-verify: no verifier at $MODULE and no cargo to build one." >&2
    echo "attest-verify: build it with:" >&2
    echo "  cargo build --release --target $WASM_TARGET --manifest-path lib/wasm-tools/Cargo.toml" >&2
    exit 2
  fi
  echo "attest-verify: building the verifier for $WASM_TARGET ..." >&2
  cargo build --quiet --release --target "$WASM_TARGET" \
    --manifest-path "$CRATE_DIR/Cargo.toml" --bin dot-sys >&2
fi

# Collect the evidence: an explicit file, a pipe, or a fresh attestation.
evidence=""
if [[ -n "$EVIDENCE_FILE" ]]; then
  if [[ ! -f "$EVIDENCE_FILE" ]]; then
    echo "attest-verify: no such evidence file: $EVIDENCE_FILE" >&2
    exit 2
  fi
  evidence="$(cat "$EVIDENCE_FILE")"
elif [[ ! -t 0 ]]; then
  evidence="$(cat)"
else
  evidence="$(bash "$SCRIPT_DIR/workstation-attestation.sh" --json)"
fi

module_args=(verify)
[[ "$JSON_MODE" -eq 1 ]] && module_args+=(--json)
[[ -n "$MAX_AGE" ]] && module_args+=(--max-age "$MAX_AGE")

set +e
verdict="$(printf '%s' "$evidence" | "$WASMTIME_BIN" run "$MODULE" "${module_args[@]}")"
status=$?
set -e

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '%s\n' "$verdict"
  exit "$status"
fi

ui_init
ui_dot_banner "Diagnostics"
ui_header "Attestation Verification"
printf '%s\n' "$verdict"
if [[ "$status" -eq 0 ]]; then
  ui_ok "Verdict" "every check passed"
else
  ui_err "Verdict" "see the failed checks above"
fi
ui_info "Verifier" "$MODULE (wasm32-wasip1, $("$WASMTIME_BIN" --version | head -n 1))"
exit "$status"
