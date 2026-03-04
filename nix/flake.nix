# Copyright (c) 2015-2026 . All rights reserved.
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
      # Use: home-manager switch --flake .#seb
      homeConfigurations = {
        seb = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux"; # Adjust if needed
          modules = [ ./home.nix ];
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
