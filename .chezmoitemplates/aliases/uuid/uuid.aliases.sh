# shellcheck shell=bash
# 🆄🆄🅸🅳 🅰🅻🅸🅰🆂🅴🆂

# uuid: Generate a UUID and copy it to the clipboard.
uuid_copy() {
  local value=""
  if command -v uuidgen >/dev/null 2>&1; then
    value="$(uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]')"
  elif command -v uuid >/dev/null 2>&1; then
    value="$(uuid | tr -d '\n' | tr '[:upper:]' '[:lower:]')"
  else
    echo "uuid/uuidgen not available" >&2
    return 1
  fi

  # Clipboard providers by platform:
  # macOS: pbcopy/pbpaste
  # WSL: clip.exe + PowerShell Get-Clipboard
  # Linux Wayland: wl-copy/wl-paste
  # Linux X11: xclip
  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$value" | pbcopy
    if command -v pbpaste >/dev/null 2>&1; then
      pbpaste
    else
      printf "%s\n" "$value"
    fi
    echo
    return 0
  fi

  if command -v clip.exe >/dev/null 2>&1; then
    printf "%s" "$value" | clip.exe
    if command -v powershell.exe >/dev/null 2>&1; then
      powershell.exe -NoProfile -Command "Get-Clipboard" | tr -d '\r'
    else
      printf "%s\n" "$value"
    fi
    return 0
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    printf "%s" "$value" | wl-copy
    if command -v wl-paste >/dev/null 2>&1; then
      wl-paste
    else
      printf "%s\n" "$value"
    fi
    echo
    return 0
  fi

  if command -v xclip >/dev/null 2>&1; then
    printf "%s" "$value" | xclip -selection clipboard
    printf "%s" "$value" | xclip -selection clipboard -o
    echo
    return 0
  fi

  # No clipboard tool found; still return generated UUID.
  printf "%s\n" "$value"
  return 0
}
alias uuid='uuid_copy'
