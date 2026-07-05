---
title: "Renaming master to main in 2026: A Zero-Downtime Runbook"
description: A supply-chain-safe procedure for renaming the default branch of a mature open-source repository — 96 in-repo edits, a grace-period mirror workflow, zero broken install URLs.
date: 2026-07-05
---

# Renaming `master` to `main` in 2026: A Zero-Downtime Runbook for a Repository at the Heart of an Open-Source Supply Chain

*Renaming the default branch of a mature repository is a supply-chain event, not a cosmetic one; done wrong, it strands `curl \| bash` install commands, breaks CI, and severs external distribution channels.*

*Sebastien Rousseau · Published 5 Jul 2026 · 12 min read*

## Why Default-Branch Naming Matters in 2026 #

Every open-source project with a public install path publishes a URL of the form `raw.githubusercontent.com/<owner>/<repo>/<branch>/install.sh`. Every downstream consumer who has copied that URL — into a README, a Slack message, a devcontainer, a company wiki, a StackOverflow answer, a Homebrew tap, an AUR PKGBUILD, an internal Ansible playbook — has taken an implicit dependency on that branch name. Renaming the branch is a **breaking change to the project's public API surface**, whether the maintainer intended one or not.

The industry moved off `master` as the default branch name years ago; new repositories default to `main`. Existing repositories, however, live with a naming inconsistency that becomes actively confusing when a maintainer has multiple projects — some on `main`, some still on `master`. The migration is unavoidable, but the operational risk profile is significant enough that most maintainers put it off indefinitely.

