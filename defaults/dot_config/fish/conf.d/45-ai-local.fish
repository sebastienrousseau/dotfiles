# Meridian local routing (fish)
#
# Fish counterpart to zsh/rc.d/45-ai-local.zsh. When `dot ai local on` has
# been run, source the generated fish env so every Anthropic/OpenAI CLI in
# the fleet talks to the local Meridian proxy. Opt-in via DOTFILES_AI and
# reversible with `dot ai local off`. No file → no effect.
if set -q DOTFILES_AI
    set -l _ai_cfg $HOME/.config
    set -q XDG_CONFIG_HOME; and set _ai_cfg $XDG_CONFIG_HOME
    set -l _ai_local_env $_ai_cfg/dotfiles/ai-local.fish
    test -r $_ai_local_env; and source $_ai_local_env
    set -e _ai_cfg _ai_local_env
end
