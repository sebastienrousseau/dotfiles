<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Support

Where to go, in order. Most questions are answered faster by the first
two rows than by opening an issue.

| I want to… | Go to |
|---|---|
| Understand a command | `dot help <command>`, `man dot`, or the [command index](docs/manual/command-index.md) |
| Read the manual | <https://doc.dotfiles.io/> (source in [`docs/manual/`](docs/manual/)) |
| Diagnose a broken environment | `dot doctor`, then `dot health` |
| Fix something myself | [`docs/guides/TROUBLESHOOTING.md`](docs/guides/TROUBLESHOOTING.md) |
| Ask a question | [GitHub Discussions](https://github.com/sebastienrousseau/dotfiles/discussions) |
| Report a bug | [Open an issue](https://github.com/sebastienrousseau/dotfiles/issues/new/choose) |
| Report a vulnerability | **Not an issue** — see [`SECURITY.md`](SECURITY.md) |
| Contribute a change | [`CONTRIBUTING.md`](CONTRIBUTING.md), then [`DEVELOPMENT.md`](DEVELOPMENT.md) |
| Package this for a distro | [`docs/packaging.md`](docs/packaging.md) |
| Migrate from another manager | [`docs/migration/`](docs/migration/) |

## Before you open an issue

Run this and paste the output — it is the single most useful thing you
can include, and it redacts secrets by design:

```bash
dot doctor
dot version
```

For install problems, add the platform and shell (`uname -a`,
`$SHELL --version`) and whether you used `install.sh`, a package
manager, or `make install`.

## What is supported

Support is best-effort from a single maintainer (see
[`GOVERNANCE.md`](GOVERNANCE.md)). The platform, shell, and toolchain
combinations that are actually tested — as opposed to merely expected
to work — are listed in
[`docs/reference/SUPPORT_MATRIX.md`](docs/reference/SUPPORT_MATRIX.md)
and [`docs/MINIMUM-TOOLCHAIN.md`](docs/MINIMUM-TOOLCHAIN.md). A bug on
a combination marked "Community" is welcome, but may be fixed only if
someone on that platform can reproduce and test it.

## Response expectations

| Kind | Expectation |
|---|---|
| Security report | SLA in [`SECURITY.md`](SECURITY.md) — 24 h initial response for Critical |
| Bug with a reproduction | Triaged, no fixed timeline |
| Feature request | Discussed in the issue; see [`ROADMAP.md`](ROADMAP.md) for direction |
| Question | Discussions, best-effort |

There is no paid support and no SLA for anything other than security
reports.
