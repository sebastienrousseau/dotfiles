# shellcheck shell=bash
# myproc: Function to list processes owned by an user
myproc() { ps "$@" -u "${USER}" -o pid,%cpu,%mem,start,time,command; }
