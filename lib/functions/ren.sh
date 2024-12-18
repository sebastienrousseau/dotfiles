#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - File Extension Renamer (ren)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   ren is a utility function to rename file extensions in the current directory.
#   It supports batch renaming with confirmation.
#
# Usage:
#   ren OLD_EXT NEW_EXT
#
# Example:
#   ren txt md           # Rename all .txt files to .md
#
################################################################################

ren() {
    # Check if we have both arguments
    if [[ $# -ne 2 ]]; then
        echo "[ERROR] Usage: ren OLD_EXT NEW_EXT" >&2
        return 1
    fi

    local old_ext="$1"
    local new_ext="$2"
    local count=0

    # First check if any matching files exist
    for file in *."$old_ext"; do
        # Skip if no matches found
        [[ -e "$file" ]] || {
            echo "[WARNING] No files found with extension .$old_ext"
            return 0
        }
        ((count++))
        break
    done

    # Show what we're about to do
    echo "[INFO] Found files with .$old_ext extension. Converting to .$new_ext"
    echo "[INFO] The following files will be renamed:"
    for file in *."$old_ext"; do
        echo "  $file → ${file%."$old_ext"}.$new_ext"
    done

    # Ask for confirmation
    echo -n "Proceed with rename? [y/N] "
    read -r response
    if [[ ! "${response}" =~ ^[Yy]$ ]]; then
        echo "[INFO] Operation cancelled"
        return 0
    fi

    # Perform the rename
    local success=0
    local failed=0
    for file in *."$old_ext"; do
        if mv "$file" "${file%."$old_ext"}.$new_ext"; then
            echo "[SUCCESS] Renamed: $file → ${file%."$old_ext"}.$new_ext"
            ((success++))
        else
            echo "[ERROR] Failed to rename: $file" >&2
            ((failed++))
        fi
    done

    # Show summary
    echo "----------------------------------------"
    echo "[COMPLETE] Successfully renamed: $success, Failed: $failed"
}