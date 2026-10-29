---
render_with_liquid: false
---

# Appendix B: Security Checklist

Run this checklist after a fresh install and quarterly afterwards.

## Pre-Install

- [ ] Download `install.sh` over HTTPS only
- [ ] Inspect `install.sh` before running (optional, recommended for untrusted environments)
- [ ] Ensure SSH signing key exists and is backed up (`~/.ssh/id_ed25519`)
- [ ] Ensure the age keys are backed up if reinstalling (`~/.config/chezmoi/key.txt` for chezmoi, `~/.config/sops/age/keys.txt` for SOPS)

## Post-Install

- [ ] Run `dot doctor`: no failed checks
- [ ] Run `dot doctor score show`: review the Health, Security and Performance scores (each out of 100)
- [ ] Run `dot secret check` and `dot security score show`: all checks pass
- [ ] Verify commit signing: `cd ~/.dotfiles && git verify-commit HEAD`
- [ ] Confirm `~/.config/git/allowed_signers` contains your public key
- [ ] Check that `~/.config/chezmoi/key.txt` and `~/.config/sops/age/keys.txt` permissions are `0600`
- [ ] Run `dot mcp check --strict`: policy matches registry

## Ongoing (monthly)

- [ ] `dot system update` — pick up security patches
- [ ] `dot secret check`: confirm no new leaks
- [ ] `dot attest verify`: the current attestation passes the verifier (needs `wasmtime`); the last one written is `~/.local/state/dotfiles/attestations/workstation-attestation.json`
- [ ] Rotate Age key if compromised or as part of scheduled rotation

## Ongoing (quarterly)

- [ ] Rotate SSH signing key
- [ ] Audit `~/.config/git/allowed_signers` (source: `defaults/dot_config/git/allowed_signers.tmpl`): remove former team members
- [ ] Review SOPS recipient list in `.sops.yaml`
- [ ] Run the chaos test (`bash scripts/ops/chaos.sh --force`) in a test container, then `dot doctor fix`: verify heal works
- [ ] Update pinned tool versions in `mise.toml`
- [ ] Run `dot attest show --fleet-store <store>` on every host and `dot fleet status`: confirm all hosts aligned

## Incident Response

If a secret leak is detected:

1. **Contain** — remove from history, force-push

   ```sh
   git filter-repo --path <file> --invert-paths
   git push --force
   ```

2. **Rotate** — change the leaked secret upstream (Stripe key, SSH key, etc.)
3. **Audit** — check who/what had access
4. **Notify** — inform affected parties if required

If a host is compromised:

1. **Revoke**: remove the host's public key from `defaults/dot_config/git/allowed_signers.tmpl`, push the change, and run `dot fleet apply --cmd 'dot config update'` so every other host drops it from `~/.config/git/allowed_signers`
2. **Re-encrypt** — `sops updatekeys` with the host excluded from recipients
3. **Attest**: run `dot attest show --fleet-store <store>` on the remaining hosts to verify revocation propagated
4. **Wipe**: if the host is recoverable, `rm -rf ~/.config/chezmoi ~/.config/sops/age ~/.dotfiles` and reinstall

## Gates Enforced by CI

The `main` branch ruleset requires these checks on every PR:

- [x] **Merge Gate** (`ci-enforced.yml`): shellcheck and shfmt, Lua and Nix lint,
  copyright headers, Gitleaks, dependency audit, Checkov infra scan, the
  security policy script, the macOS and Ubuntu test matrix, unit tests with
  100% executable module mapping, the tests-run-the-code lint, install pins,
  the complexity ratchet and mutation testing
- [x] **Reliability Summary** (`reliability-gate.yml`): reliability tests on macOS and Ubuntu
- [x] **Pre-Commit** (`pre-commit.yml`)
- [x] **Check sign-off** (`dco.yml`): every commit carries `Signed-off-by`
- [x] **Verify PR description signature** (`pr-signature.yml`)
- [ ] 100% measured line and branch coverage (current ratchet is documented in `docs/operations/COVERAGE.md`)

Other workflows (TruffleHog in `ci.yml`, version sync in `sync-versions.yml`)
run on PRs but do not block a merge. Detect-secrets runs as a local
pre-commit hook.

## See Also

- [Trust Model](../01-concepts/02-trust-model.md)
- [Encrypt a Secret tutorial](../02-tutorials/04-encrypt-secret.md)
- [Security Policy](../../security/SECURITY.md)
- [Incident Response Playbook](../../security/INCIDENT_RESPONSE.md)
