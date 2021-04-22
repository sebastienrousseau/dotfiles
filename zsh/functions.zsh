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
#  	Custom Functions
#
#  ---------------------------------------------------------------------------

# load custom executable functions
for function in ~/zsh/functions/*; do
  source $function
done

# To be tested and triaged (multi-display support)
#
# set dual monitors
# dual () {
#     xrandr --output eDP1 --primary --left-of HDMI1 --output HDMI1 --mode 1280x720
# }
# 
# dual2 () {
#     xrandr --output eDP1 --primary --left-of HDMI1 --output HDMI1 --auto
# }
# 
# # set single monitor
# single () {
#     xrandr --output HDMI1 --off
# }
# 
# 
# 
# # aliasc: Function alias
# function aliasc() {
#   alias | grep "^${1}=" | awk -F= '{ print $2 }' | sed "s/^'//" | sed "s/'$//"
# }
