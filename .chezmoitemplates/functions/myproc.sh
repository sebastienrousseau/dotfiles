# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
# myproc: Function to list processes owned by an user
myproc() { ps "$@" -u "${USER}" -o pid,%cpu,%mem,start,time,command; }
