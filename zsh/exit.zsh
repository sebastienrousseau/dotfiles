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
#  Sections:																
#  																			
#  	1. Executed by Ze Shell when login shell exits 
#
#  ---------------------------------------------------------------------------

# When leaving the console clear the screen to increase privacy
if [[ "$SHLVL" = 1 ]]; then
  clear && printf '\e[3J'
fi
