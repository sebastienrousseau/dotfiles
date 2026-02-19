# shellcheck shell=bash
# Yarn Aliases

if command -v yarn &>/dev/null; then
  alias y='yarn'
  alias ya='yarn add'
  alias yad='yarn add --dev'
  alias yga='yarn global add'
  alias yi='yarn install'
  alias yin='yarn init'
  alias yls='yarn list'
  alias yout='yarn outdated'
  alias yp='yarn pack'
  alias yrm='yarn remove'
  alias yrun='yarn run'
  alias ys='yarn serve'
  alias yst='yarn start'
  alias yt='yarn test'
  alias ytc='yarn test --coverage'
  alias yuc='yarn global upgrade && yarn cache clean'
  alias yui='yarn upgrade-interactive'
  alias yup='yarn upgrade'
  alias yv='yarn version'
  alias yw='yarn workspace'
  alias yws='yarn workspaces'
fi
