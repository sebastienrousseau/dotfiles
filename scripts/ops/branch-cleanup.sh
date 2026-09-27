#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

# Delete branches whose work is already landed, across every git repo under
# a root directory.
#
#   scripts/ops/branch-cleanup.sh                 # dry run (default)
#   APPLY=1 scripts/ops/branch-cleanup.sh         # actually delete
#   ONLY=Rust/hsh scripts/ops/branch-cleanup.sh   # one repo
#   NO_GH=1 scripts/ops/branch-cleanup.sh         # skip the GitHub criterion
#   BRANCH_CLEANUP_ROOT=~/src scripts/ops/branch-cleanup.sh
#
# TWO criteria decide whether a branch is done with:
#
#   1. ancestor    The branch tip is an ancestor of origin/<default>.
#                  Offline and conservative, but BLIND to squash merges: a
#                  squash-merged branch never becomes an ancestor. Across
#                  203 repos this test found 3 of 305 real candidates,
#                  because almost everything here squash-merges.
#
#   2. merged-PR   GitHub says a PR with this head ref was merged AND the
#                  branch tip still equals that PR's headRefOid. The SHA
#                  equality is the safety property: if someone pushed after
#                  the PR merged, the tips differ and the branch is left
#                  alone, because those commits are not in the default
#                  branch. On the run this was written for, that guard
#                  preserved 16 branches a name-only match would have
#                  destroyed.
#
# Branches matching neither are recorded as LEFT with a reason, so "why was
# this not deleted?" is answerable from the manifest rather than re-derived.
#
# Each run writes timestamped artifacts under <root>/.branch-cleanup/ so an
# apply can be diffed against the dry run that preceded it.

ROOT="${BRANCH_CLEANUP_ROOT:-$HOME/Code/Public}"
APPLY="${APPLY:-0}"
ONLY="${ONLY:-}"
NO_GH="${NO_GH:-0}"

# Run paths and artifacts; exits 0 when the root does not exist.
_bc_setup() {
  if [[ ! -d "$ROOT" ]]; then
    printf 'branch-cleanup: root not found: %s\n' "$ROOT" >&2
    printf 'Set BRANCH_CLEANUP_ROOT to the directory holding your repos.\n' >&2
    exit 0
  fi

  MODE=dry
  [[ "$APPLY" == "1" ]] && MODE=apply
  STAMP="$(date +%Y%m%d-%H%M%S)"
  RUNDIR="$ROOT/.branch-cleanup"
  mkdir -p "$RUNDIR"

  LOG="$RUNDIR/$STAMP-$MODE.log"
  MANIFEST="$RUNDIR/$STAMP-$MODE.manifest.tsv"
  RESTORE="$RUNDIR/$STAMP-restore.sh"
  RAW="$(mktemp)"
  PR_TABLE="$(mktemp)"
  trap 'rm -f "$RAW" "$PR_TABLE"' EXIT
  : >"$LOG"
}

#   status  repo  scope   branch  sha  reason
# status: DRY | DEL | FAIL | KEEP | LEFT | SKIP
row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$1" "$2" "$3" "$4" "${5:--}" "${6:--}" >>"$RAW"
}

# Remote deletion has no server-side undo; this file is the only way back,
# so it is written before anything is removed.
_bc_restore_header() {
  {
    echo "#!/usr/bin/env bash"
    echo "# Generated $(date). Undoes $LOG"
    echo "set -uo pipefail"
  } >"$RESTORE"
  chmod +x "$RESTORE"
}

# Never delete these, even when "merged". gh-pages publishes a live site, and
# it is commonly an ancestor of the default branch, so a naive merged filter
# takes the site down.
PROTECTED='^(main|master|develop|dev|trunk|gh-pages|release|stable|production|prod|HEAD)$'

say() { printf '%s\n' "$*" | tee -a "$LOG"; }

del_local=0
del_remote=0
skipped=0
failed=0
left=0

HAVE_GH=0
_bc_detect_gh() {
  if [[ "$NO_GH" != "1" ]] && command -v gh >/dev/null 2>&1 &&
    gh auth status >/dev/null 2>&1; then
    HAVE_GH=1
  fi
}

# _bc_skip <said reason> [<manifest reason>]: record a skipped repo.
_bc_skip() {
  say "SKIP $repo :: $1"
  row SKIP "$repo" - - - "${2:-$1}"
  skipped=$((skipped + 1))
}

