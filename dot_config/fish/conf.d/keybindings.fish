# Fish 4.x Enhanced Keybindings
# Leverages Fish 4.0+ keyboard protocol support (modifyOtherKeys, kitty protocol)
# for rich key combinations not possible in older terminals.

if not status is-interactive
    return
end

# Ctrl+Backspace: delete word backward
bind ctrl-backspace backward-kill-word

# Alt+Enter: accept autosuggestion and execute
bind alt-enter 'commandline -f accept-autosuggestion; commandline -f execute'

# Ctrl+Z: undo last edit
bind ctrl-z undo

# Ctrl+Shift+Z: redo
bind ctrl-shift-z redo

# Alt+Up/Down: navigate directory history
bind alt-up 'prevd; commandline -f repaint'
bind alt-down 'nextd; commandline -f repaint'

# Ctrl+Left/Right: move by word (already default, but explicit for clarity)
bind ctrl-left backward-word
bind ctrl-right forward-word

# Alt+L: list directory (quick ls)
bind alt-l 'echo; ls; commandline -f repaint'

# Alt+.: insert last argument from previous command
bind alt-. history-token-search-backward

# Ctrl+G: open git status
bind ctrl-g 'echo; git status --short 2>/dev/null || echo "Not a git repo"; commandline -f repaint'

# Alt+E: edit command in $EDITOR
bind alt-e edit_command_buffer

# FZF keybindings (if fzf is available)
if command -q fzf
    # Ctrl+R is handled by fzf or atuin
    # Ctrl+T: file picker
    bind ctrl-t 'set -l result (fzf --height 40% --reverse 2>/dev/null); and commandline -it -- $result; commandline -f repaint'
end
