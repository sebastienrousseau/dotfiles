<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Optional Nix Toolchain

This is optional. `chezmoi` remains the source of truth for config.
Use Nix only if you want reproducible binaries.

## Quick start

From the repository root:

```bash
nix develop ./nix
```

This enters the dev shell defined in `nix/flake.nix`, with common tools
including git, zsh, neovim, tmux, ripgrep, fd, bat, fzf, zoxide, eza,
lazygit, delta, gh, jq, yq, chezmoi, shellcheck and shfmt.

A bare `nix develop` at the repository root uses the root `flake.nix`
instead: a different shell, the one `direnv` loads. For the flake's
package outputs (`nix build ./nix#default`), see
[`../pkg/nix/README.md`](../pkg/nix/README.md).

---

Made with ❤️ by [Sebastien Rousseau](https://sebastienrousseau.com)
