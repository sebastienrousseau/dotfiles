{
  description = "Dotfiles optional toolchain (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }:
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
      devShells = forAllSystems (system:
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

              # Data processing
              jq
              yq

              # Security
              age
              gnupg
            ];
          };
        }
      );

      # Packages output for `nix profile install`
      packages = forAllSystems (system:
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

              # Data processing
              jq
              yq

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
