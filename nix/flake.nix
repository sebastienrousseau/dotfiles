# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
{
  description = "Dotfiles optional toolchain (Nix)";

  # NOTE: Run `nix flake update` to generate/refresh flake.lock, then commit it
  # for reproducible builds. Pin to a stable release channel for determinism.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      # Development shell for interactive use
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # Core
              git
              zsh
              neovim
              tmux

              # Search & Navigation
              ripgrep
              fd
              bat
              fzf
              zoxide
              eza

              # Git tools
              lazygit
              delta
              gh

              # Data processing
              jq
              yq

              # Dev tools
              chezmoi
              starship
              shellcheck
              shfmt
              just
              direnv

              # Security
              age
              gnupg
            ];
          };
        }
      );

      # Formatter for `nix fmt`
      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt-rfc-style);

      # Packages output for `nix profile install`
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Meta package: dot-utils - installs all dotfiles utilities
          dot-utils = pkgs.buildEnv {
            name = "dot-utils";
            paths = with pkgs; [
              # Core
              git
              zsh
              neovim
              tmux

              # Search & Navigation
              ripgrep
              fd
              bat
              fzf
              zoxide
              eza

              # Git tools
              lazygit
              delta
              gh

              # Data processing
              jq
              yq

              # Dev tools
              chezmoi
              starship
              shellcheck
              shfmt
              just
              direnv

              # Security
              age
              gnupg
            ];
            meta = {
              description = "Dotfiles utility bundle";
              longDescription = ''
                A meta-package that installs all core utilities used by the dotfiles.
                Install with: nix profile install .#dot-utils
              '';
            };
          };

          default = self.packages.${system}.dot-utils;
        }
      );
    };
}
