#  ---------------------------------------------------------------------------
#
#  ______      _  ______ _ _           
#  |  _  \    | | |  ___(_) |          
#  | | | |___ | |_| |_   _| | ___  ___ 
#  | | | / _ \| __|  _| | | |/ _ \/ __|
#  | |/ / (_) | |_| |   | | |  __/\__ \
#  |___/ \___/ \__\_|   |_|_|\___||___/
#                                                                            
#  Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
#  Prompt configuration
#
#  ---------------------------------------------------------------------------

# Normal prompt (👽) & Root prompt (😈)
PROMPT='%(!.😈 %F{red}%S%n%s%f %F{red}❱❱❱%f .👽 %F{green}%S%n%s%f %F{green}❱❱❱%f )'
export PROMPT

RPROMPT='%(!.%F{red}%B%U%d%b%u%f.%F{green}%B%U%d%b%u%f)'
export RPROMPT

# Force prompt to write history after every command.
PROMPT_COMMAND='history -a; $PROMPT_COMMAND'
