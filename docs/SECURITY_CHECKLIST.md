# Security Release Checklist

Use this checklist before cutting any new release (e.g., `v0.x.x`) to ensure supply-chain integrity.

## 1. Supply Chain & Installer
- [ ] **Pinned Version**: Update `install.sh` `VERSION` variable to match the release tag.
- [ ] **Docs Sync**: Ensure `README.md` and `.github/PULL_REQUEST_TEMPLATE.md` installer URLs point to the new tag (not `main`).
- [ ] **Clean Build**: Verify `install.sh` does not curl random scripts from third parties without pinning.

## 2. Secrets & Leak Prevention
- [ ] **SSH Keys**: Scan `dot_ssh/` to ensure no private keys (`id_rsa`, `id_ed25519`) are committed.
- [ ] **Env Vars**: Check for hardcoded API tokens in `dot_config/` (use `age` encryption or environment variables instead).
- [ ] **Git History**: Run `git secrets` or similar to scan for accidental commits of credentials.

## 3. Platform Safety
- [ ] **WSL Check**: Verify `install.sh` detects WSL and does not try to install systemd services or macOS defaults.
- [ ] **Root usage**: Ensure no script requires `sudo` unnecessarily (Principle of Least Privilege).

## 4. Toolchain
- [ ] **Binary Integrity**: Check that `dot_local/bin/` scripts are pure shell/executable and match expected checksums (no binary blobs).
- [ ] **Dependency Scan**: Run `npm audit` / `cargo audit` if applicable (currently Node.js legacy is removed).

## 5. MCP (Model Context Protocol) Hardening
- [ ] **Launcher Policy**: Verify `dot mcp` shows only allowlisted launchers (`npx`, `node`, `uvx`).
- [ ] **Filesystem Scope**: Ensure no MCP server has broad access (`/`, `/home`, `/Users`).
- [ ] **Token Validation**: Confirm required API tokens are set (`GITHUB_TOKEN`, `BRAVE_API_KEY`).
- [ ] **Arg Policy**: No wildcard (`*`) or `--unsafe` arguments in MCP server configs.
- [ ] **Env Placeholders**: All `${VAR}` references in MCP config have corresponding environment variables.

Run `dot mcp` to validate all MCP server configurations pass security checks.

## 6. Final Verification
- [ ] **Docker Test**: Run `docker build -f Dockerfile.test .` to verify clean install.
- [ ] **Doctor**: Run `dot doctor` locally.
- [ ] **MCP Check**: Run `dot mcp` to verify MCP configuration.
