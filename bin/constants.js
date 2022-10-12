/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.458) - https://dotfiles.io
* Copyright (c) Sebastien Rousseau 2022. All rights reserved
* License: MIT
*/

// 🅲🅾🅽🆂🆃🅰🅽🆃🆂 - Constants.
const version = "dotfiles-0.2.458.tgz";
const dotfile ="https://registry.npmjs.org/@sebastienrousseau/dotfiles/-/dotfiles-0.2.458.tgz";

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

const config = [
  "shell/configurations/tmux/default",
  "shell/configurations/tmux/display",
  "shell/configurations/tmux/linux",
  "shell/configurations/tmux/navigation",
  "shell/configurations/tmux/panes",
  "shell/configurations/tmux/theme",
  "shell/configurations/tmux/vi"
];

const tmux = "$DOTFILES/configurations/tmux/";

module.exports = { aliases, config, copies, dotfile, tmux, version };
