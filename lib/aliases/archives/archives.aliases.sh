#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Archive and Compression Management
# Made with ♥ by Sebastien Rousseau
# License: MIT
# This script provides functions and aliases for handling various archive formats.

#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------
# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Extract various archive formats
extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <archive_file>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2) tar xvjf "$1" ;;
        *.tar.gz|*.tgz)   tar xvzf "$1" ;;
        *.tar.xz)         tar xvJf "$1" ;;
        *.tar.zst)        tar --zstd -xvf "$1" ;;
        *.tar)            tar xvf "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.zip)            unzip "$1" ;;
        *.Z)              uncompress "$1" ;;
        *.7z)             7z x "$1" ;;
        *.zst)            unzstd "$1" ;;
        *.xz)             unxz "$1" ;;
        *.lz4)            lz4 -d "$1" ;;
        *)                echo "Error: '$1' cannot be extracted" && return 1 ;;
    esac
}

# Compress large files with flexible format support
compress_large() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: compress_large <format> <input_file> [output_file]"
        return 1
    fi

    local format="$1"
    local input="$2"
    local output="${3:-${input}.${format}}"

    if [ ! -f "$input" ]; then
        echo "Error: '$input' is not a valid file"
        return 1
    fi

    case "$format" in
        gz)     gzip -c "$input" > "$output" ;;
        bz2)    bzip2 -c "$input" > "$output" ;;
        xz)     xz -c "$input" > "$output" ;;
        zst)    zstd -c "$input" > "$output" ;;
        lz4)    lz4 -c "$input" > "$output" ;;
        *)      echo "Error: Unsupported format '$format'" && return 1 ;;
    esac
    echo "Compressed '$input' to '$output'"
}

#-----------------------------------------------------------------------------
# Aliases for Compression Tools
#-----------------------------------------------------------------------------
# 7-Zip
if command_exists 7z; then
    alias a7z='7z a'                     # Create 7z archive
    alias x7z='7z x'                     # Extract 7z archive
    alias l7z='7z l'                     # List contents of 7z archive
    alias t7z='7z t'                     # Test 7z archive integrity
fi

# Tar
if command_exists tar; then
    alias ctar='tar -cvf'                # Create tar archive
    alias xtar='tar -xvf'                # Extract tar archive
    alias ltar='tar -tvf'                # List contents of tar archive
    alias ctgz='tar -zcvf'               # Create tar.gz archive
    alias xtgz='tar -zxvf'               # Extract tar.gz archive
    alias ctbz='tar -jcvf'               # Create tar.bz2 archive
    alias xtbz='tar -jxvf'               # Extract tar.bz2 archive
    alias ctxz='tar -Jcvf'               # Create tar.xz archive
    alias xtxz='tar -Jxvf'               # Extract tar.xz archive
    alias ctzst='tar --zstd -cvf'        # Create tar.zst archive
    alias xtzst='tar --zstd -xvf'        # Extract tar.zst archive
fi

# Zip
if command_exists zip; then
    alias czip='zip -r'                  # Create zip archive
    alias xzip='unzip'                   # Extract zip archive
    alias lzip='unzip -l'                # List contents of zip archive
fi

# Compression Tools
if command_exists gzip; then
    alias cgz='gzip -cv'                 # Compress with gzip
    alias xgz='gzip -dv'                 # Extract gzip
fi

if command_exists bzip2; then
    alias cbz='bzip2 -zk'                # Compress with bzip2
    alias xbz='bzip2 -dk'                # Extract bzip2
fi

if command_exists xz; then
    alias cxz='xz -z'                    # Compress with xz
    alias xxz='xz -d'                    # Extract xz
fi

if command_exists zstd; then
    alias czst='zstd -z'                 # Compress with zstd
    alias xzst='zstd -d'                 # Extract zstd
fi

if command_exists lz4; then
    alias clz4='lz4 -zc'                 # Compress with lz4
    alias xlz4='lz4 -dc'                 # Extract lz4
fi

#-----------------------------------------------------------------------------
# Tab Completion for Extract
#-----------------------------------------------------------------------------
_extract_completion() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -f -X '!*.*(tar.bz2|tbz2|tar.gz|tgz|tar.xz|tar.zst|tar|bz2|gz|rar|zip|Z|7z|zst|xz|lz4)' -- "$cur"))
}
complete -F _extract_completion extract

# Export functions for subshells
export -f extract
export -f compress_large
