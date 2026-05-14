# GitHub Rulesets (as code)

This directory holds Rulesets configuration in the format consumed by
the [GitHub Rulesets REST API](https://docs.github.com/en/rest/repos/rules)
so branch protection lives in version control and is reproducible.

## Files

- [`master.json`](master.json) — protection ruleset for the `master`
  branch. Required status checks include the two summary gates added
  under [#857](https://github.com/sebastienrousseau/dotfiles/issues/857):
  `Compliance Summary` and `Reliability Summary`. Signed commits,
  linear history, fast-forward block, deletion block, and 1-reviewer
  PR rule are all encoded.

## Apply

```bash
# First-time creation:
gh api -X POST repos/sebastienrousseau/dotfiles/rulesets \
  --input .github/rulesets/master.json

# Subsequent updates (replace <id> with the ruleset ID returned by the
# create call or visible at /repos/<owner>/<repo>/rulesets):
gh api -X PUT repos/sebastienrousseau/dotfiles/rulesets/<id> \
  --input .github/rulesets/master.json
```

After applying, verify the required-status-checks list matches the JSON
via:

```bash
gh api repos/sebastienrousseau/dotfiles/rulesets/<id> | jq '.rules[]'
```

## Why a separate file from `branch-protection-config.json`

The sibling `../branch-protection-config.json` is the *descriptive*
record (human-readable, comments allowed, narrative `additional_enforcement`
section). This `master.json` is the *machine* spec — a strict subset of
the GitHub Rulesets API contract. Keeping them separate avoids
ambiguity about which one is canonical for `gh api` calls.

## Related

- [#857](https://github.com/sebastienrousseau/dotfiles/issues/857) — promote `Compliance Summary` + `Reliability Summary` to required checks.
- [#853](https://github.com/sebastienrousseau/dotfiles/issues/853) — Rulesets-as-code for signed commits (this file already encodes it).
- `../branch-protection-config.json` — descriptive record.
