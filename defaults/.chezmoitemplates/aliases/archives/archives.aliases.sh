# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#-----------------------------------------------------------------------------
# Archive and Compression Management

# extract's per-family unpackers (tar archives, single-file compressors,
# other archivers). extract checks the tar patterns first.
_extract_tar() {
  case "$1" in
    *.tar.bz2 | *.tbz2) tar xvjf "$1" ;;
    *.tar.gz | *.tgz) tar xvzf "$1" ;;
    *.tar.xz) tar xvJf "$1" ;;
    *.tar.zst) tar --zstd -xvf "$1" ;;
    *) tar xvf "$1" ;;
  esac
}

_extract_stream() {
  case "$1" in
    *.bz2) bunzip2 "$1" ;;
    *.gz) gunzip "$1" ;;
    *.Z) uncompress "$1" ;;
    *.zst) unzstd "$1" ;;
    *.xz) unxz "$1" ;;
    *) lz4 -d "$1" ;;
  esac
}

_extract_archive() {
  case "$1" in
    *.rar) unrar x "$1" ;;
    *.zip) unzip "$1" ;;
    *.7z) 7z x "$1" ;;
    *.lha | *.lzh) lha e "$1" ;;
    *.arj) arj x "$1" ;;
    *.arc) arc e "$1" ;;
    *) xdms u "$1" ;;
  esac
}

# _extract_into <flag> <dir>: with `-d <dir>`, create <dir> and cd into it.
_extract_into() {
  [[ "$1" = "-d" ]] && [[ -n "$2" ]] || return 0
  mkdir -p "$2"
  cd "$2" || return 1
}

extract() {
  if [[ -z "$1" ]]; then
    echo "Usage: extract <archive_file>"
    return 1
  fi

  # Initialize log file before first use
  LOG_FILE=${ARCHIVE_LOG_FILE:-"$HOME/.archive_operations.log"}

  if [[ ! -f "$1" ]]; then
    echo "Error: '$1' is not a valid file" | tee -a "$LOG_FILE"
    return 1
  fi

  # Handle filenames with spaces correctly
  local filename="$1"

  # Create extract directory for archives with multiple files
  _extract_into "$2" "$3" || return 1

  case "$filename" in
    *.tar.bz2 | *.tbz2 | *.tar.gz | *.tgz | *.tar.xz | *.tar.zst | *.tar) _extract_tar "$filename" ;;
    *.bz2 | *.gz | *.Z | *.zst | *.xz | *.lz4) _extract_stream "$filename" ;;
    *.rar | *.zip | *.7z | *.lha | *.lzh | *.arj | *.arc | *.dms) _extract_archive "$filename" ;;
    *) echo "Error: '$filename' cannot be extracted - unknown format" | tee -a "$LOG_FILE" && return 1 ;;
  esac

  # Log successful extraction
  # shellcheck disable=SC2181
  if [[ $? -eq 0 ]]; then
    echo "Successfully extracted $filename" | tee -a "$LOG_FILE"
  else
    echo "Failed to extract $filename" | tee -a "$LOG_FILE"
  fi
}

#-----------------------------------------------------------------------------
# List Archive Contents Function
#-----------------------------------------------------------------------------
_list_tar() {
  case "$1" in
    *.tar.bz2 | *.tbz2) tar tjf "$1" ;;
    *.tar.gz | *.tgz) tar tzf "$1" ;;
    *.tar.xz) tar tJf "$1" ;;
    *.tar.zst) tar --zstd -tvf "$1" ;;
    *) tar tf "$1" ;;
  esac
}

_list_archive() {
  case "$1" in
    *.rar) unrar l "$1" ;;
    *.zip) unzip -l "$1" ;;
    *.7z) 7z l "$1" ;;
    *.lha | *.lzh) lha l "$1" ;;
    *) arj l "$1" ;;
  esac
}

list_archive() {
  if [[ -z "$1" ]]; then
    echo "Usage: list_archive <archive_file>"
    return 1
  fi

  if [[ ! -f "$1" ]]; then
    echo "Error: '$1' is not a valid file"
    return 1
  fi

  case "$1" in
    *.tar.bz2 | *.tbz2 | *.tar.gz | *.tgz | *.tar.xz | *.tar.zst | *.tar) _list_tar "$1" ;;
    *.rar | *.zip | *.7z | *.lha | *.lzh | *.arj) _list_archive "$1" ;;
    *) echo "Error: Cannot list contents of '$1' - unknown format" ;;
  esac
}

#-----------------------------------------------------------------------------
# Compress Function with Progress
#-----------------------------------------------------------------------------
# _compress_ext <format>: the default archive suffix; returns 1 for an
# unsupported format.
_compress_ext() {
  case "$1" in
    tar) echo tar ;;
    tgz) echo tar.gz ;;
    tbz2) echo tar.bz2 ;;
    txz) echo tar.xz ;;
    tzst) echo tar.zst ;;
    zip | 7z | gz | bz2 | xz | zst | lz4 | rar) echo "$1" ;;
    *) return 1 ;;
  esac
}

