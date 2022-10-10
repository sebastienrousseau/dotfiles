/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.457) - https://dotfiles.io
* Copyright (c) Sebastien Rousseau 2022. All rights reserved
* License: MIT
*/

// 🅲🅾🅽🆂🆃🅰🅽🆃🆂 - Constants.
const version = "dotfiles-0.2.457.tgz";
const dotfile ="https://registry.npmjs.org/@sebastienrousseau/dotfiles/-/dotfiles-0.2.457.tgz";

const aliases = [
  ".bashrc",
  "cacert.pem",
  ".curlrc",
  ".inputrc",
  ".jshintrc",
  ".profile",
  ".tmux.conf",
  ".vimrc",
  ".wgetrc",
  ".zshrc"
];

const copies = [
  "shell/configurations/bash/bashrc",
  "shell/configurations/curl/cacert.pem",
  "shell/configurations/curl/curlrc",
  "shell/configurations/input/inputrc",
  "shell/configurations/jshint/jshintrc",
  "shell/configurations/profile/profile",
  "shell/configurations/tmux/tmux",
  "shell/configurations/vim/vimrc",
  "shell/configurations/wget/wgetrc",
  "shell/configurations/zsh/zshrc",
];

module.exports = { aliases, copies, dotfile, version };
