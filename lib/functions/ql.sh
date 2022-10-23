#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2022. All rights reserved
# License: MIT

# ql: Function to open any file in MacOS Quicklook Preview
ql() { qlmanage -p "$*" >&/dev/null; }
