# shellcheck shell=bash
# CD Navigation - Directory Stack Management
[[ -n "${_CD_STACK_LOADED:-}" ]] && return 0
_CD_STACK_LOADED=1

alias dirs='dirs -v'        # List directory stack with indices
alias pd='pushd'            # Push directory to stack
alias popd='popd && ls -lh' # Pop directory from stack and list contents
