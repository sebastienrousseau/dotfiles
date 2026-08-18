#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# Demonstrates the module coverage gate.
#
# By default this runs the real tests/framework/module_coverage.sh against a
# small, self-contained fixture rather than against this repository. Running it
# over the whole repo took ~91s — more than every other example combined by a
# factor of thirteen, and enough on its own to blow the 60s per-script budget
# that scripts/qa/validate-examples.sh runs examples under. The examples suite
# is a smoke test that examples work; re-running the full CI coverage sweep
# inside it duplicated a gate the test workflows already run.
#
# Set EXAMPLE_COVERAGE_FULL_REPO=1 to run the gate against this repository
# instead, which is the invocation CI uses.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${EXAMPLE_COVERAGE_FULL_REPO:-0}" = "1" ]; then
  printf 'Running the coverage gate against this repository (slow)...\n'
  MIN_COVERAGE="${MIN_COVERAGE:-100}" ./tests/framework/module_coverage.sh
  exit $?
fi

fixture="$(mktemp -d "${TMPDIR:-/tmp}/example-coverage-gate.XXXXXX")"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT

# The gate discovers modules under scripts/, the chezmoi function templates and
# defaults/dot_local/bin, then checks each is referenced by a test. Create one
# module of each kind and a test that covers them, so the fixture exercises the
# real discovery and matching logic rather than an empty tree.
mkdir -p "$fixture/scripts" \
         "$fixture/defaults/.chezmoitemplates/functions" \
         "$fixture/defaults/dot_local/bin" \
         "$fixture/tests/unit"

printf '#!/usr/bin/env bash\necho demo\n' > "$fixture/scripts/demo.sh"
printf '#!/usr/bin/env bash\ndemo_fn() { :; }\n' > "$fixture/defaults/.chezmoitemplates/functions/demo.sh"
cat > "$fixture/tests/unit/test_demo.sh" <<'FIXTURE'
#!/usr/bin/env bash
# Covers: scripts:demo functions:demo
FIXTURE

printf 'Running example: module coverage gate over a fixture\n'
MIN_COVERAGE=100 REPO_ROOT="$fixture" TESTS_DIR="$fixture/tests" \
  ./tests/framework/module_coverage.sh

printf 'Coverage gate example passed.\n'
printf 'Re-run with EXAMPLE_COVERAGE_FULL_REPO=1 to gate this repository.\n'
