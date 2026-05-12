# CI Egress Allowlist

This page documents the network endpoints CI jobs are allowed to
reach when `step-security/harden-runner` is operating in `block`
mode. Managed under
[#878](https://github.com/sebastienrousseau/dotfiles/issues/878).

## Status

All 76 jobs across the 28 workflow files in `.github/workflows/` are
currently in **`audit` mode** — harden-runner is the first step in
every job and records outbound network calls to the
[step-security telemetry dashboard](https://app.stepsecurity.io) but
does not block them.

The next iteration (tracked as a follow-up under #878) flips each
group to `block` once the audit-mode runs confirm the allowlist is
complete. Switching one job at a time keeps blast radius small:
a missing endpoint on a `block`-mode job fails the run loud and the
list below gets updated.

## Allowlist (by domain)

This is the union of endpoints the entire workflow surface needs.
When flipping a specific job to `block` mode, narrow this list to
the endpoints that particular job actually touches.

### GitHub itself (universally required)

| Endpoint | Used by | Why |
|---|---|---|
| `github.com:443` | every job | git clone, gh CLI |
| `api.github.com:443` | every job | gh CLI, issue/PR API |
| `objects.githubusercontent.com:443` | every job | release-asset downloads, LFS objects |
| `*.actions.githubusercontent.com:443` | every job | runner ↔ orchestrator |
| `pkg.actions.githubusercontent.com:443` | every job | action-cache CDN |
| `results-receiver.actions.githubusercontent.com:443` | every job | workflow telemetry |
| `codeload.github.com:443` | jobs that `git clone` tagged refs | tarball downloads for some actions |
| `uploads.github.com:443` | jobs that upload artifacts | `actions/upload-artifact` |
| `raw.githubusercontent.com:443` | the install-script jobs | curl-pull of unversioned content |

### Package managers (apt, brew, cargo, npm, luarocks)

| Endpoint | Used by | Why |
|---|---|---|
| `azure.archive.ubuntu.com:443` | ubuntu jobs running `apt-get` | apt mirror |
| `archive.ubuntu.com:80` | ubuntu jobs running `apt-get` | apt mirror |
| `security.ubuntu.com:80` | ubuntu jobs running `apt-get` | security updates |
| `keyserver.ubuntu.com:443` | jobs that add repo signing keys | GPG keyserver |
| `formulae.brew.sh:443` | macOS jobs running `brew` | Homebrew formula index |
| `ghcr.io:443` + `*.docker.io:443` | docker / container jobs | image pulls |
| `registry.npmjs.org:443` | npm-publish.yml + the pre-commit npm hook | npm metadata + publish |
| `registry-1.docker.io:443` | docker jobs | image manifests |
| `crates.io:443` + `static.crates.io:443` | cargo-install jobs | crate downloads |
| `index.crates.io:443` | cargo-install jobs | crate index |
| `luarocks.org:443` + `*.luarocks.org:443` | reusable-lua-lint.yml | luacheck install |

### Project-specific installers (chezmoi / mise / starship / stylua / typos / etc.)

| Endpoint | Used by | Why |
|---|---|---|
| `get.chezmoi.io:443` | `setup-chezmoi` composite (fallback path) | chezmoi installer |
| `mise.run:443` | `setup-mise` composite | mise installer |
| `releases.starship.rs:443` | mise-managed install of starship | starship binary |

### Security / SBOM / scanning

| Endpoint | Used by | Why |
|---|---|---|
| `api.osv.dev:443` | grype / scorecard | OSV vuln database |
| `vulners.com:443` | grype | vulnerability metadata |
| `toolbox-data.anchore.io:443` | anchore/sbom-action | SBOM tooling |
| `api.deps.dev:443` | future deps.dev integration (#877) | package metadata |
| `api.securityscorecards.dev:443` | scorecard.yml | publish_results upload |
| `*.codeql.github.com:443` | codeql.yml | CodeQL bundle download |

## Job-level egress notes (legitimate broad-egress jobs)

A few jobs need wider network access than the standard allowlist
covers. Each carries an inline comment near the harden-runner step
explaining the deviation so reviewers can audit at a glance.

### `update-deps.yml` — broad GitHub API egress

Polls multiple `github.com/<repo>/releases/latest` endpoints to find
new tool versions. Allowlist needs to include `api.github.com:443`
and the raw-content domain for sed-replacing version strings.

### `devcontainer-prebuild.yml` — registry push

Pushes to `ghcr.io:443` with the `packages: write` token. The egress
allowlist for that job is the standard set plus `ghcr.io` writes.

### `nightly.yml` — `Beta/Nightly Tools Test` job

This job deliberately runs `curl ... | tar -xJf -` against the
shellcheck release. Justified because the job is `continue-on-error: true`
and is opt-in (manual or scheduled). Future hardening: download the
release asset, verify a known hash, then exec — same shape as
`scripts/ci/install-chezmoi-verified.sh`.

## Updating this page

Whenever a job is flipped to `block` mode:

1. Run the audit-mode workflow at least once after every recent
   workflow change to make sure the harden-runner telemetry reflects
   reality.
2. Visit the [step-security dashboard](https://app.stepsecurity.io/)
   filtered to the repo + job + last 7 days.
3. Add any endpoints the dashboard reports that aren't already in
   this page's tables.
4. Edit the job to set `egress-policy: block` and add the per-job
   `allowed-endpoints:` block listing only what that specific job
   needs (not the whole union).
5. Land the change, watch the first run; if anything fails the run
   loud, add the missing endpoint and retry.

## References

- `step-security/harden-runner` — [https://github.com/step-security/harden-runner](https://github.com/step-security/harden-runner)
- `docs/security/SCORECARD.md` — Token-Permissions check ties to harden-runner adoption.
- Issue [#878](https://github.com/sebastienrousseau/dotfiles/issues/878).
