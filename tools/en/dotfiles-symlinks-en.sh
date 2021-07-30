#!/bin/sh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#
# Description: Installer of the symbolic links (Symlinks) for the Z shell (Zsh)
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


# Enabling .zshrc which contains the shell configurations and commands. 
ln -sf "$(pwd)/zsh/.zshrc" ~

# Enabling aliases.zsh which contains various shortcuts to reference core commands. 
ln -sf "$(pwd)/zsh/aliases.zsh" ~

# Enabling configurations.zsh which contains the shell configurations. 
ln -sf "$(pwd)/zsh/configurations.zsh" ~

# Enabling exit.zsh which gets read when the shell session closes. 
ln -sf "$(pwd)/zsh/exit.zsh" ~

# Enabling .zshrc which contains the shell configurations and commands. 
ln -sf "$(pwd)/zsh/functions.zsh" ~

# Enabling .zshrc which contains the shell configurations and commands. 
ln -sf "$(pwd)/zsh/history.zsh" ~

# Enabling .zprofile which contains commands executed on shell login. 
ln -sf "$(pwd)/zsh/profile.zsh" ~

# Enabling .zlogout, which gets read when the shell session closes. 
ln -sf "$(pwd)/zsh/profile.zsh" ~

# Enabling .zshenv which contain the user’s environment variables. 
ln -sf "$(pwd)/zsh/profile.zsh" ~

# Enabling .zprofile which contains commands executed on shell login. 
ln -sf "$(pwd)/zsh/profile.zsh" ~

# Enabling .zprofile which contains commands executed on shell login. 
ln -sf "$(pwd)/zsh/profile.zsh" ~

# Enabling .zprofile which contains commands executed on shell login. 
ln -sf "$(pwd)/zsh/profile.zsh" ~

# Enabling .zprofile which contains commands executed on shell login. 
ln -sf "$(pwd)/zsh/profile.zsh" ~
