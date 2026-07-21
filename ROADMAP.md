# Roadmap

This is the canonical roadmap for the dotfiles project. Other roadmap files in
`docs/operations/` and `docs/archive/` are kept only as compatibility stubs and
must link back here rather than carrying separate active plans.

Concrete work is tracked in
[GitHub Issues](https://github.com/sebastienrousseau/dotfiles/issues) and
[Milestones](https://github.com/sebastienrousseau/dotfiles/milestones). Shipped
changes are recorded in [`CHANGELOG.md`](CHANGELOG.md). Versioning follows
[SemVer](https://semver.org/) with `.chezmoidata.toml` as the source of truth.

## Current Series: 0.2.x

The current line is focused on turning a broad personal dotfiles system into a
reliable cross-platform shell distribution.

### Trust

- Keep commits, release tags, SBOMs, and provenance signed and continuously
  verified.
- Expand egress-blocked CI from proven local-only jobs before broader networked
  jobs.
- Maintain MCP policy, lock, registry, server-card, and secret-scanning gates.
- Keep disclosure keys, release identity, DCO, and PR-signature checks enforced.

### Predictability

- Keep macOS, Linux, WSL, and PowerShell 7.5+ behaviour aligned across shell
  startup, aliases, functions, and the `dot` CLI.
- Preserve chezmoi idempotency and dry-run safety for every managed surface.
- Continue pinning external actions, reusable workflows, tool versions, and
  package references where reproducible locks are practical.
- Keep feature flags explicit so advanced desktop, AI, and fleet behaviour stays
  opt-in.

### Observability

- Keep `dot doctor`, `dot health`, `dot drift`, `dot perf`, and reliability
  dashboards as first-class diagnostic surfaces.
- Ratchet measured bash coverage as tests move from source-text assertions to
  branch-driving sandbox execution.
- Keep documentation, examples, traceability, and generated command indexes under
  drift checks.

### AI Fleet

- Keep `dot ai` as the cockpit for Claude, Codex, Copilot, Kimi, Aider,
  OpenCode, Ollama, and related AI CLIs.
- Keep the local Claude gateway scoped per subprocess, never globally exported
  into the interactive shell.
- Track provider-specific install, doctor, routing, and cost behaviours through
  docs, tests, and regression cases.

## Near-Term Priorities

1. **Coverage ratchet** - finish deep branch coverage for the scripts that still
   dominate the denominator, then raise the CI floor in lockstep with measured
   coverage.
2. **Egress hardening** - keep expanding `egress-policy: block` from local-only
   jobs to package-installing jobs once each allowlist is proven by CI logs.
3. **Docs governance** - keep this file as the only active roadmap and enforce
   redirects for historical roadmap paths.
4. **Platform parity** - continue closing Windows-native PowerShell and WSL gaps
   without weakening macOS/Linux behaviour.
5. **Distribution** - keep Homebrew, Scoop, AUR, devcontainer, and install
   surfaces aligned with signed release artifacts.

## Later

- Add a second maintainer to improve review independence and bus factor.
- Add containerized integration runs that can safely exercise system-mutation
  surfaces.
- Add deeper enterprise fleet workflows: attested fleet apply, host inventory,
  policy bundles, and rollback evidence.
- Add richer local observability for shell lifecycle timing and AI-agent runs.

## Historical Roadmaps

These paths are retained for old links only:

| Path | Status |
| --- | --- |
| `docs/operations/ROADMAP.md` | Redirects here |
| `docs/operations/ROADMAP_2026.md` | Historical 2026 audit plan; redirected here |
| `docs/operations/ARCHITECTURE_ROADMAP.md` | Historical architecture plan; redirected here |
| `docs/operations/ROADMAP_V0_2_503.md` | Frozen v0.2.512 plan; redirected here |
| `docs/archive/LEGACY_ROADMAP.md` | Legacy archive; redirected here |

## How To Influence The Roadmap

Open or comment on a
[GitHub Issue](https://github.com/sebastienrousseau/dotfiles/issues), or start a
discussion. Contributions are welcome; see [`CONTRIBUTING.md`](CONTRIBUTING.md).
