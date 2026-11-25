# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# myproc: Function to list processes owned by an user
myproc() { ps "$@" -u "${USER}" -o pid,%cpu,%mem,start,time,command; }
