#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.460) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# logout: Function to logout from OS X via the Terminal
logout() {
	osascript -e 'tell application "System Events" to log out'
	builtin logout
}
