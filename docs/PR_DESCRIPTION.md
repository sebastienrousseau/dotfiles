# Release notes — v0.2.484

## Overview

v0.2.484 is a focused patch release that finishes the `dot` command UX normalization and ensures the release tag includes the latest fixes already merged on `master`.

## Fixes

- **`dot tools` styling**
  - Default `dot tools` now renders styled CLI output through UI helpers.
  - Raw markdown remains available via `dot tools docs`.

- **`dot status` clarity**
  - `dot status` now prints a styled `Clean` state when there is no drift.

- **`dot keys` robustness**
  - Fixed strict-mode unbound-argument behavior when called without a query.

## Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.484/install.sh)"
exec zsh
```

Non-interactive:

```bash
DOTFILES_NONINTERACTIVE=1 sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.484/install.sh)"
```

## Upgrade

```bash
dot update
```
