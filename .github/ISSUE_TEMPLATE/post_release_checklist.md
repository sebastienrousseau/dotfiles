---
name: Post-release Checklist
about: Verify release hygiene after publishing a version
title: "Post-release: vX.Y.Z checklist"
labels: release, maintenance
assignees: ''
---

## Release

- [ ] Version: `vX.Y.Z`
- [ ] Release notes published and reviewed
- [ ] Tag points to intended commit (`git rev-list -n 1 vX.Y.Z`)
- [ ] Release target is correct (`gh release view vX.Y.Z --json targetCommitish`)

## CI

- [ ] CI passed on release commit
- [ ] Required checks configured and enforced on `master`

## Security/Policy

- [ ] Commit signature policy verified on `master`
- [ ] Force-push disabled on protected branches/rulesets
- [ ] Secret scanning policy validated

## Local Validation

- [ ] `dot apply` completed cleanly
- [ ] Key command smoke checks:
  - [ ] `dot help`
  - [ ] `dot --version`
  - [ ] `dot doctor`

## Notes

Add links to run IDs, release URL, and any follow-up tasks.
