# GitHub Rulesets (as code)

This directory holds Rulesets configuration in the format consumed by
the [GitHub Rulesets REST API](https://docs.github.com/en/rest/repos/rules).

> **Not applied.** `main.json` is a draft of a stricter policy. GitHub
> does not enforce it: `main` is protected by classic branch protection
> (five required checks, signed commits, linear history, 0 approvals)
> plus one ruleset that blocks deletion and force-push. See
> [`../BRANCH_PROTECTION.md`](../BRANCH_PROTECTION.md) for the live
> settings and how to read them.

## Files

- [`main.json`](main.json): a draft protection ruleset for the `main`
  branch. It encodes signed commits, linear history, the fast-forward
  and deletion blocks, a one-reviewer code-owner PR rule, and fifteen
  required status checks, including the two summary gates added under
  [#857](https://github.com/sebastienrousseau/dotfiles/issues/857)
  (`Compliance Summary` and `Reliability Summary`).

  Two of those contexts match no job in any workflow:
  `Type Check / Strict Mode`, and `Test / Integration` (the job is
  named `Test / Integration (Docker)`). Applying the file unchanged
  would leave both checks pending and block every merge, so fix the
  list before applying it.

## Apply (once the context list is fixed)

```bash
# First-time creation:
gh api -X POST repos/sebastienrousseau/dotfiles/rulesets \
  --input .github/rulesets/main.json

# Subsequent updates (replace <id> with the ruleset ID returned by the
# create call or visible at /repos/<owner>/<repo>/rulesets):
gh api -X PUT repos/sebastienrousseau/dotfiles/rulesets/<id> \
  --input .github/rulesets/main.json
```

After applying, verify the required-status-checks list matches the JSON
via:

```bash
gh api repos/sebastienrousseau/dotfiles/rulesets/<id> | jq '.rules[]'
```

## Why a separate file from `branch-protection-config.json`

The sibling `../branch-protection-config.json` is the *descriptive*
record (human-readable, narrative `additional_enforcement` section).
It is not applied either, and it carries the same fifteen contexts.
This `main.json` is the *machine* spec, a strict subset of the GitHub
Rulesets API contract.

## Related

- [#857](https://github.com/sebastienrousseau/dotfiles/issues/857): promote `Compliance Summary` + `Reliability Summary` to required checks.
- [#853](https://github.com/sebastienrousseau/dotfiles/issues/853): Rulesets-as-code for signed commits.
- `../branch-protection-config.json`: descriptive record.
