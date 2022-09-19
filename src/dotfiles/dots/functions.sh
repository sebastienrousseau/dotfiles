#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

# Load custom executable functions
for function in "$DF_HOME"/functions/[^.#]*.bash; do
  # shellcheck source=/dev/null
  source "$function"
done

# TODO: #19 To be tested and triaged (multi-display support)
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
# TODO: #20 Test Function alias
# # aliasc: Function alias
# function aliasc() {
#   alias | grep "^${1}=" | awk -F= '{ print $2 }' | sed "s/^'//" | sed "s/'$//"
# }