This article documents the migration of the [.dotfiles](https://github.com/sebastienrousseau/dotfiles) repository — 60+ files with hardcoded branch references, four external distribution channels, three CI providers tracking the default branch, and a public install command bookmarked by an unknown number of downstream users. The migration was **zero-downtime**: no install command broke, no CI job failed, no downstream integration degraded. The blueprint is generalisable to any medium-complexity open-source repository.

## The Branch-Rename 2026 Architecture Lens #

A default-branch rename is not a single operation. It's a sequence of coordinated changes across a defined dependency graph, each with its own migration mechanism:

| Layer | Design Decision | Why It Matters | Risk if Mishandled |
|---|---|---|---|
| **GitHub metadata** | Native rename via Settings → Branches or `POST /repos/{owner}/{repo}/branches/{branch}/rename` | GitHub auto-migrates default-branch setting, open PR targets, branch-protection assignment, ruleset targeting, and Pages source | Renaming via manual `git push :old-name` + `git push new-name` skips the auto-migration and orphans PRs |
| **In-repo workflow triggers** | `.github/workflows/*.yml` `branches:` lists updated pre-rename | Workflows that trigger on `push:` or `pull_request:` targeting the old name silently stop firing after rename | Migration PR itself under-tested — the workflows it edits no longer fire on it |
| **Grace-period mirror** | New workflow fast-forwards `master` from `main` on every push | Preserves `raw.githubusercontent.com/…/master/…` URLs for downstream consumers who cannot be reached | External `curl \| bash` install commands return HTTP 404 the moment `master` ceases to exist |
| **Documentation URIs** | `mkdocs.yml` `edit_uri`, README install commands, docs prose | GitHub redirects `github.com/…/blob/master/…` automatically; `raw.githubusercontent.com/…/master/…` does **not** redirect | Docs site edit buttons point at nonexistent branches; install commands 404 |
| **Rulesets as code** | `.github/rulesets/<branch>.json` file renamed alongside the JSON `target.include` | Machine-readable ruleset files that reference `refs/heads/master` misalign with GitHub's auto-migrated state | Configuration drift between the in-repo policy source of truth and GitHub's live enforcement |
| **Test-suite assertions** | Regression tests that asserted `/master/` URLs in README updated to assert `/main/` | Tests written before rename fail *after* rename in the exact commit that fixes them | Migration PR shows red CI, blocking merge |
| **External distribution** | Homebrew tap, Scoop bucket, AUR PKGBUILD — pinned to release tags, not branches | Version-pinning insulates external distribution from branch renames | Branch-pinned distribution manifests break silently on rename |

## Key Branch-Rename Migration Signals #

| Signal | Operational Benchmark | Reference | Technical Platform Implementation |
|---|---|---|---|
| **URL Reachability Post-Rename** | `HTTP 200` on both `main/install.sh` and `master/install.sh` for the full grace period | External-consumer continuity | Mirror workflow: `on: push: branches: [main]` → `git push origin main:refs/heads/master` |
| **CI Coverage on Migration PR** | Workflow-trigger `branches:` list transitionally includes both `main` and `master` | Migration PR must be tested against the current default | `pull_request: branches: [main, master]` — remove `master` once the mirror retires |
| **In-Repo URL Consistency** | Zero remaining `/master/` URIs on the head branch, excluding intentional mirror-preservation strings | Doc/install correctness | `git grep 'raw.githubusercontent.com/.../master/'` returns empty (or only test-fixture strings) |
| **Ruleset File Alignment** | `.github/rulesets/*.json` filename matches its `target.include` refspec | Config-as-code hygiene | File rename via `git mv` + JSON `target.include` update in the same commit |
| **Grace-Period Retirement Marker** | Calendar-visible tracking item with an explicit sunset date | Operational-debt visibility | GitHub issue with target date in title + calendar event (`.ics` or Google Calendar quick-add URL) |

## Diagnosis: Enumerating the Blast Radius #

Before touching a single file, an authoritative audit surfaces the full inventory of `master` references. On the .dotfiles repository, that surfaced **~88 mechanical replacements across 60 files**, grouped as:

- **24 GitHub Actions workflow files** — trigger lists, `github.ref_name == 'master'` conditionals, `--base master` PR-creating steps, inline `@SHA # master` comments describing what commit was pinned
- **7 `raw.githubusercontent.com/.../master/…` URLs** — README install command, `install.sh` (referencing itself in its own comment header), `bin/dot-bootstrap`, `docs/index.md`, install guide, MkDocs edit_uri, chezmoi-data JSON `$id` field
- **~25 documentation files** — `github.com/…/blob/master/…` references in operations runbooks, security docs, architecture decision records
- **1 ruleset-as-code file** — `.github/rulesets/master.json` with a `target.include: refs/heads/master` field
- **1 regression test** — asserting the README contains `/master/` (a red-team catch: this test PROTECTS against accidental rename, which now needs its assertion inverted)
- **4 legitimately-kept references** — the `gbd` bulk-branch-delete script with a `main|master` whitelist regex, the `git-primary-branch` shell function's fallback path, the release-branch check in `scripts/ops/release.sh`, and Scorecard-linter fixtures demonstrating `@master` as an anti-pattern

## Remediation Sequence #

The rename is executed as a five-phase sequence, each with a distinct commit or GitHub operation:

**Phase 1 — Pre-migration content preparation.** A single pull request rewrites all in-repo `master` references while `master` is still the default branch. This PR must merge before any GitHub-side rename. Workflow `pull_request:` triggers gain `[main, master]` (paired) so the PR itself triggers CI against the current default. The ruleset file is renamed via `git mv` and its JSON target updated. The regression test's assertion is inverted from "must contain `/master/`" to "must contain `/main/`".

**Phase 2 — GitHub-side rename.** Via UI (`Settings → Branches → Rename`) or API (`POST /repos/{owner}/{repo}/branches/master/rename`). GitHub auto-migrates default-branch setting, PR targets, branch-protection assignment, ruleset targeting, Pages source. Blocked if a branch-protection *rule pattern* targeting the new name already exists — delete the empty rule first via GraphQL:

```
gh api graphql -f query='
mutation {
  deleteBranchProtectionRule(input: { branchProtectionRuleId: "..." }) {
    clientMutationId
  }
}'
```

**Phase 3 — Mirror workflow activation.** Trigger the pre-committed mirror workflow via `workflow_dispatch` or a small push to `main`. The workflow performs a fast-forward `git push origin main:refs/heads/master`, recreating `master` as a passive mirror. From this point forward, every push to `main` mirrors automatically.

**Phase 4 — Local clone update (per-workstation).** Every developer with an active clone runs:

```
git branch -m master main
git fetch origin
git branch -u origin/main main
git remote set-head origin -a
```

**Phase 5 — Retirement scheduling.** A GitHub issue with a title-embedded target date (`[2027-07-05] Retire master mirror + tighten workflow triggers to main-only`) plus a calendar reminder ensures the grace-period mirror doesn't become permanent operational debt.

## Verification: URLs, CI, Docs Site #

Post-rename smoke tests:

```
$ curl -sI https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh   | head -1
HTTP/2 200
$ curl -sI https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh | head -1
HTTP/2 200
```

Both branch names resolve during the grace period. When the mirror is retired in 12 months, `/master/` returns 404 by design — but by then no active install command should still reference it.

CI status post-rename: on the .dotfiles repository, the migration PR (`#961`) ran **70 checks green, 0 failed**, driven by the `[main, master]` trigger-list transitional configuration. The follow-up test-coverage PR (`#963`) confirmed no downstream test regression.

Docs site: MkDocs `edit_uri` — updated from `edit/master/docs/` to `edit/main/docs/` — resolves correctly. `github.com/…/blob/master/…` links continue to work via GitHub's built-in redirect; `raw.githubusercontent.com/…/master/…` works via the mirror.

## Return on Resilience #

The commercial value of a supply-chain-safe rename is defensive, not offensive: nothing new is built, but nothing existing breaks.

| Metric | Result |
|---|---|
| Files updated in migration PR | 97 (96 edits + 1 rename + 1 new workflow) |
| Grace-period external URL uptime | 100% (both `/main/` and `/master/` return HTTP 200) |
| CI checks post-rename | 70 green, 0 failed |
| Downstream distribution channels broken | 0 (Homebrew tap, Scoop bucket, AUR pinned to tags) |
| Local-clone update commands | 4 lines, ~5 seconds per workstation |
| Operational debt introduced | 1 mirror workflow, retired via calendar-scheduled task 2027-07-05 |

## Takeaways #

1. **Land the in-repo edits before the GitHub-side rename.** Merging Phase 1 while `master` is still default gives you both a working CI baseline and a rehearsal.

2. **Add the mirror workflow before renaming, not after.** The interval between the GitHub rename and the mirror's first fast-forward push is the window during which `raw.githubusercontent.com/…/master/…` returns 404. Minimising that window is a matter of ordering.

3. **Update `pull_request:` triggers transitionally.** `branches: [main, master]` covers the migration PR itself (which targets the pre-rename default) and every future PR (which will target `main`). The grace-period `master` entry retires with the mirror.

4. **Track retirement as an issue with an explicit sunset date.** Mirror workflows are the classic case of "temporary" becoming "permanent". A calendar event and a GitHub issue with a date-anchored title enforce end-of-life.

5. **Rulesets-as-code files must be renamed alongside their JSON targets.** GitHub auto-migrates the *live* ruleset assignment; the file in your repo is the source-of-truth if you ever reapply. Both must agree.

The reference implementation landed as [PR #961](https://github.com/sebastienrousseau/dotfiles/pull/961) with the retirement issue tracked at [#962](https://github.com/sebastienrousseau/dotfiles/issues/962), shipped in [v0.2.510](https://github.com/sebastienrousseau/dotfiles/releases/tag/v0.2.510).