# _compress_stream <tool> <level> <input> <output>: one file through a
# stream compressor, with a pv progress bar when pv is installed.
_compress_stream() {
  if [[ $has_pv -eq 1 ]]; then
    pv "$3" | "$1" "-$2" >"$4"
  else
    "$1" -c "-$2" "$3" >"$4"
  fi
}

# _compress_tar <format> <level> <output> <input>...: the tar formats.
_compress_tar() {
  local format="$1" level="$2" output="$3"
  shift 3
  case "$format" in
    tar) tar -cf "$output" "$@" ;;
    tgz)
      if [[ $has_pv -eq 1 ]] && [[ $# -eq 1 ]] && [[ -f "$1" ]]; then
        pv "$1" | tar -cz -f "$output" -C "$(dirname "$1")" "$(basename "$1")"
      else
        tar -czf "$output" "$@"
      fi
      ;;
    tbz2) tar -cjf "$output" -C "$(dirname "$1")" "$@" ;;
    txz) XZ_OPT="-$level" tar -cJf "$output" "$@" ;;
    *) ZSTD_CLEVEL="$level" tar --zstd -cf "$output" "$@" ;;
  esac
}

# _compress_multi <format> <level> <output> <input>...: the multi-file
# archivers.
_compress_multi() {
  local format="$1" level="$2" output="$3"
  shift 3
  case "$format" in
    zip) zip -r "$output" "$@" "-$level" ;;
    7z) 7z a "-mx=$level" "$output" "$@" ;;
    rar) rar a "-m$level" "$output" "$@" ;;
    *) _compress_tar "$format" "$level" "$output" "$@" ;;
  esac
}

# _compress_tool <format>: the stream compressor for a single-file format;
# returns 1 for the archive formats.
_compress_tool() {
  case "$1" in
    gz) echo gzip ;;
    bz2) echo bzip2 ;;
    xz) echo xz ;;
    zst) echo zstd ;;
    lz4) echo lz4 ;;
    *) return 1 ;;
  esac
}

# Sets compress's first / inputs / output / explicit from its remaining
# arguments: the last one names the output when it does not exist yet.
# No array indexing: this file is sourced into zsh too, whose arrays are
# 1-based, so ${inputs[0]} read as empty and a.txt compressed to ".tar".
_compress_split() {
  local arg last="" n=0
  first="$1"
  for arg in "$@"; do last="$arg"; done
  if [[ "$#" -gt 1 ]] && [[ ! -e "$last" ]]; then
    explicit=1
    output="$last"
    for arg in "$@"; do
      n=$((n + 1))
      if [[ "$n" -lt "$#" ]]; then
        inputs+=("$arg")
      fi
    done
  else
    inputs=("$@")
  fi
}

# _compress_run <format> <level> <first-input> <output>: compress's inputs
# (and has_pv) into <output>, logging the result to $LOG_FILE.
_compress_run() {
  local format="$1" level="$2" first="$3" output="$4" tool
  if ! _compress_ext "$format" >/dev/null; then
    echo "Error: Unsupported format '$format'" | tee -a "$LOG_FILE"
    return 1
  fi
  if tool="$(_compress_tool "$format")"; then
    if [[ ${#inputs[@]} -ne 1 ]] || [[ ! -f "$first" ]]; then
      echo "Error: $tool compression requires a single input file" | tee -a "$LOG_FILE"
      return 1
    fi
    _compress_stream "$tool" "$level" "$first" "$output"
  else
    _compress_multi "$format" "$level" "$output" "${inputs[@]}"
  fi

  # Log result
  # shellcheck disable=SC2181
  if [[ $? -eq 0 ]]; then
    echo "Successfully compressed to $output" | tee -a "$LOG_FILE"
  else
    echo "Failed to compress to $output" | tee -a "$LOG_FILE"
    return 1
  fi
}

compress() {
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Usage: compress <format> <input_files...> [output_file]"
    echo "Formats: tar, tgz, tbz2, txz, tzst, zip, 7z, gz, bz2, xz, zst, lz4, rar"
    echo "Options: -l <1-9> compression level (if supported by format)"
    return 1
  fi

  local format="$1" level=6 first="" output="" explicit=0 ext has_pv=0
  local inputs=()
  shift
  # Check for compression level option
  if [[ "$1" = "-l" ]]; then
    level="$2"
    shift 2
  fi
  _compress_split "$@"
  if [[ "$explicit" -eq 0 ]]; then
    # Default output name based on the first input
    ext="$(_compress_ext "$format")" || {
      echo "Error: Unsupported format '$format'"
      return 1
    }
    output="$first.$ext"
  fi

  # Check if we have pv installed for progress indication
  command -v pv >/dev/null 2>&1 && has_pv=1

  # Log file for operations
  LOG_FILE=${ARCHIVE_LOG_FILE:-"$HOME/.archive_operations.log"}

  echo "Compressing to $output..."
  _compress_run "$format" "$level" "$first" "$output"
}

#-----------------------------------------------------------------------------
# Compress Large Files Function (Preserved for backward compatibility)
#-----------------------------------------------------------------------------
compress_large() {
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Usage: compress_large <format> <input_file> [output_file]"
    echo "Note: Consider using the more powerful 'compress' function instead"
    return 1
  fi

  local format="$1"
  local input="$2"
  local output="${3:-${input}.${format}}"

  if [[ ! -f "$input" ]]; then
    echo "Error: '$input' is not a valid file"
    return 1
  fi

  case "$format" in
    gz) gzip -c "$input" >"$output" ;;
    bz2) bzip2 -c "$input" >"$output" ;;
    xz) xz -c "$input" >"$output" ;;
    zst) zstd -c "$input" >"$output" ;;
    lz4) lz4 -c "$input" >"$output" ;;
    *) echo "Error: Unsupported format '$format'" && return 1 ;;
  esac
  echo "Compressed '$input' to '$output'"
}

