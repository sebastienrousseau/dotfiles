#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Archive and Compression Management
# Made with ♥ by Sebastien Rousseau
# License: MIT

#-----------------------------------------------------------------------------
# Extract Function
#-----------------------------------------------------------------------------
# Archive and Compression Management

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

#-----------------------------------------------------------------------------
# Compress Function
#-----------------------------------------------------------------------------
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
# Aliases
#-----------------------------------------------------------------------------
# 7-Zip Aliases
alias a7z='7z a'          # Create 7z archive
alias x7z='7z x'          # Extract 7z archive

# Tar Aliases
alias ctar='tar -cvf'     # Create tar archive
alias xtar='tar -xvf'     # Extract tar archive
alias ltar='tar -tvf'     # List tar archive contents
alias ctgz='tar -zcvf'    # Create tar.gz archive
alias xtgz='tar -zxvf'    # Extract tar.gz archive
alias ctbz='tar -jcvf'    # Create tar.bz2 archive
alias xtbz='tar -jxvf'    # Extract tar.bz2 archive
alias ctxz='tar -Jcvf'    # Create tar.xz archive
alias xtxz='tar -Jxvf'    # Extract tar.xz archive
alias ctzst='tar --zstd -cvf' # Create tar.zst archive
alias xtzst='tar --zstd -xvf' # Extract tar.zst archive

# Zip Aliases
alias czip='zip -r'       # Create zip archive
alias xzip='unzip'        # Extract zip archive
alias lzip='unzip -l'     # List zip archive contents

# Gzip Aliases
alias cgz='gzip -cv'      # Compress with gzip
alias xgz='gzip -dv'      # Extract gzip

# Bzip2 Aliases
alias cbz='bzip2 -zk'     # Compress with bzip2
alias xbz='bzip2 -dk'     # Extract bzip2

# XZ Aliases
alias cxz='xz -z'         # Compress with xz
alias xxz='xz -d'         # Extract xz

# Zstd Aliases
alias czst='zstd -z'      # Compress with zstd
alias xzst='zstd -d'      # Extract zstd

# LZ4 Aliases
alias clz4='lz4 -zc'      # Compress with lz4
alias xlz4='lz4 -dc'      # Extract lz4

