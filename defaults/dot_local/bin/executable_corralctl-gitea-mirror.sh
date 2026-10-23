#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Mirror GitHub to the NAS Gitea, exactly.
#
# `corralctl sync` brings a destination to parity with the *local clone*
# (every local branch and tag there, nothing else). Working clones are the
# wrong source for that: they lag origin, hold local-only branches, and lack
# remote-only ones. So this keeps a dedicated mirror tree whose refs/heads
# and refs/tags are a forced, pruned copy of GitHub's, and syncs that.
#
# corralctl creates missing repositories and pushes, but it never forces and
# Gitea refuses to delete a repository's default branch, so on its own it
# cannot converge a Gitea copy that has drifted. sync therefore also points
# each Gitea default branch at GitHub's, force-pushes what still differs
# (logging every overwritten ref), and succeeds only on exact parity.
#
# Layout matches corralctl's: <mirror>/<visibility>/<language>/<repo>.
# corralctl reads a repository's visibility from the <visibility> segment.
#
# Usage: corralctl-gitea-mirror.sh refresh|sync|verify
#   refresh  clone/fetch every GitHub repo of $OWNER into the mirror tree
#   sync     refresh, then converge gitea on the mirror (retried)
#   verify   compare every branch and tag hash, mirror vs gitea
set -euo pipefail

OWNER="${CORRAL_OWNER:-sebastienrousseau}"
GITEA_OWNER="${CORRAL_GITEA_OWNER:-$OWNER}"
MIRROR="${CORRAL_MIRROR_DIR:-$HOME/.local/share/corral-mirror}"
JOBS="${CORRAL_JOBS:-8}"
GITEA_JOBS="${CORRAL_GITEA_JOBS:-4}"
SOURCE_URL="${CORRAL_SOURCE_URL:-https://github.com}"
GITEA_GIT_BASE="${CORRAL_GITEA_GIT_BASE:-git@git.hub:}"
RETRY_SLEEP="${CORRAL_RETRY_SLEEP:-300}"
LIST="$MIRROR/.github-repos.tsv"
export OWNER GITEA_OWNER MIRROR SOURCE_URL GITEA_GIT_BASE LIST

