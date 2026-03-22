# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
      homeConfigurations = {
        user = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # Default, overridden by --override-input if needed or just edit
          modules = [ ./home.nix ];
        };
      };

      # Overlay: read .chezmoidata.toml features to conditionally include packages
      overlays.chezmoi-features =
        final: prev:
        let
          dataFile = ../.chezmoidata.toml;
          hasFeature =
            name:
            builtins.pathExists dataFile
            && builtins.match ".*${name} = true.*" (builtins.readFile dataFile) != null;
        in
        {
          dotfiles-conditional = final.buildEnv {
            name = "dotfiles-conditional";
            paths =
              (if hasFeature "starship" then [ final.starship ] else [ ])
              ++ (if hasFeature "zsh" then [ final.zoxide ] else [ ])
              ++ (if hasFeature "fish" then [ final.direnv ] else [ ])
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
