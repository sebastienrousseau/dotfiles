<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Container images

**No container image is published, deliberately.**

This project configures a *workstation*: it writes to `$HOME`, manages
shell startup, installs fonts and applies OS defaults. None of that
survives a container boundary in a way that is useful to a user, so a
published `dotfiles` image would be a misleading artefact.

Four Dockerfiles exist in the repository and all four are build or
test infrastructure, not products:

| Dockerfile | Purpose |
|---|---|
| [`../../tests/Dockerfile.test`](../../tests/Dockerfile.test) | CI test baseline |
| [`../../tests/Dockerfile.sandbox`](../../tests/Dockerfile.sandbox) | Fresh-Ubuntu sandbox for integration tests (digest-pinned base) |
| [`../../.devcontainer/Dockerfile`](../../.devcontainer/Dockerfile) | Dev container / Codespaces |
| [`../../fuzz/oss-fuzz/Dockerfile`](../../fuzz/oss-fuzz/Dockerfile) | OSS-Fuzz builder |

To try the framework disposably, use the sandbox the CLI already
provides, which is what `tests/Dockerfile.sandbox` backs:

```sh
dot sandbox
```

If a published image is ever added, it belongs here, with a
digest-pinned base (OpenSSF Scorecard checks that) and an entry in
[`../VERIFY.md`](../VERIFY.md).