# The repo's default branch: origin/HEAD, else what `git remote show` says.
_bc_default_branch() {
  local d
  # `|| true`: with no origin/HEAD, symbolic-ref fails and, under pipefail +
  # errexit, would abort the whole run before the fallback below.
  d="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null |
    sed 's|^origin/||' || true)"
  if [[ -z "$d" ]]; then
    d="$(git remote show origin 2>/dev/null |
      sed -n 's/.*HEAD branch: //p' || true)"
  fi
  printf '%s' "$d"
}

# --- preconditions --------------------------------------------------
# Sets cur and def; returns 1 (after recording why) when the repo is
# skipped.
_bc_preconditions() {
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    _bc_skip "dirty worktree"
    return 1
  fi
  cur="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  if [[ "$cur" == "HEAD" ]]; then
    _bc_skip "detached HEAD"
    return 1
  fi
  if ! git fetch --prune --quiet origin 2>/dev/null; then
    _bc_skip "fetch failed"
    return 1
  fi
  def="$(_bc_default_branch)"
  if [[ -z "$def" ]]; then
    _bc_skip "no default branch"
    return 1
  fi
  if [[ "$cur" != "$def" ]]; then
    _bc_skip "on '$cur', not default '$def'" "on '$cur' not default '$def'"
    return 1
  fi
}

# --- merged-PR table, one API call per repo --------------------------
# A flat "ref<TAB>oid<TAB>num" file rather than an associative array:
# this repo targets bash 3.2 (what macOS ships), where `declare -A` does
# not exist. tests/unit/shell/test_bash32_portability.sh enforces that.
_bc_pr_table() {
  : >"$PR_TABLE"
  [[ "$HAVE_GH" == "1" ]] || return 0
  # gh returns newest first; keep only the first row per head ref.
  gh pr list --state merged --limit 1000 \
    --json headRefName,headRefOid,number \
    --jq '.[] | [.headRefName, .headRefOid, .number] | @tsv' 2>/dev/null |
    awk -F'\t' '!seen[$1]++' >"$PR_TABLE" || true
  say "    (merged PRs with head refs: $(wc -l <"$PR_TABLE" | tr -d ' '))"
}

# decide <scope> <branch> <sha> -> "DELETE <reason>" | "LEAVE <reason>"
decide() {
  local scope="$1" b="$2" sha="$3" ref
  if [[ "$scope" == "local" ]]; then ref="$b"; else ref="origin/$b"; fi
  if git merge-base --is-ancestor "$ref" "origin/$def" 2>/dev/null; then
    echo "DELETE ancestor-of-$def"
    return
  fi
  local hit oid num
  hit="$(awk -F'\t' -v k="$b" '$1 == k { print $2 "\t" $3; exit }' "$PR_TABLE")"
  if [[ -n "$hit" ]]; then
    oid="${hit%%$'\t'*}"
    num="${hit##*$'\t'}"
    if [[ "$sha" == "$oid" ]]; then
      echo "DELETE pr#${num}-merged"
    else
      # Branch moved after its PR merged: later commits are NOT in the
      # default branch, so deleting here would discard them.
      echo "LEAVE moved-since-pr#${num}"
    fi
    return
  fi
  echo "LEAVE not-merged"
}

# _bc_triage <scope> <branch> <sha> <label>: keep protected branches and
# leave undecided ones; sets reason and returns 0 only for a deletion
# candidate.
_bc_triage() {
  local scope="$1" b="$2" sha="$3" label="$4" verdict
  if [[ "$b" =~ $PROTECTED ]]; then
    say "    keep  $label $b (protected)"
    row KEEP "$repo" "$scope" "$b" "$sha" protected
    return 1
  fi
  [[ "$b" == "$def" ]] && return 1
  [[ "$scope" == local && "$b" == "$cur" ]] && return 1
  read -r verdict reason < <(decide "$scope" "$b" "$sha")
  if [[ "$verdict" == "LEAVE" ]]; then
    row LEFT "$repo" "$scope" "$b" "$sha" "$reason"
    left=$((left + 1))
    return 1
  fi
}

# --- local branches --------------------------------------------------
_bc_delete_local() {
  local b="$1" sha="$2"
  if [[ "$sha" != "-" ]]; then
    echo "cd \"$ROOT/$repo\" && git branch -f \"$b\" $sha" >>"$RESTORE"
  fi
  # -D, not -d: a squash-merged branch is not an ancestor, so -d refuses
  # even when the PR that carried it is verifiably merged.
  if git branch -D "$b" >>"$LOG" 2>&1 &&
    ! git show-ref --verify --quiet "refs/heads/$b"; then
    say "    del   local  $b ($reason)"
    row DEL "$repo" local "$b" "$sha" "$reason"
    del_local=$((del_local + 1))
  else
    # Most often the branch is checked out in another worktree; run
    # `git worktree prune` first when those are stale.
    say "    FAIL  local  $b ($reason)"
    row FAIL "$repo" local "$b" "$sha" "$reason"
    failed=$((failed + 1))
  fi
}

