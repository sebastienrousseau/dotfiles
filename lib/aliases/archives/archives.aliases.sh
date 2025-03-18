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
        echo "Error: '$1' is not a valid file" | tee -a "$LOG_FILE"
        return 1
    fi

    # Create a log file if logging is enabled
    LOG_FILE=${ARCHIVE_LOG_FILE:-"$HOME/.archive_operations.log"}

    # Handle filenames with spaces correctly
    local filename="$1"
    # shellcheck disable="SC2034,SC2155"
    local dirname=$(dirname "$filename")
    # shellcheck disable="SC2034,SC2155"
    local basename=$(basename "$filename")

    # Create extract directory for archives with multiple files
    if [ "$2" = "-d" ] && [ ! -z "$3" ]; then
        mkdir -p "$3"
        cd "$3" || return 1
    fi

    case "$filename" in
        *.tar.bz2|*.tbz2) tar xvjf "$filename" ;;
        *.tar.gz|*.tgz)   tar xvzf "$filename" ;;
        *.tar.xz)         tar xvJf "$filename" ;;
        *.tar.zst)        tar --zstd -xvf "$filename" ;;
        *.tar)            tar xvf "$filename" ;;
        *.bz2)            bunzip2 "$filename" ;;
        *.gz)             gunzip "$filename" ;;
        *.rar)            unrar x "$filename" ;;
        *.zip)            unzip "$filename" ;;
        *.Z)              uncompress "$filename" ;;
        *.7z)             7z x "$filename" ;;
        *.zst)            unzstd "$filename" ;;
        *.xz)             unxz "$filename" ;;
        *.lz4)            lz4 -d "$filename" ;;
        *.lha|*.lzh)      lha e "$filename" ;;
        *.arj)            arj x "$filename" ;;
        *.arc)            arc e "$filename" ;;
        *.dms)            xdms u "$filename" ;;
        *)                echo "Error: '$filename' cannot be extracted - unknown format" | tee -a "$LOG_FILE" && return 1 ;;
    esac

    # Log successful extraction
    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "Successfully extracted $filename" | tee -a "$LOG_FILE"
    else
        echo "Failed to extract $filename" | tee -a "$LOG_FILE"
    fi
}

#-----------------------------------------------------------------------------
# List Archive Contents Function
#-----------------------------------------------------------------------------
list_archive() {
    if [ -z "$1" ]; then
        echo "Usage: list_archive <archive_file>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2) tar tjf "$1" ;;
        *.tar.gz|*.tgz)   tar tzf "$1" ;;
        *.tar.xz)         tar tJf "$1" ;;
        *.tar.zst)        tar --zstd -tvf "$1" ;;
        *.tar)            tar tf "$1" ;;
        *.rar)            unrar l "$1" ;;
        *.zip)            unzip -l "$1" ;;
        *.7z)             7z l "$1" ;;
        *.lha|*.lzh)      lha l "$1" ;;
        *.arj)            arj l "$1" ;;
        *)                echo "Error: Cannot list contents of '$1' - unknown format" ;;
    esac
}

#-----------------------------------------------------------------------------
# Compress Function with Progress
#-----------------------------------------------------------------------------
compress() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: compress <format> <input_files...> [output_file]"
        echo "Formats: tar, tgz, tbz2, txz, tzst, zip, 7z, gz, bz2, xz, zst, lz4, rar"
        echo "Options: -l <1-9> compression level (if supported by format)"
        return 1
    fi

    local format="$1"
    shift

    # Check for compression level option
    local level=6  # Default compression level
    if [ "$1" = "-l" ]; then
        level="$2"
        shift 2
    fi

    # The last argument might be the output file if it doesn't exist as a file or directory
    local inputs=("$@")
    local num_inputs=${#inputs[@]}
    local output=""

    # If the last argument doesn't exist as a file or directory and has more than 1 argument
    if [ "$num_inputs" -gt 1 ] && [ ! -e "${inputs[$num_inputs-1]}" ]; then
        output="${inputs[$num_inputs-1]}"
        # shellcheck disable="SC2184,2086"
        unset inputs[$num_inputs-1]
    else
        # Default output name based on the first input
        case "$format" in
            tar)    output="${inputs[0]}.tar" ;;
            tgz)    output="${inputs[0]}.tar.gz" ;;
            tbz2)   output="${inputs[0]}.tar.bz2" ;;
            txz)    output="${inputs[0]}.tar.xz" ;;
            tzst)   output="${inputs[0]}.tar.zst" ;;
            zip)    output="${inputs[0]}.zip" ;;
            7z)     output="${inputs[0]}.7z" ;;
            gz)     output="${inputs[0]}.gz" ;;
            bz2)    output="${inputs[0]}.bz2" ;;
            xz)     output="${inputs[0]}.xz" ;;
            zst)    output="${inputs[0]}.zst" ;;
            lz4)    output="${inputs[0]}.lz4" ;;
            rar)    output="${inputs[0]}.rar" ;;
            *)      echo "Error: Unsupported format '$format'" && return 1 ;;
        esac
    fi

    # Check if we have pv installed for progress indication
    local has_pv=0
    if command -v pv >/dev/null 2>&1; then
        has_pv=1
    fi

    # Log file for operations
    LOG_FILE=${ARCHIVE_LOG_FILE:-"$HOME/.archive_operations.log"}

    echo "Compressing to $output..."
    case "$format" in
        tar)
            tar -cf "$output" "${inputs[@]}"
            ;;
        tgz)
            if [ $has_pv -eq 1 ] && [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                pv "${inputs[0]}" | tar -cz -f "$output" -C "$(dirname "${inputs[0]}")" "$(basename "${inputs[0]}")"
            else
                tar -czf "$output" "${inputs[@]}"
            fi
            ;;
        tbz2)
            tar -cjf "$output" -C "$(dirname "${inputs[0]}")" "${inputs[@]}"
            ;;
        txz)
            XZ_OPT="-$level" tar -cJf "$output" "${inputs[@]}"
            ;;
        tzst)
            ZSTD_CLEVEL="$level" tar --zstd -cf "$output" "${inputs[@]}"
            ;;
        zip)
            zip -r "$output" "${inputs[@]}" "-$level"
            ;;
        7z)
            7z a "-mx=$level" "$output" "${inputs[@]}"
            ;;
        gz)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | gzip "-$level" > "$output"
                else
                    gzip -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: gzip compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        bz2)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | bzip2 "-$level" > "$output"
                else
                    bzip2 -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: bzip2 compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        xz)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | xz "-$level" > "$output"
                else
                    xz -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: xz compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        zst)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | zstd "-$level" > "$output"
                else
                    zstd -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: zstd compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        lz4)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | lz4 "-$level" > "$output"
                else
                    lz4 -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: lz4 compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        rar)
            rar a "-m$level" "$output" "${inputs[@]}"
            ;;
        *)
            echo "Error: Unsupported format '$format'" | tee -a "$LOG_FILE"
            return 1
            ;;
    esac

    # Log result
    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "Successfully compressed to $output" | tee -a "$LOG_FILE"
    else
        echo "Failed to compress to $output" | tee -a "$LOG_FILE"
        return 1
    fi
}

