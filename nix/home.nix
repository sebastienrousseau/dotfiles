# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
{ pkgs, ... }:

{
  home.username = "dotfiles";
  home.homeDirectory = "/tmp/dotfiles-home";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    htop
    tldr
  ];

  home.sessionVariables = {
    # EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

  programs.fish = {
    enable = true;
  };
}