#-----------------------------------------------------------------------------
# Quick Backup Function
#-----------------------------------------------------------------------------
backup() {
  local target="$1"
  local format="${2:-tgz}" # Default to tar.gz
  # shellcheck disable=SC2155
  local timestamp=$(date +%Y%m%d-%H%M%S)

  if [[ -z "$target" ]]; then
    echo "Usage: backup <file_or_directory> [format]"
    echo "Available formats: tgz (default), tbz2, txz, tzst, zip, 7z"
    return 1
  fi

  if [[ ! -e "$target" ]]; then
    echo "Error: '$target' does not exist"
    return 1
  fi

  # shellcheck disable=SC2155
  local basename=$(basename "$target")
  local output="${basename}-backup-${timestamp}"

  local ext
  case "$format" in
    tgz) ext=tar.gz ;;
    tbz2) ext=tar.bz2 ;;
    txz) ext=tar.xz ;;
    tzst) ext=tar.zst ;;
    zip | 7z) ext="$format" ;;
    *) echo "Error: Unsupported backup format '$format'" && return 1 ;;
  esac
  compress "$format" "$target" "$output.$ext"

  # shellcheck disable=SC2181
  if [[ $? -eq 0 ]]; then
    echo "Backup created: $output"
  fi
}

#-----------------------------------------------------------------------------
# Aliases
#-----------------------------------------------------------------------------
# Optional interactive cleanup alias (kept in archive bucket by convention).
if [[ "${DOTFILES_SAFE_ALIASES:-0}" == "1" ]]; then
  alias zap='dot_confirm_destructive "rm -vi (zap)" && rm -vi'
fi

# Extract Aliases
alias x='extract' # Extract any supported archive (using universal extract script)

# List Content Aliases
alias l7z='7z l'              # List 7z archive contents
alias ltar='tar -tvf'         # List tar archive contents
alias ltgz='tar -tzvf'        # List tar.gz archive contents
alias ltbz='tar -tjvf'        # List tar.bz2 archive contents
alias ltxz='tar -tJvf'        # List tar.xz archive contents
alias ltzst='tar --zstd -tvf' # List tar.zst archive contents
alias lzip='unzip -l'         # List zip archive contents
if command -v unrar >/dev/null 2>&1; then
  alias lrar='unrar l' # List rar archive contents
fi
alias lar='list_archive' # Generic list archive contents

# 7-Zip Aliases
alias c7z='7z a' # Create 7z archive
alias x7z='7z x' # Extract 7z archive

# Tar Aliases
alias ctar='tar -cvf'         # Create tar archive
alias xtar='tar -xvf'         # Extract tar archive
alias ctgz='tar -zcvf'        # Create tar.gz archive
alias xtgz='tar -zxvf'        # Extract tar.gz archive
alias ctbz='tar -jcvf'        # Create tar.bz2 archive
alias xtbz='tar -jxvf'        # Extract tar.bz2 archive
alias ctxz='tar -Jcvf'        # Create tar.xz archive
alias xtxz='tar -Jxvf'        # Extract tar.xz archive
alias ctzst='tar --zstd -cvf' # Create tar.zst archive
alias xtzst='tar --zstd -xvf' # Extract tar.zst archive

# Zip Aliases
alias czip='zip -r' # Create zip archive
alias xzip='unzip'  # Extract zip archive

# RAR Aliases
if command -v rar >/dev/null 2>&1; then
  alias crar='rar a' # Create rar archive
fi
if command -v unrar >/dev/null 2>&1; then
  alias xrar='unrar x' # Extract rar archive
fi

# Gzip Aliases
alias cgz='gzip -cv' # Compress with gzip
alias xgz='gzip -dv' # Extract gzip

# Bzip2 Aliases
alias cbz='bzip2 -zk' # Compress with bzip2
alias xbz='bzip2 -dk' # Extract bzip2

# XZ Aliases
alias cxz='xz -z' # Compress with xz
alias xxz='xz -d' # Extract xz

# Zstd Aliases
alias czst='zstd -z' # Compress with zstd
alias xzst='zstd -d' # Extract zstd

# LZ4 Aliases
alias clz4='lz4 -zc' # Compress with lz4
alias xlz4='lz4 -dc' # Extract lz4

# Combined Aliases
alias ac='compress'        # Generic compression (Archive Create)
alias acl='compress_large' # Legacy compress_large
alias bak='backup'         # Quick backup function
