#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/registry.sh; inherits set -euo pipefail
#
# Module content rules for `dot registry install`: a module is third-party
# data, so it may only ship plain files, and nothing about it is executed.
#   * Archive entries are refused when any path component is a name chezmoi
#     acts on: templates render (and `output` runs commands) even during a
#     dry run, scripts run, and exact_/remove_/.chezmoiremove delete files.
#   * The preview is a listing plus `diff -u`, without chezmoi.
#   * The apply runs chezmoi with an empty config and a throwaway state, so
#     the user's hooks, data and script history are never in play.

[[ "${_DOT_REGISTRY_MODULE_LOADED:-0}" == "1" ]] && return 0
_DOT_REGISTRY_MODULE_LOADED=1

## _registry_forbidden_component <path> — print the first component of
## <path> that chezmoi would treat as active content, and succeed; fail when
## every component is a plain name. chezmoi parses these prefixes only in
## first position, so a later private_run_x is just a file called run_x.
_registry_forbidden_component() {
  local component parts=()
  IFS=/ read -r -a parts <<<"$1"
  for component in ${parts[@]+"${parts[@]}"}; do
    case "$component" in
      *.tmpl | .chezmoi* | run_* | exact_* | remove_* | create_* | modify_* | symlink_* | encrypted_* | external_*)
        printf '%s\n' "$component"
        return 0
        ;;
    esac
  done
  return 1
}

## _registry_target_name <component> — the target name chezmoi gives one
## plain source component.
_registry_target_name() {
  local c="${1%.literal}"
  while :; do
    case "$c" in
      private_* | readonly_* | empty_* | executable_*) c="${c#*_}" ;;
      literal_*)
        printf '%s\n' "${c#literal_}"
        return 0
        ;;
      dot_*)
        printf '.%s\n' "${c#dot_}"
        return 0
        ;;
      *)
        printf '%s\n' "$c"
        return 0
        ;;
    esac
  done
}

## _registry_target_path <relative source path> — target path under $HOME.
_registry_target_path() {
  local component out="" parts=()
  IFS=/ read -r -a parts <<<"$1"
  for component in ${parts[@]+"${parts[@]}"}; do
    out="${out:+$out/}$(_registry_target_name "$component")"
  done
  printf '%s\n' "$out"
}

## _registry_module_targets <module root> — "source<TAB>target" per file.
_registry_module_targets() {
  local root="$1" file rel
  while IFS= read -r file; do
    rel="${file#"$root"/}"
    printf '%s\t%s\n' "$rel" "$(_registry_target_path "$rel")"
  done < <(find "$root" -type f | LC_ALL=C sort)
}

## _registry_preview <archive> <module root> — what --yes would change.
_registry_preview() {
  local archive="$1" root="$2" rel target
  ui_section "Module contents"
  tar -tzf "$archive" | _registry_clean_stream
  ui_section "Changes in \$HOME"
  while IFS=$'\t' read -r rel target; do
    if [[ -f "$HOME/$target" ]]; then
      diff -u "$HOME/$target" "$root/$rel" | _registry_clean_stream || true
    else
      printf '  new: ~/%s\n' "$target" | _registry_clean_stream
    fi
  done < <(_registry_module_targets "$root")
}

## _registry_apply <module source> <scratch dir> — apply with no access to
## the user's chezmoi config or state. `--config-format toml` is required:
## chezmoi infers the format from the extension and /dev/null has none.
_registry_apply() {
  chezmoi apply --no-tty --config /dev/null --config-format toml \
    --exclude scripts,externals,encrypted,templates,symlinks,remove \
    --persistent-state "$2/state.boltdb" --cache "$2/cache" \
    --source "$1" --destination "$HOME"
}

## _registry_installed_record <metadata json> <module source> — metadata
## plus `files`: every target path, so removal can delete exactly those.
_registry_installed_record() {
  _registry_module_targets "$2" | cut -f2 |
    jq -R --arg home "$HOME" '$home + "/" + .' |
    jq -s --argjson meta "$1" '$meta + {files: .}'
}
