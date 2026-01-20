# shellcheck shell=bash
# Diagnostics Aliases

# JSON Processing (jq)
if command -v jq &>/dev/null; then
  alias j='jq'
  alias jc='jq -C' # Colorize
  alias jr='jq -r' # Raw output
fi

# YAML Processing (yq)
if command -v yq &>/dev/null; then
  alias yq='yq'
  alias yqr='yq eval -r' # Raw output
  alias yqy='yq eval -P' # Pretty print
fi

# Netcat (nc)
if command -v nc &>/dev/null; then
  alias nc='nc'
  alias ncl='nc -l' # Listen mode
  alias ncv='nc -v' # Verbose
  alias ncz='nc -zv' # Scan ports
fi

# Curlie (Modern curl)
if command -v curlie &>/dev/null; then
  alias curl='curlie'
fi
