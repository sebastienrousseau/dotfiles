#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🅰🅻🅸🅰🆂🅴🆂

# Load custom executable aliases
for file in $DF_HOME/aliases/*/[^.#]*.sh; do
  # shellcheck source=/dev/null
  source "$file"
done

# shellcheck source=/dev/null
# source "$DF_HOME"/aliases/aliases.plugin.sh # Load default aliases.

## shellcheck source=/dev/null
# source "$DF_HOME"/aliases/gcloud/gcloud.plugin.zsh # Load gcloud aliases.

## shellcheck source=/dev/null
# source "$DF_HOME"/aliases/git/git.plugin.zsh # Load git aliases.

## shellcheck source=/dev/null
# source "$DF_HOME"/aliases/heroku/heroku.plugin.zsh # Load heroku aliases.

## shellcheck source=/dev/null
# source "$DF_HOME"/aliases/homebrew/homebrew.plugin.zsh # Load homebrew aliases.

## shellcheck source=/dev/null
# source "$DF_HOME"/aliases/jekyll/jekyll.plugin.zsh # Load jekyll aliases.

## shellcheck source=/dev/null
# source "$DF_HOME"/aliases/subversion/subversion.plugin.zsh # Load subversions aliases.
