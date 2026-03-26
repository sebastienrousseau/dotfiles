# IPython configuration
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
c = get_config()  # noqa: F821

# Prompt
c.TerminalInteractiveShell.confirm_exit = False
c.TerminalInteractiveShell.editing_mode = "vi"
c.TerminalInteractiveShell.true_color = True

# History
c.HistoryAccessor.hist_file = ""

# Auto-reload modules
c.InteractiveShellApp.extensions = ["autoreload"]
c.InteractiveShellApp.exec_lines = ["%autoreload 2"]

# Display
c.TerminalInteractiveShell.highlighting_style = "monokai"
