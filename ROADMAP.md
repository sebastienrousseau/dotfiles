# Roadmap

This roadmap describes the direction of the project. It is intentionally
high-level; concrete, dated work is tracked in
[GitHub Issues](https://github.com/sebastienrousseau/dotfiles/issues) and
[Milestones](https://github.com/sebastienrousseau/dotfiles/milestones), and
shipped changes are recorded in [`CHANGELOG.md`](CHANGELOG.md). Versioning
follows [SemVer](https://semver.org/) with the source of truth in
`.chezmoidata.toml`.

## Now (current series — 0.2.x)

- **Cross-platform parity** — keep macOS, Linux, WSL, and PowerShell 7.5+
  behaviour aligned across the shell, aliases, and `dot` CLI.
- **AI fleet (`dot ai`)** — the cockpit, the local Claude gateway, and fleet
  curation (see [`docs/AI.md`](docs/AI.md)).
- **Supply-chain hardening** — signed commits and release tags, Cosign/SLSA
  provenance, SBOMs, pinned and monitored dependencies, and continuous
  static/dynamic analysis (CodeQL, ClusterFuzzLite).

## Next

- **OpenSSF Best Practices — silver tier.** Close the remaining gaps that are
  in the project's control (reproducible-build attestation, broader coverage).
  Some silver criteria (≥2 maintainers / two-person review, ≥80% statement
  coverage) require a co-maintainer and a sustained coverage push; see the
  badge at [project 12840](https://www.bestpractices.dev/projects/12840).
- **Test coverage** — continue raising measured shell coverage from the current
  documented floor (see [`docs/operations/COVERAGE.md`](docs/operations/COVERAGE.md)).
- **Documentation** — keep the reference manual (`docs/manual/`) and guides in
  step with the shipping surface.

## Later / under consideration

- A second maintainer to unlock independent review and a higher bus factor.
- Containerised integration runs to exercise the system-mutation surface.

## How to influence the roadmap

Open or comment on a
[GitHub Issue](https://github.com/sebastienrousseau/dotfiles/issues), or start a
discussion. Contributions are welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md).
