#!/usr/bin/env sh

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.448)

## 🆂🆈🅼🅻🅸🅽🅺🆂
export DOTFILES="$HOME"/.dotfiles # Path to the dotfiles directory.

ln -s "$DOTFILES"/vim/vim "$HOME"/.vim # Symlink .vim to .dotfiles/vim/vim.
ln -s "$DOTFILES"/vim/vimrc "$HOME"/.vimrc # Symlink .vimrc to .dotfiles/vim/vimrc.
ln -s "$DOTFILES"/zhrc "$HOME"/.zhrc # Symlink .zhrc to .dotfiles/zhrc.
