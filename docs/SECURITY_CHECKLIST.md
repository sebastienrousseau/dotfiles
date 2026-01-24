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

## 5. Final Verification
- [ ] **Docker Test**: Run `docker build -f Dockerfile.test .` to verify clean install.
- [ ] **Doctor**: Run `dot doctor` locally.
