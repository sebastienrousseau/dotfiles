---
name: OpenSSF Scorecard regression / sub-10 check
about: Track a Scorecard check below 10/10
title: '[scorecard] <Check>: <score>/10 — <one-line summary>'
labels: ['type:security', 'priority:medium', 'scorecard']
assignees: 'sebastienrousseau'
---

## Check

<!-- Which Scorecard check is affected? See https://github.com/ossf/scorecard/blob/main/docs/checks.md -->

- **Name**: <e.g. Branch-Protection / Signed-Releases / Fuzzing>
- **Current score**: <0-10 or -1>
- **Previous score**: <or N/A if first time>

## Evidence

Live dashboard: <https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/dotfiles>

```text
<paste the relevant Scorecard JSON output for this check, including the .reason field>
```

## Root cause

<!-- What's actually causing the sub-10 score? -->

## Plan

- [ ] <step 1>
- [ ] <step 2>
- [ ] Re-run Scorecard via `gh workflow run scorecard.yml --ref master`
- [ ] Verify dashboard reflects the fix
- [ ] Update `docs/security/SCORECARD.md` "Closed this cycle" table

## Exception path (if not fixable)

<!-- If the score is structurally low (e.g. Contributors=0 for a solo
     project), document the rationale here and add an entry to the
     Exceptions table in docs/security/SCORECARD.md with an expiry date. -->

- [ ] Add entry to `docs/security/SCORECARD.md` § Exceptions
- [ ] Comment on the Code Scanning alert via the UI with the dismissal reason

## References

- `docs/security/SCORECARD.md` — current posture + closed-this-cycle log.
- `docs/operations/ROADMAP_V0_2_503.md` workstream G — driving aggregate score targets.
- [Scorecard check definition](https://github.com/ossf/scorecard/blob/main/docs/checks.md)
