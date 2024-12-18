/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
* Made with ♥ in London, UK by @wwdseb
* Copyright (c) 2015-2024. All rights reserved
* License: MIT
*/

// 🅲🅾🅽🆂🆃🅰🅽🆃🆂 - Constants.
const version = "dotfiles-0.2.469.tgz";
const dotfile = "https://registry.npmjs.org/@wwdseb/dotfiles/-/dotfiles-0.2.469.tgz";

const aliases = [
  ".bashrc",
  "cacert.pem",
  ".curlrc",
  ".gemrc",
  ".inputrc",
  ".jshintrc",
  ".nanorc",
  ".profile",
  ".tmux.conf",
  ".vimrc",
  ".wgetrc",
  ".zshrc"
];

const copies = [
  "lib/configurations/bash/bashrc",
  "lib/configurations/curl/cacert.pem",
  "lib/configurations/curl/curlrc",
  "lib/configurations/gem/gemrc",
  "lib/configurations/input/inputrc",
  "lib/configurations/jshint/jshintrc",
  "lib/configurations/nano/nanorc",
  "lib/configurations/profile/profile",
  "lib/configurations/tmux/tmux",
  "lib/configurations/vim/vimrc",
  "lib/configurations/wget/wgetrc",
  "lib/configurations/zsh/zshrc",
];

const config = [
  "lib/configurations/tmux/default",
  "lib/configurations/tmux/display",
  "lib/configurations/tmux/linux",
  "lib/configurations/tmux/navigation",
  "lib/configurations/tmux/panes",
  "lib/configurations/tmux/theme",
  "lib/configurations/tmux/vi"
];

const tmux = "$DOTFILES/configurations/tmux/";

module.exports = { aliases, config, copies, dotfile, tmux, version };
