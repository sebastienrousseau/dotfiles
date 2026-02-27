# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
# ql: Function to open any file in MacOS Quicklook Preview
ql() { qlmanage -p "$*" >&/dev/null; }
