# shellcheck shell=bash
# Copyright (c) 2015-2026. All rights reserved.
# Description: Script containing default shell aliases
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Function: set_default_aliases
#
# Description:
#   Sets default shell aliases for enhanced shell usage.
#
# Arguments:
#   None
#
# Notes:
#   - Some aliases are designed for enhanced shell navigation and utility.
#   - Ensure to validate that all aliases work as expected in the bash shell.

set_default_aliases() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        fc -W >/dev/null 2>&1 || true
    elif [ -n "${BASH_VERSION:-}" ]; then
        history -a >/dev/null 2>&1 || true
    fi

    ## General aliases

    # Display the current date and time.
    alias da='date "+%Y-%m-%d %A %T %Z"'

    # Shortcut for `pwd` which returns working directory name.
    alias p='pwd'

    # Display the $PATH variable on newlines.
    alias path='echo ${PATH//:/\\n}'

    # Reload the shell.
    alias r='reload'

    # Prints the last 10 lines of a text or log file, and then waits for new
    # additions to the file to print it in real time.
    alias t='tail -f'

    # Show the current week number.
    alias wk='date +%V'

    ## Exit/shutdown aliases
    # Shortcut for the `exit` command.
    alias ':q'='quit'

    # Shortcut for the `exit` command.
    alias bye='quit'

    # Shortcut for the `exit` command.
    alias q='quit'

    # Shortcut for the `exit` command.
    alias quit='exit'

    # Shutdown the system.
    alias halt='sudo /sbin/halt'

    # Alias to view history
    alias h='history'
    alias history='fc -il 1' # Show history with ISO 8601 timestamps

    # Poweroff the system.
    alias poweroff='sudo /sbin/shutdown'

    # Reboot the system.
    alias reboot='sudo /sbin/reboot'

    ## Network aliases
    # Append sudo to ifconfig (configure network interface parameters)
    # command.
    alias ifconfig='sudo ifconfig'

    # Get network interface parameters for en0.
    alias ipinfo='ipconfig getpacket en0'

    # Show only active network listeners.
    alias nls='sudo lsof -i -P | grep LISTEN'

    # List of open ports.
    alias op='sudo lsof -i -P'

    # Limit Ping to 5 ECHO_REQUEST packets.
    alias ping='ping -c 5'

    # List all listening ports.
    alias ports='netstat -tulan'

    ## System monitoring aliases
    # Allows the user to interactively monitor the system's vital resources
    # or server's processes in real time.
    alias top='sudo btop'

    # Clear ASL logs (macOS) - requires confirmation
    clear_asl_logs() {
      if [[ "$(uname)" != "Darwin" ]]; then
        echo "[ERROR] This command is macOS-only" >&2
        return 1
      fi
      echo "[WARNING] This will delete all ASL logs in /private/var/log/asl/"
      read -r -p "Continue? [y/N] " confirm
      [[ "$confirm" == [yY]* ]] || { echo "Aborted."; return 1; }
      sudo rm -rf /private/var/log/asl/* && echo "[INFO] ASL logs cleared."
    }
    alias clearasl='clear_asl_logs'

    ## Utility aliases
    # Count the number of files in the current directory.
    alias ctf='echo $(ls -1 | wc -l)'

    # Quickly search for file.
    alias qfind='find . -name '

    # Reload the shell.
    alias reload='exec $SHELL -l'

    # Get the weather.
    alias wth='curl -s "wttr.in/?format=3"'

    ## File system navigation aliases
}

set_default_aliases
