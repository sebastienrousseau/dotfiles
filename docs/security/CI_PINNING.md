---
render_with_liquid: false
---

# CI Dependency Pinning Policy

CI references use two different trust models. They must not be conflated.

1. **Third-party actions** use `owner/action@<40-hex-commit-sha>`.
2. **Third-party reusable workflows** use
   `owner/repository/.github/workflows/file.yml@<40-hex-commit-sha>`.
3. **Reusable workflows in this repository** use
   `./.github/workflows/file.yml`.
4. **Container images and downloaded release binaries** use immutable digests
   or verified SHA256 manifests.

The SLSA generic generator remains the documented exception: its bootstrap
requires a release-tag reference. The corresponding commit is recorded beside
the call site and reviewed whenever the tag changes.

## Why local references are required in this repository

A local reusable-workflow reference is resolved from the same commit as its
caller. Consequently, a pull request that changes
`reusable-shell-lint.yml` executes that changed workflow during the pull
request. An owner/repository reference pinned to an older SHA is immutable,
but it executes stale code and can let a broken or weakened reusable workflow
merge without ever being tested.

```yaml
# Required for a workflow in this repository.
uses: ./.github/workflows/reusable-shell-lint.yml

# Required for a workflow owned by another repository.
uses: example/security-workflows/.github/workflows/audit.yml@b0615f8fb5c0f3826f58904a5567eff11b6c500e
```

The security boundary is therefore:

- same repository: same reviewed commit;
- external repository: immutable reviewed commit.

## Rejected forms

```yaml
# Rejected: bypasses changes to the reusable workflow in the current PR.
uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@b0615f8fb5c0f3826f58904a5567eff11b6c500e

# Rejected: mutable external branch or tag.
uses: example/security-workflows/.github/workflows/audit.yml@main
uses: example/security-workflows/.github/workflows/audit.yml@v1

# Rejected: abbreviated external commit identifier.
uses: example/security-workflows/.github/workflows/audit.yml@b0615f8f
```

## Enforcement

`tools/ci/lint-reusable-pins.sh` validates both parts of the policy. Its name
is retained for compatibility with existing hooks and coverage accounting.
The fixture tests in `tests/unit/ci/test_reusable_pin_lint.sh` prove that:

- local same-repository references pass;
- remote references back to this repository fail, even at a full SHA;
- external full-SHA references pass; and
- mutable or abbreviated external references fail.

Run the policy locally with:

```sh
bash tools/ci/lint-reusable-pins.sh
bash tests/unit/ci/test_reusable_pin_lint.sh
```

## Dependabot

Dependabot continues to update third-party GitHub Actions. Local reusable
workflows are repository source, not dependencies, so they need no pin-bump
automation. Removing that automation also removes its write-capable token and
the former two-PR “change then refresh pins” release cycle.

## References

- [GitHub workflow syntax: reusable workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_iduses)
- [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- `tools/ci/lint-reusable-pins.sh`
- `tests/unit/ci/test_reusable_pin_lint.sh`
