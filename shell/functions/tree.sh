#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# tree: Function to generates a tree view from the current directory
#if [ ! -e /usr/local/bin/tree ]; then
#	tree(){
#		pwd
#		ls -R | grep ":$" |   \
#		sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' -e 's/^/   /' -e 's/-/|/'
#	}
#fi