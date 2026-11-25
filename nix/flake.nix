# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
{
  description = "Dotfiles optional toolchain (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
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
      # Home Manager configuration
      # Use: home-manager switch --flake .#user
      # You can rename 'user' to your actual username if desired
      homeConfigurations = nixpkgs.lib.optionalAttrs (builtins.pathExists ./home.nix) {
        user = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # Default, overridden by --override-input if needed or just edit
          modules = [ ./home.nix ];
        };
      };

      # Overlay: read the chezmoi data (defaults/.chezmoidata.toml) to
      # decide which optional packages to include. Each one is on unless
      # [features] sets it to false. The path was ../.chezmoidata.toml,
      # which does not exist, so every optional package was dropped.
      overlays.chezmoi-features =
        final: prev:
        let
          dataFile = ../defaults/.chezmoidata.toml;
          data = if builtins.pathExists dataFile then builtins.fromTOML (builtins.readFile dataFile) else { };
          features = data.features or { };
          enabled = name: features.${name} or true;
          optional = name: pkg: if enabled name then [ pkg ] else [ ];
        in
        {
          dotfiles-conditional = final.buildEnv {
            name = "dotfiles-conditional";
            paths =
              optional "starship" final.starship
              ++ optional "zoxide" final.zoxide
              ++ optional "direnv" final.direnv
              ++ [
                final.bat
                final.ripgrep
                final.fd
                final.eza
              ];
          };
        };

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
              git
              zsh
              neovim
              tmux
              ripgrep
              fd
              bat
              fzf
              zoxide
              eza
              lazygit
              delta
              gh
              jq
              yq
              chezmoi
              starship
              shellcheck
              shfmt
              just
              direnv
              age
              gnupg
            ];
          };

          default = self.packages.${system}.dot-utils;
        }
      );
    };
}
