#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.

# 10-secrets.sh: Optional secret bucket auto-loader
# Loads configured secret buckets into the current shell via `dot env load`.

if [[ "${DOTFILES_SECRETS_AUTO_LOAD:-0}" != "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

if ! command -v dot >/dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

_dot_secret_buckets=()
if [[ -n "${DOTFILES_SECRETS_BUCKET_NAMES:-}" ]]; then
  while IFS= read -r _bucket; do
    [[ -n "$_bucket" ]] || continue
    _dot_secret_buckets+=("$_bucket")
  done < <(printf '%s' "${DOTFILES_SECRETS_BUCKET_NAMES}" | tr ',' '\n')
fi

for _bucket in "${_dot_secret_buckets[@]}"; do
  [[ -n "$_bucket" ]] || continue
  _dot_secret_out="$(dot env load "$_bucket" 2>/dev/null || true)"
  [[ -n "$_dot_secret_out" ]] || continue
  case "$_dot_secret_out" in
    export\ * | typeset\ * | unset\ *)
      # Use process substitution instead of eval for safety
      # shellcheck disable=SC1090
      . /dev/stdin <<<"$_dot_secret_out"
      ;;
    *)
      # Ignore non-shell output
      ;;
  esac
  unset _dot_secret_out
done

unset _dot_secret_buckets _bucket
