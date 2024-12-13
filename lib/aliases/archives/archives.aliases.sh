#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: archives.aliases.sh
# Version: 0.2.469
# Author: @wwdseb
# Copyright (c) 2015-2025. All rights reserved
# Description:
#   This script defines aliases for common archive operations. It provides
#   shortcuts for compressing and extracting various types of archive files.
# Website: https://dotfiles.io
# License: MIT
################################################################################

# 🅰🆁🅲🅷🅸🆅🅴🆂 🅰🅻🅸🅰🆂🅴🆂

## Check for existence of archive programs
if type 7z &> /dev/null; then
  alias compress_7z='7z a'
  alias extract_7z='7z x'
fi

if type tar &> /dev/null; then
  alias compress_tar='tar -cvf'
  alias extract_tar='tar -xvf'
  alias compress_tar_gzip='tar -zcvf'
  alias extract_tar_gzip='tar -zxvf'
  alias compress_tar_bzip2='tar -cvjf'
  alias extract_tar_bzip2='tar -xvjf'
fi

if type jar &> /dev/null; then
  alias compress_jar='jar -cvf'
  alias extract_jar='jar -xvf'
fi

if type xz &> /dev/null; then
  alias compress_xz='tar -cvJf'
  alias extract_xz='tar -xvJf'
fi

if type zip &> /dev/null; then
  alias compress_zip='zip -r'
  alias extract_zip='unzip'
fi

if type zstd &> /dev/null; then
  alias compress_zstd='zstd -zcvf'
  alias extract_zstd='zstd -zxvf'
fi

if type gzip &> /dev/null; then
  alias compress_gzip='gzip -cv'
  alias extract_gzip='gzip -dv'
fi

if type bzip2 &> /dev/null; then
  alias compress_bzip2='bzip2 -zkvf'
  alias extract_bzip2='bzip2 -dkvf'
fi

if type lzop &> /dev/null; then
  alias compress_lzop='lzop -cv'
  alias extract_lzop='lzop -dv'
fi

if type lz4 &> /dev/null; then
  alias compress_lz4='lz4 -zcv'
  alias extract_lz4='lz4 -dcv'
fi

if type pigz &> /dev/null; then
  alias compress_pigz='pigz -zkvf'
  alias extract_pigz='pigz -dkvf'
fi

# 🅳🅴🅵🅴🅽🆂🅸🆅🅴 🅲🅾🅳🅸🅽🅶

# Ensure valid arguments are passed
function compress_file() {
  local archive_type="$1"
  case "${archive_type}" in
    7z|tar|jar|xz|zip|zstd|gzip|bzip2|lzop|lz4|pigz)
      alias "compress_${archive_type}" "${archive_type} -cvf"
      ;;
    *)
      echo "Unsupported archive type: ${archive_type}"
      return 1
      ;;
  esac
}

function extract_file() {
  local archive_type="$1"
  case "${archive_type}" in
    7z|tar|jar|xz|zip|zstd|gzip|bzip2|lzop|lz4|pigz)
      alias "extract_${archive_type}" "${archive_type} -xvf"
      ;;
    *)
      echo "Unsupported archive type: ${archive_type}"
      return 1
      ;;
  esac
}

# Handle large files by piping outputs
function compress_large_file() {
  local archive_type="$1"
  case "${archive_type}" in
    7z|tar|jar|xz|zip|zstd|gzip|bzip2|lzop|lz4|pigz)
      alias "compress_${archive_type}" "${archive_type} -cvf -"
      ;;
    *)
      echo "Unsupported archive type: ${archive_type}"
      return 1
      ;;
  esac
}

function extract_large_file() {
  local archive_type="$1"
  case "${archive_type}" in
    7z|tar|jar|xz|zip|zstd|gzip|bzip2|lzop|lz4|pigz)
      alias "extract_${archive_type}" "${archive_type} -xvf -"
      ;;
    *)
      echo "Unsupported archive type: ${archive_type}"
      return 1
      ;;
  esac
}

# 🅿🅾🆁🆃🅰🅱🅸🅻🅸🆃🆈

function set_alias() {
  local program="$1"
  local flags="$2"
  # shellcheck disable=SC2250,SC2139
  alias "compress_$program"="${program} ${flags}"

}

# Set better defaults in case archive programs are missing
set_alias compress_bz2 bzip2 '-zkvf'
set_alias compress_lz4 lz4 '-zcv'
set_alias compress_lzma xz '-zcvf'
set_alias compress_lzo lzop '-cv'
set_alias compress_pgz pigz '-zkvf'
set_alias compress_tbz2 tar '-cvjf'
set_alias compress_tgz tar '--use-compress-program=pigz -cvf'
set_alias compress_tgz tar '-zcvf'
set_alias compress_tlzo tar '--lzip -cvf'
set_alias compress_txz tar '-cvJf'
set_alias compress_tzst tar '--zstd -cvf'
set_alias compress_zlib gzip '-cv'
set_alias compress_zstd zstd '-zcvf'
