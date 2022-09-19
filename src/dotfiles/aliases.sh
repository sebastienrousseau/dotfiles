#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🅰🅻🅸🅰🆂🅴🆂

# Load custom executable aliases
for file in $DOTFILES/aliases/*/[^.#]*.sh; do
  # shellcheck source=/dev/null
  source "$file"
done

# shellcheck source=/dev/null
# source "$DOTFILES"/aliases/aliases.plugin.sh # Load default aliases.

## shellcheck source=/dev/null
# source "$DOTFILES"/aliases/gcloud/gcloud.plugin.zsh # Load gcloud aliases.

## shellcheck source=/dev/null
# source "$DOTFILES"/aliases/git/git.plugin.zsh # Load git aliases.

## shellcheck source=/dev/null
# source "$DOTFILES"/aliases/heroku/heroku.plugin.zsh # Load heroku aliases.

## shellcheck source=/dev/null
# source "$DOTFILES"/aliases/homebrew/homebrew.plugin.zsh # Load homebrew aliases.

## shellcheck source=/dev/null
# source "$DOTFILES"/aliases/jekyll/jekyll.plugin.zsh # Load jekyll aliases.

## shellcheck source=/dev/null
# source "$DOTFILES"/aliases/subversion/subversion.plugin.zsh # Load subversions aliases.
