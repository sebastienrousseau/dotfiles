#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - sysinfo
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# sysinfo - A minimal system information script with emoji OS icons.
#
# This script displays basic system information in a style similar to neofetch,
# but simpler. It attempts to detect OS, CPU, GPU, memory, etc.
#
# Usage:
#   sysinfo
#
################################################################################

#-------------------------------#
# Color Variables               #
#-------------------------------#
GREEN='\033[0;32m'
RESET='\033[0m'

#######################################
# Detect platform and choose an emoji.
#######################################
case "$(uname -s)" in
    Darwin)
        emoji="🍎"
        ;;
    Linux)
        emoji="🐧"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        emoji="🪟"
        ;;
    *)
        emoji="🖥"
        ;;
esac

hostname=$(hostname)

#######################################
# Collect system information depending on OS.
#######################################
if [[ "$(uname -s)" = "Darwin" ]]; then
    hw_info=$(system_profiler SPHardwareDataType)
    disp_info=$(system_profiler SPDisplaysDataType)

    model_name=$(echo "${hw_info}" | awk -F': ' '/Model Name/{print $2}')
    model_id=$(echo "${hw_info}" | awk -F': ' '/Model Identifier/{print $2}')
    chip=$(echo "${hw_info}" | awk -F': ' '/Chip/{print $2}')
    total_cores=$(echo "${hw_info}" | awk -F': ' '/Total Number of Cores/{print $2}')
    mem=$(echo "${hw_info}" | awk -F': ' '/Memory/{print $2}')

    os="macOS $(sw_vers -productVersion)"
    kernel=$(uname -r)
    uptime=$(uptime | sed 's/.*up //' | sed 's/, .*//')
    cpu="$chip ($total_cores cores)"
    gpu=$(echo "${disp_info}" | awk -F': ' '/Chipset Model/ {print $2; exit}')
    resolution=$(echo "${disp_info}" | awk -F': ' '/Resolution/{print $2}' | head -n1)
    shell=$(basename "${SHELL}")

    terminal=${TERM_PROGRAM:-"${TERM}"}
    memory="${mem}"

elif [[ "$(uname -s)" = "Linux" ]]; then
    # OS
    if [ -f /etc/os-release ]; then
        os=$(awk -F= '/^PRETTY_NAME/{print $2}' /etc/os-release 2>/dev/null | tr -d \")
    else
        os=$(uname -s)
    fi

    kernel=$(uname -r)
    uptime=$(uptime -p | sed 's/up //')
    shell=$(basename "${SHELL}")
    terminal=${TERM:-"Unknown"}

    # CPU (check if lscpu is available)
    if command -v lscpu >/dev/null 2>&1; then
        cpu=$(lscpu 2>/dev/null | awk -F': +' '/Model name/ {print $2; exit}')
    else
        cpu="Unknown CPU"
    fi

    # GPU (check if lspci is available)
    if command -v lspci >/dev/null 2>&1; then
        gpu=$(lspci 2>/dev/null | grep -E "VGA|3D" | sed -E "s/.*: (.*)/\1/" | head -n1)
    else
        gpu="Unknown GPU"
    fi

    # Memory
    mem_total_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -n "${mem_total_kb:-}" ]; then
        memory=$(awk "BEGIN {printf \"%.1fGiB\",$mem_total_kb/1024/1024}")
    else
        memory="Unknown"
    fi

    # Resolution (check if xrandr is available)
    if command -v xrandr >/dev/null 2>&1; then
        resolution=$(xrandr --current 2>/dev/null | awk '/\*/{print $1; exit}')
    else
        resolution="Unknown"
    fi

    model_name=""
    model_id=""

else
    # Fallback
    os=$(uname -s)
    kernel=$(uname -r)
    uptime="Unknown"
    cpu="Unknown"
    gpu="Unknown"
    shell=$(basename "${SHELL}")
    terminal=${TERM:-"Unknown"}
    memory="Unknown"
    resolution="Unknown"
    model_name=""
    model_id=""
fi

#######################################
# Print system information.
#######################################
sysinfo() {
    printf "%s  %s\n" "${emoji}" "${hostname}"
    echo "------------------"
    echo "${GREEN}OS:${RESET}         ${os}"
    echo "${GREEN}Kernel:${RESET}     ${kernel}"
    echo "${GREEN}Uptime:${RESET}     ${uptime}"
    echo "${GREEN}CPU:${RESET}        ${cpu}"
    echo "${GREEN}GPU:${RESET}        ${gpu}"
    echo "${GREEN}Memory:${RESET}     ${memory}"
    echo "${GREEN}Shell:${RESET}      ${shell}"
    echo "${GREEN}Terminal:${RESET}   ${terminal}"
    echo "${GREEN}Resolution:${RESET} ${resolution}"
    if [[ -n "${model_name}" ]] && [[ -n "${model_id}" ]]; then
        echo "Model:      ${model_name} (${model_id})"
    fi
}