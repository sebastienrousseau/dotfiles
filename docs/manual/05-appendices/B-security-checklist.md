# Appendix B: Security Checklist

Run this checklist after a fresh install and quarterly afterwards.

## Pre-Install

- [ ] Download `install.sh` over HTTPS only
- [ ] Inspect `install.sh` before running (optional, recommended for untrusted environments)
- [ ] Ensure SSH signing key exists and is backed up (`~/.ssh/id_ed25519`)
- [ ] Ensure Age key is backed up if reinstalling (`~/.config/age/keys.txt`)

## Post-Install

- [ ] Run `dot doctor` — expect score ≥90
- [ ] Run `dot verify --security` — all checks pass
- [ ] Verify commit signing: `cd ~/.dotfiles && git verify-commit HEAD`
- [ ] Confirm `~/.ssh/allowed_signers` contains your public key
- [ ] Check that `~/.config/age/keys.txt` permissions are `0600`
- [ ] Run `dot mcp --strict` — policy matches registry

## Ongoing (monthly)

- [ ] `dot upgrade` — pick up security patches
- [ ] `dot verify --security` — confirm no new leaks
- [ ] Review `~/.local/state/dotfiles/mcp-violations.log` — any unexpected entries?
- [ ] Review recent attestations — `ls ~/.local/state/dotfiles/attestation/ | tail -10`
- [ ] Rotate Age key if compromised or as part of scheduled rotation

## Ongoing (quarterly)

- [ ] Rotate SSH signing key
- [ ] Audit `~/.ssh/allowed_signers` — remove former team members
- [ ] Review SOPS recipient list in `.sops.yaml`
- [ ] Run `dot chaos` in a test container — verify heal works
- [ ] Update pinned tool versions in `mise.toml`
- [ ] Run fleet attestation — confirm all hosts aligned

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

1. **Revoke** — remove the host's public key from `~/.ssh/allowed_signers` on all other fleet hosts
2. **Re-encrypt** — `sops updatekeys` with the host excluded from recipients
3. **Attest** — run `dot fleet attest` to verify revocation propagated
4. **Wipe** — if the host is recoverable, `rm -rf ~/.config/age ~/.dotfiles` and reinstall

## Gates Enforced by CI

Every PR to master must pass:

- [x] SSH-signed commits
- [x] Shellcheck zero warnings (severity=error)
- [x] Gitleaks scan
- [x] Detect-secrets baseline diff
- [x] TruffleHog verified scan
- [x] Copyright headers present
- [x] 100% unit test coverage
- [x] Reliability tests (macOS + Ubuntu)
- [x] Checkov infra scan
- [x] Version sync (bumped across all files)

## See Also

- [Trust Model](../01-concepts/02-trust-model.md)
- [Encrypt a Secret tutorial](../02-tutorials/04-encrypt-secret.md)
- [Security Policy](../../security/SECURITY.md)
- [Incident Response Playbook](../../security/INCIDENT_RESPONSE.md)
