# Release notes — v0.2.483

## Overview

v0.2.483 finalizes the security/compliance uplift on `master`, restores the styled `dot` CLI experience, and hardens CI with an explicit module-coverage gate.

## Highlights

- **Signed commit workflow hardening**
  - Added signed pre-push hook tooling under `scripts/git-hooks/`.
  - Added compliance checks and cryptographic-signature verification updates.

- **Testing and quality**
  - Added CI module coverage enforcement via `scripts/tests/framework/module_coverage.sh`.
  - Coverage threshold is now **>=95%**, with current module coverage at **100% (62/62)**.
  - Stabilized unit tests to match current runtime behavior and environment constraints.
  - Unit suite now passes end-to-end: **1046 tests, 0 failures**.

- **CLI UX improvements**
  - Restored styled CLI output in `dot` help/version with ASCII logo.
  - Fixed help command layout with aligned columns.
  - Command labels in help are now highlighted in green.

- **Core reliability fix**
  - Fixed strict-mode argument handling for `dot add` when invoked without arguments.

- **Documentation and release hygiene**
  - Synced README and docs to `v0.2.483`.
  - Updated compliance/testing claims to match current repository state.

## Installation

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.483/install.sh)"
exec zsh
```

Non-interactive:

```bash
DOTFILES_NONINTERACTIVE=1 sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.483/install.sh)"
```

## Upgrade

```bash
dot update
```

## Verification

```bash
./scripts/tests/framework/test_runner.sh
MIN_COVERAGE=95 ./scripts/tests/framework/module_coverage.sh
```
