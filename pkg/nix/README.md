<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Nix

The Nix packaging is not a separate recipe — it is the flake in
[`nix/flake.nix`](../../nix/flake.nix), kept there because Home Manager
consumes it directly.

| Output | What |
|---|---|
| `packages.<system>.dot-utils` | The tool environment (`pkgs.buildEnv` over ~23 CLI tools) |
| `packages.<system>.default` | Alias for `dot-utils` |
| `homeConfigurations` | Home Manager activation (guarded by `nix/home.nix` existing) |
| `devShells.default` | Contributor shell |

```sh
nix build ./nix#default
nix develop ./nix
```

The **root** `flake.nix` intentionally provides only `devShells.default`
(the `direnv` shell); it has no `packages` output, so `nix build` at
the repository root does nothing. Use `./nix#` as above.

Not yet in nixpkgs. A derivation there would be a straightforward
`stdenv.mkDerivation` over the release tarball with
`makeFlags = [ "PREFIX=$(out)" ]` — see [`../../docs/packaging.md`](../../docs/packaging.md).