# name<TAB>visibility<TAB>language<TAB>default-branch, one per GitHub repo.
list_github() {
  gh repo list "$OWNER" --limit 2000 --json name,visibility,primaryLanguage,defaultBranchRef \
    --jq '.[] | [.name, (.visibility|ascii_downcase),
                 ((.primaryLanguage.name // "other")|ascii_downcase|gsub(" "; "-")),
                 (.defaultBranchRef.name // "")] | @tsv'
}

repo_dir() { # name -> its mirror clone, if any
  local d
  for d in "$MIRROR"/*/*/"$1"; do [[ -d "$d/.git" ]] && printf '%s\n' "$d"; done
  return 0
}
gitea_url() { printf '%s%s/%s.git\n' "$GITEA_GIT_BASE" "$GITEA_OWNER" "$1"; }
export -f repo_dir gitea_url

mirror_one() {
  local name="$1" vis="$2" lang="$3" dest old
  dest="$MIRROR/$vis/$lang/$name"
  # Visibility or primary language changed on GitHub: move, don't re-clone.
  for old in "$MIRROR"/*/*/"$name"; do
    [[ -d "$old" && "$old" != "$dest" ]] || continue
    mkdir -p "${dest%/*}" && mv "$old" "$dest" && echo "MOVE  $name -> $vis/$lang"
  done
  if [[ ! -d "$dest/.git" ]]; then
    git clone -q --no-checkout "$SOURCE_URL/$OWNER/$name.git" "$dest" ||
      {
        echo "FAIL  $name (clone)"
        return 0
      }
  fi
  git -C "$dest" fetch -q --force --prune --prune-tags --update-head-ok origin \
    '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' ||
    {
      echo "FAIL  $name (fetch)"
      return 0
    }
  echo "OK    $name"
}
export -f mirror_one

cmd_refresh() {
  local list
  mkdir -p "$MIRROR"
  list="$(list_github)"
  [[ -n "$list" ]] || {
    echo "ERROR: empty repository list from GitHub" >&2
    return 1
  }
  printf '%s\n' "$list" >"$LIST"
  # shellcheck disable=SC2016 # $1..$3 expand in the child bash, not here
  cut -f1-3 "$LIST" | tr '\t\n' '\0\0' |
    xargs -0 -r -n3 -P "$JOBS" bash -c 'mirror_one "$1" "$2" "$3"' _ |
    grep -v '^OK ' || true
  prune_gone
  echo "refresh: $(wc -l <"$LIST") GitHub repositories"
}

# Drop mirror entries whose repository no longer exists on GitHub. This only
# touches the mirror cache; the gitea copy is left for a human to decide.
prune_gone() {
  local dir name
  for dir in "$MIRROR"/*/*/*/; do
    [[ -d "$dir.git" ]] || continue
    name="$(basename "$dir")"
    cut -f1 "$LIST" | grep -qxF "$name" && continue
    rm -rf -- "$dir" && echo "GONE  $name (not on GitHub; mirror entry removed, gitea copy kept)"
  done
}

gitea_api() { # method path [json-body]
  local -a body=()
  [[ $# -lt 3 ]] || body=(-H 'Content-Type: application/json' --data "$3")
  # The token goes in through a header file, never argv (visible in ps).
  curl -q -sSf --max-time 30 -X "$1" "${body[@]}" \
    -H @<(printf 'Authorization: token %s\n' "$GITEA_TOKEN") \
    "$GITEA_URL/api/v1/repos/$GITEA_OWNER/$2"
}
export -f gitea_api

# Point the Gitea default branch at GitHub's, pushing it first if Gitea lacks
# it: Gitea will not delete a default branch, so a stale one blocks parity.
align_one() {
  local name="$1" want="$2" dir cur
  [[ -n "$want" ]] || return 0
  dir="$(repo_dir "$name")"
  [[ -n "$dir" ]] || return 0
  cur="$(gitea_api GET "$name" 2>/dev/null | grep -o '"default_branch":"[^"]*"' | cut -d'"' -f4)" || return 0
  [[ -n "$cur" && "$cur" != "$want" ]] || return 0
  git -C "$dir" push -q "$(gitea_url "$name")" "refs/heads/$want:refs/heads/$want" 2>/dev/null || true
  if gitea_api PATCH "$name" "{\"default_branch\":\"$want\"}" >/dev/null; then
    echo "DEFAULT $name $cur -> $want"
  else
    echo "FAIL  $name (default branch $cur -> $want)"
  fi
}
export -f align_one

mirror_refs() { git -C "$1" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags | sort; }

# Gitea's refs for a repo. Fails, rather than answering "no refs", when the
# NAS cannot be read: an empty answer would let force_one push blind and
# leave the old hashes unrecorded.
gitea_refs() {
  local raw
  raw="$(git ls-remote --refs --heads --tags "$(gitea_url "$1")" 2>/dev/null)" || return 1
  [[ -z "$raw" ]] || tr '\t' ' ' <<<"$raw" | sort
}
export -f mirror_refs gitea_refs

# Force the Gitea copy to the mirror's refs. Every overwritten or removed
# ref is logged with its old hash, so the journal is the recovery record.
force_one() {
  local name="$1" dir mine theirs out
  dir="$(repo_dir "$name")"
  [[ -n "$dir" ]] || return 0
  mine="$(mirror_refs "$dir")"
  [[ -n "$mine" ]] || return 0
  theirs="$(gitea_refs "$name")" || {
    echo "FAIL  $name (cannot read gitea refs; not forcing)"
    return 0
  }
  [[ "$mine" == "$theirs" ]] && return 0
  comm -13 <(printf '%s\n' "$mine") <(printf '%s\n' "$theirs") | sed "s/^/FORCE $name was /"
  out="$(git -C "$dir" push -q --force --prune --atomic "$(gitea_url "$name")" \
    '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' 2>&1)" ||
    printf 'FAIL  %s: %s\n' "$name" "${out//$'\n'/ | }"
}
export -f force_one

verify_one() {
  local name="$1" dir mine theirs
  dir="$(repo_dir "$name")"
  [[ -n "$dir" ]] || return 0
  mine="$(mirror_refs "$dir")"
  [[ -n "$mine" ]] || return 0 # empty on GitHub; corralctl skips it too
  theirs="$(gitea_refs "$name")" || theirs="(unreadable)"
  if [[ "$mine" == "$theirs" ]]; then echo "SAME  $name"; else echo "DIFF  $name"; fi
}
export -f verify_one

# The NAS sshd resets connections under load, so gitea-facing steps run with
# less parallelism than the GitHub refresh.
each_repo() { # fn [with-default-branch]
  local fn="$1" cols=1 n=1
  [[ "${2:-}" == default ]] && cols=1,4 && n=2
  # shellcheck disable=SC2016 # $1/$2 expand in the child bash, not here
  cut -f"$cols" "$LIST" | tr '\t\n' '\0\0' |
    xargs -0 -r -n"$n" -P "$GITEA_JOBS" bash -c "$fn"' "$@"' _
}

# corralctl creates missing repositories and pushes what it can; a stale
# default branch makes its atomic push fail, which the next two steps undo.
converge() {
  corralctl sync "$MIRROR" --to "gitea@$GITEA_URL" || true
  each_repo align_one default
  each_repo force_one
  cmd_verify
}

cmd_sync() {
  local attempt
  : "${GITEA_URL:?GITEA_URL must be set (see ~/.config/corral-sync.env)}"
  : "${GITEA_TOKEN:?GITEA_TOKEN must be set (see ~/.config/corral-sync.env)}"
  cmd_refresh
  # The NAS sshd intermittently resets every connection (2026-10-23 04:00:
  # 205/212 kex resets); converging is idempotent, so retry.
  for attempt in 1 2 3; do
    converge && return 0
    [[ $attempt -lt 3 ]] || return 1
    echo "NOTICE: attempt $attempt left gitea short of GitHub; retrying in ${RETRY_SLEEP}s."
    sleep "$RETRY_SLEEP"
  done
}

cmd_verify() {
  local out
  [[ -r "$LIST" ]] || {
    echo "ERROR: no repository list; run refresh first" >&2
    return 1
  }
  out="$(each_repo verify_one | sort)"
  grep '^DIFF' <<<"$out" || true
  echo "verify: $(grep -c '^SAME' <<<"$out" || true) identical, $(grep -c '^DIFF' <<<"$out" || true) different"
  ! grep -q '^DIFF' <<<"$out"
}

case "${1:-}" in
refresh) cmd_refresh ;;
sync) cmd_sync ;;
verify) cmd_verify ;;
*)
  echo "usage: $0 refresh|sync|verify" >&2
  exit 2
  ;;
esac
