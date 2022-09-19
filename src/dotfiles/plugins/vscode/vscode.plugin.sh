#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🅿🅻🆄🅶🅸🅽🆂

# Add Visual Studio Code (code)
# code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $"*" ;}

#   ----------------------------------------------------------------------------
#   1.0 Functions Detect Visual Studio.
#   ----------------------------------------------------------------------------

if [[ $('uname') == 'Linux' ]]; then
    local _vscode_linux_paths > /dev/null 2>&1
    _vscode_linux_paths=(
        "/opt/vscode/code"
        "/usr/local/bin/code"
        "$HOME/bin/code"
    )
    for _vscode_path in $_vscode_linux_paths; do
        if [[ -a $_vscode_path ]]; then
            vs_run() { $_vscode_path $@ >/dev/null 2>&1 &| }
            vs_run_sudo() {sudo $_vscode_path $@ >/dev/null 2>&1}
            # svs: Editing system protected files.
            alias svs=vs_run_sudo

            # vs: Launch Visual Studio Code.
            alias vs=vs_run
            break
        fi
    done

elif  [[ "$OSTYPE" = darwin* ]]; then
    local _vscode_darwin_paths > /dev/null 2>&1
    _vscode_darwin_paths=(
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        "/usr/local/bin/code"
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    )
    for _vscode_path in $_vscode_darwin_paths; do
        if [[ -a $_vscode_path ]]; then
            vs_run () { "$_vscode_path" $* }
            vs_run_sudo () {sudo "$_vscode_path" $* }
            # svs: Editing system protected files.
            alias svs=vs_run_sudo

            # vs: Launch Visual Studio Code.
            alias vs=vs_run
            break
        fi
    done

elif [[ "$OSTYPE" = 'cygwin' ]]; then
    local _vscode_cygwin_paths > /dev/null 2>&1
    _vscode_cygwin_paths=(
        "$(cygpath $ProgramW6432/Visual\ Studio\ Code)/code.exe"
    )
    for _vscode_path in $_vscode_cygwin_paths; do
        if [[ -a $_vscode_path ]]; then
            vs_run () { "$_vscode_path" $* }
            # vs: Launch Visual Studio Code.
            alias vs=vs_run
            break
        fi
    done

fi



#   ----------------------------------------------------------------------------
#   2.0 Visual Studio Code aliases.
#   ----------------------------------------------------------------------------

# vsd: Open a file difference editor. Requires two file paths as arguments.
alias vsd='vs --diff'

# vsgt: When used with file:line[:character], opens a file at a specific line and
#       optional character position. This argument is provided since some operating
#       systems permit : in a file name.
alias vsgt='vs --goto'

# vsh: Print usage.
alias vsh='vs --help'

# vsl: Set the display language (locale) for the VS Code session.
alias vsl='vs --locale '

# vsnw: Opens a new session of VS Code instead of restoring the previous session.
alias vsnw='vs --new-window'

# vsrw: Forces opening a file or folder in the last active window.
alias vsrw='vs --reuse-window'

# vst: Open VS Code from current directory.
alias vst='vs .'

# vsv: Print VS Code version, GitHub commit id, and architecture.
alias vsv='vs --version'

# vsw: Wait for the files to be closed before returning.
alias vsw='vs --wait'