#-----------------------------------------------------------------------------
# Compress Large Files Function (Preserved for backward compatibility)
#-----------------------------------------------------------------------------
compress_large() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: compress_large <format> <input_file> [output_file]"
        echo "Note: Consider using the more powerful 'compress' function instead"
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
# Quick Backup Function
#-----------------------------------------------------------------------------
backup() {
    local target="$1"
    local format="${2:-tgz}"  # Default to tar.gz
    # shellcheck disable=SC2155
    local timestamp=$(date +%Y%m%d-%H%M%S)

    if [ -z "$target" ]; then
        echo "Usage: backup <file_or_directory> [format]"
        echo "Available formats: tgz (default), tbz2, txz, tzst, zip, 7z"
        return 1
    fi

    if [ ! -e "$target" ]; then
        echo "Error: '$target' does not exist"
        return 1
    fi

    # shellcheck disable=SC2155
    local basename=$(basename "$target")
    local output="${basename}-backup-${timestamp}"

    case "$format" in
        tgz)  compress tgz "$target" "$output.tar.gz" ;;
        tbz2) compress tbz2 "$target" "$output.tar.bz2" ;;
        txz)  compress txz "$target" "$output.tar.xz" ;;
        tzst) compress tzst "$target" "$output.tar.zst" ;;
        zip)  compress zip "$target" "$output.zip" ;;
        7z)   compress 7z "$target" "$output.7z" ;;
        *)    echo "Error: Unsupported backup format '$format'" && return 1 ;;
    esac

    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "Backup created: $output"
    fi
}

#-----------------------------------------------------------------------------
# Aliases
#-----------------------------------------------------------------------------
# Extract Aliases
alias x='extract'                    # Extract any supported archive

# List Content Aliases
alias l7z='7z l'                     # List 7z archive contents
alias ltar='tar -tvf'                # List tar archive contents
alias ltgz='tar -tzvf'               # List tar.gz archive contents
alias ltbz='tar -tjvf'               # List tar.bz2 archive contents
alias ltxz='tar -tJvf'               # List tar.xz archive contents
alias ltzst='tar --zstd -tvf'        # List tar.zst archive contents
alias lzip='unzip -l'                # List zip archive contents
alias lrar='unrar l'                 # List rar archive contents
alias la='list_archive'              # Generic list archive contents

# 7-Zip Aliases
alias c7z='7z a'                     # Create 7z archive
alias x7z='7z x'                     # Extract 7z archive

# Tar Aliases
alias ctar='tar -cvf'                # Create tar archive
alias xtar='tar -xvf'                # Extract tar archive
alias ctgz='tar -zcvf'               # Create tar.gz archive
alias xtgz='tar -zxvf'               # Extract tar.gz archive
alias ctbz='tar -jcvf'               # Create tar.bz2 archive
alias xtbz='tar -jxvf'               # Extract tar.bz2 archive
alias ctxz='tar -Jcvf'               # Create tar.xz archive
alias xtxz='tar -Jxvf'               # Extract tar.xz archive
alias ctzst='tar --zstd -cvf'        # Create tar.zst archive
alias xtzst='tar --zstd -xvf'        # Extract tar.zst archive

# Zip Aliases
alias czip='zip -r'                  # Create zip archive
alias xzip='unzip'                   # Extract zip archive

# RAR Aliases
alias crar='rar a'                   # Create rar archive
alias xrar='unrar x'                 # Extract rar archive

# Gzip Aliases
alias cgz='gzip -cv'                 # Compress with gzip
alias xgz='gzip -dv'                 # Extract gzip

# Bzip2 Aliases
alias cbz='bzip2 -zk'                # Compress with bzip2
alias xbz='bzip2 -dk'                # Extract bzip2

# XZ Aliases
alias cxz='xz -z'                    # Compress with xz
alias xxz='xz -d'                    # Extract xz

# Zstd Aliases
alias czst='zstd -z'                 # Compress with zstd
alias xzst='zstd -d'                 # Extract zstd

# LZ4 Aliases
alias clz4='lz4 -zc'                 # Compress with lz4
alias xlz4='lz4 -dc'                 # Extract lz4

# Combined Aliases
alias c='compress'                   # Generic compression function
alias cl='compress_large'            # Legacy compress_large function
alias b='backup'                     # Quick backup function
