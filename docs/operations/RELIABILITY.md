---
render_with_liquid: false
---
{% raw %}

# Reliability

## Reliability scorecard

- Unit coverage: 100% module mapping target, enforced by `tests/framework/module_coverage.sh`
- Integration depth: the integration tests in `tests/integration/`, run by `reliability-audit.sh --with-integration`
- Regression automation: every `test_*.sh` under `tests/` that the runner discovers; its FINAL SUMMARY prints the current counts

## Coverage gap map

| Module | Missing path | Risk level | Proposed test case |
| :--- | :--- | :--- | :--- |
| `scripts/qa/reliability-audit.sh` | Quick mode and integration mode branch handling | Closed | Covered by `tests/unit/misc/test_qa_reliability_behaviour.sh` |
| `scripts/git-hooks/pre-push` | Audit command failure path | Closed | Covered by `tests/unit/misc/test_git_hooks_pre_push_behaviour.sh` |
| `tests/framework/module_coverage.sh` | False-positive module matches | Closed | Covered by `tests/unit/misc/test_module_coverage_behaviour.sh` |
| `examples/*.sh` | Drift between examples and real commands | Closed | Examples execute in CI through `Examples Contract` and `validate-examples.sh` |

## Integration boundaries

```mermaid
flowchart LR
  Dev[Developer] --> Hook[pre-push hook]
  Hook --> Audit[reliability-audit.sh]
  Audit --> Syntax[Shell syntax gate]
  Audit --> Unit[Unit suite]
  Audit --> Coverage[Module coverage]
  Audit --> Docs[Docs coverage]
  Audit --> Trace[Traceability coverage]
  Audit --> Examples[Example validation]
  Audit --> Integration[Integration suite]
  Integration --> Repo[Dotfiles workflows]
  CI[Reliability Gate workflow] --> Audit
  CI --> WSL[WSL contract]
  CI --> PS[PowerShell contract]
  CI --> Matrix[Feature matrix]
  WSL --> Repo
  PS --> Repo
```

The pre-push hook runs `reliability-audit.sh --quick` (no integration
suite). The WSL, PowerShell and feature-matrix contracts run only in
the Reliability Gate workflow, not in the audit.

```mermaid
sequenceDiagram
  participant Dev as Developer
  participant Git as Git client
  participant Hook as pre-push
  participant Audit as reliability-audit.sh
  participant Suite as tests/framework/test_runner.sh
  participant Cov as module_coverage.sh
  participant Ex as validate-examples.sh

  Dev->>Git: git push
  Git->>Hook: invoke pre-push
  Hook->>Hook: verify signed commits
  Hook->>Audit: run quick gate
  Audit->>Audit: shell syntax
  Audit->>Suite: run unit suite
  Audit->>Cov: enforce 100% module mapping
  Audit->>Audit: docs and traceability coverage
  Audit->>Ex: execute examples
  Ex-->>Audit: pass
  Cov-->>Audit: pass
  Suite-->>Audit: pass
  Audit-->>Hook: pass
  Hook-->>Git: allow push
```

## CI gate

A trimmed view of `.github/workflows/reliability-gate.yml` (hardening,
tool-install and pinned-action steps left out):

```yaml
name: Reliability Gate

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  reliability:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, macos-15]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Reliability audit
        run: bash ./scripts/qa/reliability-audit.sh --with-integration

  examples-contract:
    runs-on: ubuntu-latest
    steps:
      - name: Validate executable examples
        run: bash ./scripts/qa/validate-examples.sh
      - name: Every command has an example
        run: bash ./scripts/qa/examples-coverage.sh

  feature-matrix:
    runs-on: ubuntu-latest
    steps:
      - name: Verify the feature matrix is in sync
        run: bash ./scripts/qa/check-feature-matrix.sh

  wsl-contract:
    runs-on: ubuntu-latest
    steps:
      - name: Validate WSL parity contract
        run: bash ./scripts/qa/wsl-contract.sh

  powershell-contract:
    runs-on: windows-latest
    steps:
      - name: Run PowerShell parity contract
        shell: pwsh
        run: ./scripts/qa/powershell-contract.ps1

  reliability-summary:
    needs: [reliability, examples-contract, feature-matrix, wsl-contract, powershell-contract]
    runs-on: ubuntu-latest
```

## Functional examples

- `examples/example-test-suite.sh`: Runs a focused unit slice.
- `examples/example-coverage-gate.sh`: Runs the module coverage contract.
- `examples/example-git-hooks.sh`: Shows the local hook entrypoints.
- `examples/example-platform-contract.sh`: Shows the platform and host contract across macOS, Linux, and WSL.

## Local guardrail

`make test` is the canonical reliability command. It runs syntax checks, unit tests, module coverage, executable examples, and integration tests.

For a lightweight repository-wide snapshot, run `bash ./scripts/qa/coverage-baseline.sh --with-module-coverage`.

Core internal behaviors are traced through `bash ./scripts/qa/traceability-coverage.sh`.
{% endraw %}
