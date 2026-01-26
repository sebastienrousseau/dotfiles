#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.474) - <https://dotfiles.io>
# Made With ❤️ in London, United Kingdom
# Designed by Sebastien Rousseau
# Copyright (c) 2015-2026. All rights reserved.
# License: MIT

## 🆂🆂🅷 - Generate a new SSH key and add it to the ssh-agent

EMAIL=$1

# check if email is set
if [[ -z "${EMAIL}" ]]; then
  echo "No email argument supplied"
  exit 1
fi

# create default .ssh directory if it doesn’t exist
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/checking-for-existing-ssh-keys
if [[ ! -d "${HOME}/.ssh/" ]]; then
  mkdir "${HOME}/.ssh/"
  chmod 700 "${HOME}/.ssh/"
fi

# check if ssh key already exists
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/checking-for-existing-ssh-keys
if [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
  echo "SSH Key already exists. Skipping SSH Key Generation."
  exit 0
fi

# generate ssh key using ed25519 algorithm
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
# -C set email, -N empty passcode, -q quiet
# WARNING: This creates an SSH key WITHOUT a passphrase for automation purposes.
# For manual/interactive use, consider adding a passphrase for enhanced security.
# See: https://security.stackexchange.com/questions/87044/
ssh-keygen -q -t ed25519 -C "${EMAIL}" -f "${HOME}"/.ssh/id_ed25519 -N ""

# start ssh-agent in the background
ssha="ssh-agent -s"
eval "${ssha}"

# Create config file if it doesn't exist
touch ~/.ssh/config
printf "Host *\n AddKeysToAgent yes\n UseKeychain yes\n IdentityFile ~/.ssh/id_ed25519" | tee ~/.ssh/config

# add ssh key
sudo ssh-add -K "${HOME}"/.ssh/id_ed25519

# print public key to add
echo "SSH Key created and added to agent. Add public key to remote (GitHub, GitLab, etc.)"
echo "Public Key:"
cat "${HOME}"/.ssh/id_ed25519.pub

# adding your SSH key to your GitHub account
# https://docs.github.com/en/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account
echo "run 'pbcopy < ~/.ssh/id_ed25519.pub' and paste that into GitHub"
