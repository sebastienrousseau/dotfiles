##!/bin/zsh

# uuid: Function to generate a UUID (Universally Unique IDentifier)
# function uuid() {
#   local N B C='89ab' # 89ab is the hexadecimal value of 10, 11, 12, 13, 14, 15 in decimal
#   for ((N = 0; N < 16; ++N)); do
#     B=$(($RANDOM % 256))
#     case $N in
#     6)
#       printf '4%x' $((B % 16))
#       ;;
#     8)
#       printf '%c%x' ${C:$RANDOM%${#C}:1} $((B % 16))
#       ;;
#     3 | 5 | 7 | 9)
#       printf '%02x-' $B
#       ;;
#     *)
#       printf '%02x' $B
#       ;;
#     esac
#   done
#   echo
# }

# shellcheck shell=bash
about-alias 'uuidgen aliases'

if _command_exists uuid; then # Linux
	alias uuidu="uuid | tr '[:lower:]' '[:upper:]'"
	alias uuidl=uuid
elif _command_exists uuidgen; then # macOS/BSD
	alias uuidu="uuidgen"
	alias uuid="uuidgen | tr '[:upper:]' '[:lower:]'" # because upper case is like YELLING
	alias uuidl=uuid
fi
