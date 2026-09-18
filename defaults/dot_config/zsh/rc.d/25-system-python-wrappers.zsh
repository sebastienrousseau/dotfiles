# shellcheck shell=bash
# Wrappers for /usr/bin scripts using `#!/usr/bin/env python3`
#
# mise (with activate_aggressive=true) places its Python installs ahead of
# /usr/bin in PATH, so system scripts resolve to mise Python which lacks
# system-only bindings like `gi` (from Arch's python-gobject, installed only
# under /usr/lib/python3.14/site-packages). See memory: mise_python_shadowing.md

powerprofilesctl() { /usr/bin/python3.14 /usr/bin/powerprofilesctl "$@"; }
