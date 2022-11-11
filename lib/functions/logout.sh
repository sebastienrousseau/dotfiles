#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# logout: Function to logout from OS X via the Terminal
logout() {
	osascript -e 'tell application "System Events" to log out'
	builtin logout
}
