#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

# logout: Function to logout from OS X via the Terminal
logout() {
	osascript -e 'tell application "System Events" to log out'
	builtin logout
}
