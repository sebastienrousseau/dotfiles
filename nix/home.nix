# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
{ pkgs, ... }:

{
  home.username = "user";
  home.homeDirectory = "/home/user";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You can update Home Manager without changing this value. See the Home Manager
  # release notes for a list of state version changes in each release.
  home.stateVersion = "24.11";

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Add additional packages here
    htop
    tldr
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # Example:
    # ".screenrc".source = dotfiles/screenrc;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'.
  home.sessionVariables = {
    # EDITOR = "nvim";
  };

  # ── Shell aliases (shared across all shells managed by Home Manager) ───
  # home.shellAliases = {
  #   ll = "eza -l --icons --git";
  #   la = "eza -la --icons --git";
  #   cat = "bat --style=auto";
  #   g = "git";
  #   d = "docker";
  # };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # ── Example programs ───────────────────────────────────────────────────
  # Uncomment any section below to let Home Manager manage these tools
  # declaratively. Run `home-manager switch` after editing.

  # programs.git = {
  #   enable = true;
  #   userName = "Your Name";
  #   userEmail = "you@example.com";
  #   signing = {
  #     key = "~/.ssh/id_ed25519.pub";
  #     signByDefault = true;
  #   };
  #   extraConfig.gpg.format = "ssh";
  # };

  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   enableFishIntegration = true;
  # };

  # programs.zoxide = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   enableFishIntegration = true;
  # };

  # programs.direnv = {
  #   enable = true;
  #   nix-direnv.enable = true;  # Seamless nix shell integration
  # };

  # programs.bat = {
  #   enable = true;
  #   config.theme = "TwoDark";
  # };

  # programs.eza = {
  #   enable = true;
  #   enableZshIntegration = true;
  # };

  # ── XDG directories ───────────────────────────────────────────────────
  # xdg = {
  #   enable = true;
  #   configHome = "${config.home.homeDirectory}/.config";
  #   dataHome = "${config.home.homeDirectory}/.local/share";
  #   cacheHome = "${config.home.homeDirectory}/.cache";
  #   stateHome = "${config.home.homeDirectory}/.local/state";
  # };

  # Manage fish plugins via Home Manager
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "fisher";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "fisher";
          rev = "791da644d33d392216f6b1a9b5fc1e470db6d7f2";
          sha256 = "sha256-U1yd8m56YrHXrJFkU8xaOglulOGV0iBvwjU/bdf8tqA=";
        };
      }
    ];
  };
}
