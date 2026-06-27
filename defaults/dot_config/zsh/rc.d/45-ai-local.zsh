# shellcheck shell=bash
# Meridian local routing
#
# When `dot ai local on` has been run, an env file pins ANTHROPIC_BASE_URL /
# OPENAI_BASE_URL at the local Meridian proxy so every Anthropic/OpenAI
# CLI in the fleet talks to one Claude subscription served locally. The
# toggle is opt-in (gated on DOTFILES_AI) and reversible (`dot ai local off`
# removes the file). No file → no effect, so this is a cheap no-op when
# local routing is not in use.
if [[ -n "${DOTFILES_AI:-}" ]]; then
  _ai_local_env="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ai-local.env"
  [[ -r "$_ai_local_env" ]] && source "$_ai_local_env"
  unset _ai_local_env
fi