_bc_local_branch() {
  local b="$1" sha reason
  sha="$(git rev-parse "$b" 2>/dev/null || echo "-")"
  _bc_triage local "$b" "$sha" "local " || return 0
  if [[ "$APPLY" == "1" ]]; then
    _bc_delete_local "$b" "$sha"
  else
    say "    DRY   local  $b ($reason)"
    row DRY "$repo" local "$b" "$sha" "$reason"
  fi
}

# --- remote branches --------------------------------------------------
_bc_delete_remote() {
  local b="$1" sha="$2"
  if [[ "$sha" != "-" ]]; then
    echo "cd \"$ROOT/$repo\" && git push origin $sha:refs/heads/\"$b\"" \
      >>"$RESTORE"
  fi
  if git push --quiet origin --delete "$b" >>"$LOG" 2>&1; then
    say "    del   origin $b ($reason)"
    row DEL "$repo" origin "$b" "$sha" "$reason"
    del_remote=$((del_remote + 1))
  else
    say "    FAIL  origin $b (push --delete refused; protected?)"
    row FAIL "$repo" origin "$b" "$sha" "$reason"
    failed=$((failed + 1))
  fi
}

_bc_remote_branch() {
  local b="$1" sha reason
  sha="$(git rev-parse "origin/$b" 2>/dev/null || echo "-")"
  _bc_triage origin "$b" "$sha" origin || return 0
  if [[ "$APPLY" == "1" ]]; then
    _bc_delete_remote "$b" "$sha"
  else
    say "    DRY   origin $b ($reason)"
    row DRY "$repo" origin "$b" "$sha" "$reason"
  fi
}

_bc_repo() {
  local b
  repo="${1%/.git}"
  [[ -n "$ONLY" && "$repo" != "$ONLY" ]] && return 0
  cd "$ROOT/$repo" 2>/dev/null || return 0
  if ! git rev-parse --git-dir >/dev/null 2>&1 || ! _bc_preconditions; then
    cd "$ROOT"
    return 0
  fi

  say "=== $repo (default=$def)"
  _bc_pr_table

  while IFS= read -r b; do
    [[ -z "$b" ]] || _bc_local_branch "$b"
  done < <(git branch --format='%(refname:short)' 2>/dev/null)

  while IFS= read -r b; do
    [[ -z "$b" ]] || _bc_remote_branch "$b"
  done < <(git branch -r --format='%(refname:short)' 2>/dev/null |
    grep '^origin/' | sed 's|^origin/||' | grep -v '^HEAD$')

  cd "$ROOT"
}

_bc_summary() {
  say ""
  say "==== APPLY=$APPLY  deleted_local=$del_local  deleted_remote=$del_remote  failed=$failed  left=$left  skipped_repos=$skipped ===="
  say "Log:      $LOG"
  say "Manifest: $MANIFEST"
  if [[ "$APPLY" == "1" ]]; then
    say "Restore:  $RESTORE"
  fi
}

_bc_reconcile() {
  local m prev=""
  for m in "$RUNDIR"/*.manifest.tsv; do
    [[ -e "$m" ]] || continue
    [[ "$m" == "$MANIFEST" ]] && continue
    prev="$m" # glob expands sorted, so the last match is the newest
  done
  if [[ -n "$prev" ]]; then
    say ""
    say "Reconcile against previous run:"
    say "  diff <(cut -f2-4 '$prev') <(cut -f2-4 '$MANIFEST')"
  fi
}

_bc_main() {
  local g
  _bc_setup
  if [[ "$APPLY" == "1" ]]; then
    _bc_restore_header
  fi
  _bc_detect_gh
  say "# run $STAMP mode=$MODE root=$ROOT only=${ONLY:-<all>} gh=$HAVE_GH"

  while IFS= read -r g; do
    _bc_repo "$g"
  done < <(find "$ROOT" -maxdepth 3 -name .git -type d 2>/dev/null |
    sed "s|^$ROOT/||;s|/.git$||")

  # Sorted by identity (repo, scope, branch) and NOT by status, so a row
  # keeps its position when its status changes between runs. Sorting by
  # status made a DRY->FAIL transition read as a delete plus an insert.
  sort -t$'\t' -k2,2 -k3,3 -k4,4 -o "$MANIFEST" "$RAW"

  _bc_summary
  _bc_reconcile
}

_bc_main
exit 0
