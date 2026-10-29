---
render_with_liquid: false
---

# Security Release Checklist

Use this checklist before cutting any new release (e.g., `v0.x.x`) to ensure supply-chain integrity.

## 1. Supply Chain & Installer

- [ ] **Pinned Version**: Confirm the default `local version="v…"` in `install.sh` (the `version` it pins `VERSION` to) matches the release tag.
- [ ] **Docs Sync**: Ensure the `README.md` installer URL and SHA-256 point to the new release asset (not `main`); see [INSTALL_VERIFICATION.md](INSTALL_VERIFICATION.md).
- [ ] **Clean Build**: Verify `install.sh` does not curl random scripts from third parties without pinning.
- [ ] **SOUP Register**: Review [SOUP_REGISTER.md](SOUP_REGISTER.md) and confirm all active external components have an owner and validation path.

## 2. Secrets & Leak Prevention

- [ ] **SSH Keys**: Scan `defaults/private_dot_ssh/` to ensure no private keys (`id_rsa`, `id_ed25519`) are committed.
- [ ] **Env Vars**: Check for hardcoded API tokens in `defaults/dot_config/` (use `age` encryption or environment variables instead).
- [ ] **Git History**: Run `gitleaks detect --config config/gitleaks.toml` (or similar) to scan for accidental commits of credentials.

## 3. Platform Safety

- [ ] **WSL Check**: Verify `install.sh` detects WSL and does not try to install systemd services or macOS defaults.
- [ ] **Root usage**: Ensure no script requires `sudo` unnecessarily (Principle of Least Privilege).

## 4. Toolchain

- [ ] **Binary Integrity**: Check that `defaults/dot_local/bin/` scripts are pure shell/executable and match expected checksums (no binary blobs).
- [ ] **Dependency Scan**: Run `npm audit` in `defaults/dot_local/share/dot-mcp/node/` (the root `package.json` has no lockfile, so `npm audit` cannot run there) and `cargo audit` in `lib/wasm-tools/`.

## 5. MCP (Model Context Protocol) Hardening

- [ ] **Launcher Policy**: Verify `dot mcp check` reports only allowlisted launchers (`npx`, `node`, `uvx`, or binaries under `~/.local/share/dot-mcp/`).
- [ ] **Filesystem Scope**: Ensure no MCP server has broad access (`/`, `/home`, `/Users`).
- [ ] **Default Profile**: Confirm only the `strict-local` server set is enabled by default.
- [ ] **Token Validation**: Confirm required API tokens are set (`GITHUB_TOKEN`, `BRAVE_API_KEY`).
- [ ] **Arg Policy**: No wildcard (`*`) or `--unsafe` arguments in MCP server configs.
- [ ] **Env Placeholders**: All `${VAR}` references in MCP config have corresponding environment variables.

Run `dot mcp check --strict --json` to validate all MCP server configurations and capture an audit artifact.

## 6. Release Attestation

- [ ] **SBOM Generation**: Verify `dotfiles-sbom.spdx.json` is generated in release workflow.
- [ ] **Attestation Signing**: Confirm `actions/attest-build-provenance` signs the release artifacts.
- [ ] **Attestation Verification**: Verify with `gh attestation verify <artifact> --repo sebastienrousseau/dotfiles`.
- [ ] **Automation Keying**: Confirm `ACTIONS_BOT_SIGNING_KEY` exists and matches the signer in `defaults/dot_config/git/allowed_signers.tmpl`.

## 7. Final Verification

- [ ] **Docker Test**: Run `tests/test-docker.sh` (builds `tests/Dockerfile.test`) to verify clean install.
- [ ] **Doctor**: Run `dot doctor` locally.
- [ ] **MCP Check**: Run `dot mcp check` to verify MCP configuration.
