---
render_with_liquid: false
---

# Atuin History Filtering

This page documents how high-risk command patterns are excluded from
Atuin shell history, how to extend the list for your machine, and the
trade-offs of filter design.

## Why

Atuin syncs shell history across machines and exposes a fuzzy-search UI
(`Ctrl-R`). Without a filter, every command — including ones that
contain secrets passed inline (`AWS_SECRET_ACCESS_KEY=...`, `op run`,
`vault read`, `curl -H 'Authorization: Bearer ...'`) — is captured,
synced to a remote service, and made grep-able.

The `history_filter` array in `~/.config/atuin/config.toml` lists
regular expressions that, if matched, prevent Atuin from recording the
command at all (it never enters the local DB, and therefore never
syncs).

## How it ships

Patterns are sourced from `.chezmoidata/secrets-patterns.toml` and
materialised into `~/.config/atuin/config.toml` by the chezmoi template
at `dot_config/atuin/config.toml.tmpl`.

```
.chezmoidata/secrets-patterns.toml
  └── [atuin.history_filter]
        defaults  = [...]      # audited baseline (this repo)
        extra     = [...]      # empty by default; populated per machine

dot_config/atuin/config.toml.tmpl
  └── chezmoi apply  ─────►  ~/.config/atuin/config.toml
```

Run `chezmoi apply ~/.config/atuin/config.toml` after editing the
defaults; `dot doctor` reports the count of deployed patterns and
fails loud if the block is missing.

## What's filtered by default

The audited baseline covers:

- Generic env-var exports: `^export (SECRET|TOKEN|PASSWORD|API_KEY|AWS_)`,
  `^PASSWORD=`, `^[A-Z_]+_TOKEN=`, `^[A-Z_]+_KEY=`.
- Cloud provider auth: `aws ... configure|auth|login`, `gcloud auth ...`,
  `az login`, `kubectl ... --kubeconfig`.
- AI provider keys: Anthropic, OpenAI, Gemini, Mistral.
- SaaS secrets: Stripe, GitHub PAT (`GH_TOKEN`, `GITHUB_TOKEN`), `NPM_TOKEN`,
  `CARGO_REGISTRY_TOKEN`.
- Authorization headers (`curl -H 'Authorization: ...'`).
- Embedded creds in git URLs (`git clone https://user:pass@...`).
- Secret managers: `vault`, `op` (1Password), `chamber`.
- Key material: `ssh-keygen`, `ssh-add`, `gpg --import|--export-secret`,
  `age -d|-e --passphrase`.
- DB connection strings with inline creds
  (`postgres|mysql|mongodb|redis://user:pass@host`).

See `.chezmoidata/secrets-patterns.toml` for the canonical list.

## Adding per-host patterns

Each contributor or machine can extend the list without editing the
shared template. In `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.atuin.history_filter]
extra = [
  "^my-private-tool ",
  "^OUR_CORP_API_KEY=",
  "tailscale up --auth-key=",
]
```

Then re-apply:

```bash
chezmoi apply ~/.config/atuin/config.toml
```

The `extra` patterns are appended to the defaults in the deployed
config.

## Adding a pattern to the project defaults

Edit `.chezmoidata/secrets-patterns.toml` and add a regex to
`[atuin.history_filter].defaults`. Then:

1. Add a fixture command to `tests/unit/secrets/test_atuin_history_filter.sh`
   under `LEAKED_FIXTURES` — your new pattern must catch at least one
   real-shape command.
2. Run the test: `bash tests/unit/secrets/test_atuin_history_filter.sh`.
3. Add a benign-fixture if your regex is broad enough to risk false
   positives.
4. Open a PR; CI runs the same test.

## Trade-offs

`history_filter` is a deny-list. Two classes of failure to design
around:

- **False positives**: an overly broad regex hides commands the user
  needs to recall. Mitigation: every new pattern must include a
  fixture under `BENIGN_FIXTURES` that the regex correctly does *not*
  match.
- **False negatives**: a new secret format ships, no pattern matches,
  the secret lands in history. Mitigation: the OpenSSF Scorecard
  workflow (issue #869) and the nightly drift detector (#875) will
  surface new exposure surfaces; review them quarterly.

`history_filter` does not replace:

- A real secret manager (`age`/`sops`, 1Password, Vault) — see
  `docs/security/ENCRYPTION.md`.
- Pre-commit `gitleaks` / `detect-secrets` scans — see
  `config/pre-commit-config.yaml`.
- Server-side audit logging — see `docs/security/COMPLIANCE.md`.

It's the last line of defence against accidental command-line capture,
not the first.

## References

- Atuin config schema: <https://atuin.sh/docs/config>
- Chezmoi template data: <https://www.chezmoi.io/reference/templates/>
- Issue #872 (this hardening)
- `tests/unit/secrets/test_atuin_history_filter.sh` (pattern-coverage test)
- `scripts/diagnostics/doctor.sh` — "Atuin History Filter" section
