#!/usr/bin/env bash
# Provider-agnostic secrets bridge for dotfiles.

set -euo pipefail

DOT_SECRETS_HOME="${DOT_SECRETS_HOME:-$HOME/.config/dotfiles/secrets}"
DOT_SECRETS_STORE_DIR="${DOT_SECRETS_STORE_DIR:-$DOT_SECRETS_HOME/store}"
DOT_SECRETS_INDEX_FILE="${DOT_SECRETS_INDEX_FILE:-$DOT_SECRETS_HOME/index.txt}"
DOT_SECRETS_AGE_KEY="${DOT_SECRETS_AGE_KEY:-$HOME/.config/chezmoi/key.txt}"
DOT_SECRETS_SERVICE_PREFIX="${DOT_SECRETS_SERVICE_PREFIX:-dotfiles.secret}"

dot_secrets_ensure_layout() {
  mkdir -p "$DOT_SECRETS_STORE_DIR"
  touch "$DOT_SECRETS_INDEX_FILE"
  chmod 700 "$DOT_SECRETS_HOME" 2>/dev/null || true
  chmod 700 "$DOT_SECRETS_STORE_DIR" 2>/dev/null || true
  chmod 600 "$DOT_SECRETS_INDEX_FILE" 2>/dev/null || true
}

dot_secrets_provider() {
  local provider="${DOTFILES_SECRETS_PROVIDER:-auto}"
  if [[ "$provider" != "auto" ]]; then
    printf "%s\n" "$provider"
    return 0
  fi

  if [[ "${OSTYPE:-}" == darwin* ]] && command -v security >/dev/null 2>&1; then
    printf "macos-keychain\n"
    return 0
  fi
  if command -v pass >/dev/null 2>&1; then
    printf "pass\n"
    return 0
  fi
  if command -v age >/dev/null 2>&1 && [[ -f "$DOT_SECRETS_AGE_KEY" ]]; then
    printf "plain-enc\n"
    return 0
  fi
  printf "none\n"
}

dot_secrets_index_add() {
  local key="${1:-}"
  [[ -n "$key" ]] || return 1
  dot_secrets_ensure_layout
  if ! grep -qxF "$key" "$DOT_SECRETS_INDEX_FILE" 2>/dev/null; then
    printf "%s\n" "$key" >>"$DOT_SECRETS_INDEX_FILE"
  fi
}

dot_secrets_index_list() {
  dot_secrets_ensure_layout
  awk 'NF > 0' "$DOT_SECRETS_INDEX_FILE" | sort -u
}

dot_secrets_store_macos() {
  local key="$1" value="$2" service="${DOT_SECRETS_SERVICE_PREFIX}.${key}"
  security add-generic-password -U -a "${USER:-dotfiles}" -s "$service" -w "$value" >/dev/null
}

dot_secrets_get_macos() {
  local key="$1" service="${DOT_SECRETS_SERVICE_PREFIX}.${key}"
  security find-generic-password -a "${USER:-dotfiles}" -s "$service" -w 2>/dev/null || return 1
}

dot_secrets_store_pass() {
  local key="$1" value="$2"
  printf "%s\n" "$value" | pass insert -m -f "dotfiles/${key}" >/dev/null
}

dot_secrets_get_pass() {
  local key="$1"
  pass show "dotfiles/${key}" 2>/dev/null | head -n1
}

dot_secrets_store_plain_enc() {
  local key="$1" value="$2"
  local tmp_rec file
  [[ -f "$DOT_SECRETS_AGE_KEY" ]] || {
    echo "age key not found: $DOT_SECRETS_AGE_KEY" >&2
    return 1
  }
  command -v age >/dev/null 2>&1 || {
    echo "age not installed" >&2
    return 1
  }
  command -v age-keygen >/dev/null 2>&1 || {
    echo "age-keygen not installed" >&2
    return 1
  }
  dot_secrets_ensure_layout
  tmp_rec="$(mktemp)"
  file="$DOT_SECRETS_STORE_DIR/${key}.age"
  trap 'rm -f "$tmp_rec"' RETURN
  age-keygen -y "$DOT_SECRETS_AGE_KEY" >"$tmp_rec"
  printf "%s" "$value" | age -R "$tmp_rec" -o "$file"
  chmod 600 "$file" 2>/dev/null || true
}

dot_secrets_get_plain_enc() {
  local key="$1" file="$DOT_SECRETS_STORE_DIR/${key}.age"
  [[ -f "$DOT_SECRETS_AGE_KEY" ]] || return 1
  [[ -f "$file" ]] || return 1
  age -d -i "$DOT_SECRETS_AGE_KEY" "$file" 2>/dev/null || return 1
}

dot_secrets_set() {
  local key="${1:-}" value="${2:-}" provider
  [[ -n "$key" ]] || return 1
  provider="$(dot_secrets_provider)"
  case "$provider" in
    macos-keychain) dot_secrets_store_macos "$key" "$value" ;;
    pass) dot_secrets_store_pass "$key" "$value" ;;
    plain-enc) dot_secrets_store_plain_enc "$key" "$value" ;;
    *)
      echo "No supported secrets provider detected." >&2
      return 1
      ;;
  esac
  dot_secrets_index_add "$key"
}

dot_secrets_get() {
  local key="${1:-}" provider
  [[ -n "$key" ]] || return 1
  provider="$(dot_secrets_provider)"
  case "$provider" in
    macos-keychain) dot_secrets_get_macos "$key" ;;
    pass) dot_secrets_get_pass "$key" ;;
    plain-enc) dot_secrets_get_plain_enc "$key" ;;
    *) return 1 ;;
  esac
}

dot_secrets_bucket_keys() {
  local data_file="${1:-}" bucket="${2:-}"
  [[ -f "$data_file" ]] || return 1
  [[ -n "$bucket" ]] || return 1
  awk -v b="$bucket" '
    $0 ~ "^[[:space:]]*" b "[[:space:]]*=" {
      line=$0
      gsub(/^.*\[/, "", line)
      gsub(/\].*$/, "", line)
      gsub(/"/, "", line)
      n=split(line, arr, ",")
      for (i=1; i<=n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[i])
        if (arr[i] != "") print arr[i]
      }
      exit
    }
  ' "$data_file"
}
