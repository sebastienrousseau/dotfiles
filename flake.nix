# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
{
  description = "Universal Dotfiles Reproducible Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core Shells
            zsh
            fish
            nushell

            # Prompt & Navigation
            starship
            zoxide
            atuin

            # Modern CLI Replacements
            eza
            bat
            fd
            ripgrep
            fzf
            yazi
            zellij

            # Dev tools
            neovim
            tmux
            git
            gh
            lazygit
            sops
            age

            # Neovim LSP & IDE Tooling
            lua-language-server
            nil # Nix LSP
            marksman # Markdown LSP
            taplo # Markdown linter
            stylua
            shellcheck
            shfmt
            nodePackages.typescript-language-server
            nodePackages.prettier

            # Configuration management
            chezmoi
            mise

            # Advanced tools
            pueue
            wasmtime

            # Modern Terminal UI & AI (Charmbracelet + Productivity)
            gum
            glow
            mods
            thefuck
            carapace
          ];

          shellHook = ''
            echo "🔮 Welcome to the declarative dotfiles shell!"
            echo "   Packages are provided strictly via Nix Flakes."
            # Only start starship if inside supported shell
            if [ -n "$ZSH_VERSION" ]; then
              eval "$(starship init zsh)"
            elif [ -n "$FISH_VERSION" ]; then
              starship init fish | source
            elif [ -n "$BASH_VERSION" ]; then
              eval "$(starship init bash)"
            fi
          '';
        };
      }
    );
}
