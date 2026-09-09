<!--
  Role:     Personal, cross-project Claude Code preferences.
  Deployed: ~/.claude/CLAUDE.md (via chezmoi — the dot_claude/ source prefix
            strips to .claude/ on apply).
  Audience: Claude Code, when it operates in ANY working directory on this
            machine. Applies to every project you work on.

  Distinct from:
    - CLAUDE.md       (repo root) — instructions scoped to THIS repo only.
    - docs/OPENCODE.md         — the OpenCode CLI equivalent of the above.

  Keep this file terse — style and tooling preferences only. Anything
  project-specific belongs in that project's own CLAUDE.md, not here.
-->

# Personal Claude Code Preferences

## Style

- Concise responses, no filler
- Use conventional commits
- Shell: 2-space indent, set -euo pipefail
- Lua: stylua formatting

## Handing over commands

Whenever I need to run shell steps myself (signed-commit flows
where your Bash tool can't reach my ssh-agent, interactive
prompts, anything destructive that needs my eyes first), hand
them over as ONE runnable script FILE that I can invoke by path
— never a fenced copy-paste block, never scattered one-liners.

- Write the script to disk: `.git/<name>.sh` for repo-local
  work, or another path outside the working tree.
- `chmod +x` it so I can run it directly: `./.git/<name>.sh`.
- Shebang `#!/usr/bin/env bash`, first line of body
  `set -euo pipefail`.
- Quote heredocs (`<<'EOF'`) so commit messages don't
  interpolate.
- Normalise cwd up front: `cd "$(git rev-parse --show-toplevel)"`
  (or an explicit absolute path).
- Multi-phase work goes in one script with labelled sections,
  not multiple scripts I have to chain.
- After the script, one line on what it does and what to tell
  you next.

A fenced ```bash block in chat is NOT a script — it's a
copy-paste instruction. Write the file.

Applies to every project, not just the one this preference was
captured in.

## Tools

- Package manager: mise (not asdf, not nvm)
- Shell: zsh (primary), fish, bash
- Editor: Neovim with lazy.nvim
- Dotfiles: chezmoi-managed

## Working discipline

Read every instruction — mine, a repo's, or a skill's — as **conditions,
not quotas**.

- **Conditions, not quotas.** "Add a test when behaviour changes" is not
  "always add N tests". Don't inflate work to hit a number; a rule whose
  triggering condition isn't present doesn't fire.
- **No manufactured urgency.** Caps / "MUST" / "NEVER" mark a hard gate,
  not a demand to over-act. Satisfy the gate; don't escalate unrelated
  behaviour because a nearby instruction shouted.
- **Autonomy on minor decisions.** For reversible, low-stakes choices that
  follow from the task, decide and proceed — note the choice, don't stop to
  ask. Reserve questions for ambiguous or irreversible forks.
- **Coverage-first for reviews.** When reviewing or auditing, report
  everything with a confidence/severity tag and let a later step filter —
  don't self-censor mid-pass to hit a "top N" shape.

**Anti-rationalization — before declaring anything done, check honestly:**

- Red flags that mean "not done": "it compiles / typechecks" (necessary,
  not sufficient); "it looks right" (reading a diff is not running it); a
  test that passes but was never seen to fail first; "green on my machine"
  without the full gate; a benchmark delta within noise cited as a win.
- Rationalizations to reject: "this edge case won't happen" (test it or
  document why it can't); "I'll add the test in a follow-up" (same commit,
  or it didn't happen); "the linter is wrong here" (justify a specific
  inline suppression, never a blanket one); "close enough" on a claimed
  equivalence (prove it, don't assert it).
- Verification is a step, not a vibe: state what you did to verify and what
  you observed; if you skipped a step, say so.

## Destructive git operations

Rewriting or discarding history is **never** a routine tool call. This applies
to every repository, not just the one where it was learned.

Covered: `rebase` (incl. `--signoff`, `--autosquash`), `push --force` /
`--force-with-lease`, `reset --hard`, `stash pop`/`drop`, `checkout --`,
`clean -fd`, `commit --amend` on anything already pushed, branch deletion.

- **Check the precondition, then the postcondition.** Before: does the path
  exist exactly as spelled, and did the previous command actually succeed?
  After: verify the invariant that matters — `%G?` for signatures, file
  contents for edits, `git stash list` for stashes — **before pushing**, not
  after being asked.
- **A rebase does not preserve signatures.** It rewrites every commit and
  re-signs only if `commit.gpgsign` is set. Never assume it survived; check
  `git log --format='%G?'` on the rewritten range.
- **One branch at a time.** Never batch a force-push across several branches.
- **Never chain a destructive command after an unverified one.** `set -e`
  semantics do not carry across separate tool calls; a failed `stash push`
  still lets the following `stash pop` run, and it will pop something else.
- **Prefer the non-destructive form**: `revert` over `reset --hard`; a fresh
  branch over rewriting a pushed one; `git stash list` before any `pop`.
- **Idempotence is not free.** A replacement script run twice can corrupt data.
  Revert to a known-clean state, confirm the revert actually happened, then
  apply once.
- **Recovery**: `git reflog` and the hash printed by a dropped stash
  (`git stash store <sha>`) can undo most of this — but only if the mistake is
  noticed, which is why the postcondition check is the rule that matters.

The failure mode to watch for: treating one of these as ordinary, and letting
the next step proceed as though the previous had succeeded. The damage usually
looks fine at the time and surfaces much later.
