# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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
