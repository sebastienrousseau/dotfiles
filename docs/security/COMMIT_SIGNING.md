# Commit Signing — Policy & Setup

Every commit that reaches `main` in this repository must carry a
cryptographic signature that GitHub can verify. The policy is enforced
in three independent layers, so a single bypass does not break the
chain. This document explains the policy, walks through SSH and GPG
setup, and lists the verification commands you can run locally before
pushing.

## Why

Closes [#853](https://github.com/sebastienrousseau/dotfiles/issues/853).
Local hooks alone are bypassable: `git push --no-verify` skips the
pre-push hook, and a clone that never ran `scripts/git-hooks/install.sh`
has no hook at all. GitHub-side enforcement closes that gap.
`DOTFILES_ALLOW_UNSKIPPED_PUSH=1` is not one of these escape hatches:
it skips only the reliability audit, never the signature check (see
[AUDIT_BYPASS.md](AUDIT_BYPASS.md)).

## Enforcement layers

1. **Local pre-push hook**: `scripts/git-hooks/pre-push` runs
   `git verify-commit` against every commit in the push range. A
   single unverified commit aborts the push. It is installed per
   clone by `scripts/git-hooks/install.sh`, and the global
   `~/.config/git/hooks/pre-push` chains to it. `--no-verify` skips
   this layer, and `pre-commit install --hook-type pre-push` replaces
   it; the next two catch it.
2. **GitHub branch protection**: the classic branch protection on
   `main` has **Require signed commits** enabled, with
   `enforce_admins` on, so GitHub refuses an unsigned commit on
   `main`, including an admin's. This is live repository
   configuration set through the GitHub settings or API, not applied
   from a file in this repository. Read it with
   `gh api repos/sebastienrousseau/dotfiles/branches/main/protection`.
3. **`compliance-guard.yml` workflow**: its `Verify Commit Signatures`
   job runs on every PR targeting `main`. It walks the commit range
   with `git verify-commit`, marks unsigned commits in the PR summary,
   and fails when `unsigned_count > 0`. It is not a required status
   check, so layer 2 is what blocks the merge.

A merge to `main` therefore requires a signature GitHub verifies
(layer 2), whatever happened locally. The protection holds even if a
contributor's local hooks are missing or skipped.

`.github/rulesets/main.json` encodes a stricter `main` ruleset
(including `required_signatures`), but it is **not applied**: the only
active ruleset blocks deletion and force-push on the default branch.
See [`.github/BRANCH_PROTECTION.md`](../../.github/BRANCH_PROTECTION.md)
for the live settings.

## Setting up SSH signing (recommended)

SSH signing is the 2026 default. It reuses your existing SSH key —
no new key material, no GPG agent, no Kleopatra UI. GitHub has
recognised SSH signatures since [2022](https://github.blog/changelog/2022-08-23-ssh-commit-verification-now-supported/).

```sh
# 1. Tell git to sign with SSH.
git config --global gpg.format ssh

# 2. Point at the SSH key you want git to use.
git config --global user.signingkey "$HOME/.ssh/id_ed25519.pub"

# 3. Turn on auto-signing for every commit and tag.
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# 4. Tell GitHub which SSH key signs your commits.
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(hostname) signing"

# 5. (Optional) Populate the allowed_signers file so
#    `git log --show-signature` can verify locally.
mkdir -p "$HOME/.config/git"
echo "$(git config user.email) $(cat ~/.ssh/id_ed25519.pub)" \
  > "$HOME/.config/git/allowed_signers"
git config --global gpg.ssh.allowedSignersFile \
  "$HOME/.config/git/allowed_signers"
```

After this, `git log --show-signature` shows `Good "git" signature
for you@example.com with ED25519 key SHA256:…` on every new commit.

## Setting up GPG signing (legacy / for tag-signing mirrors that don't yet support SSH)

```sh
# 1. Generate or import a key. ED25519 is the modern recommendation;
#    RSA-4096 is the conservative fallback.
gpg --quick-generate-key "Your Name <you@example.com>" ed25519 sign 2y

# 2. Find the long key ID.
gpg --list-secret-keys --keyid-format=long

# 3. Tell git which key.
git config --global user.signingkey <LONG_KEY_ID>
git config --global commit.gpgsign true

# 4. Export and upload the public key to GitHub.
gpg --armor --export <LONG_KEY_ID> | gh gpg-key add -
```

## Verifying locally before pushing

```sh
# Every commit in the push range.
git log "$(git merge-base @{u} HEAD)..HEAD" \
  --pretty='%H %G? %s' \
  | awk '$2 != "G" {print "UNSIGNED:", $0}'

# Or the canonical command the pre-push hook uses:
for c in $(git rev-list "$(git merge-base @{u} HEAD)..HEAD"); do
  git verify-commit "$c" >/dev/null 2>&1 \
    && echo "✓ $c" \
    || echo "✗ $c — unsigned, will be rejected by main branch protection"
done
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `error: gpg failed to sign the data` | gpg-agent isn't running, or `GPG_TTY` not exported | `export GPG_TTY=$(tty)` in your shell rc; restart agent with `gpgconf --kill gpg-agent` |
| `error: Load key "/.../id_ed25519": Permission denied` | SSH key permissions too open | `chmod 600 ~/.ssh/id_ed25519` |
| GitHub shows "Unverified" on a commit signed locally | Signing key not uploaded to GitHub | `gh ssh-key add … --type signing` (SSH) or `gh gpg-key add` (GPG) |
| Pre-push hook rejects a merge commit you didn't author | Upstream commit lacks a signature | Either pull the rebased branch, or fast-forward instead of merging |

## References

- `gh api repos/sebastienrousseau/dotfiles/branches/main/protection`:
  the live, enforced policy.
- `.github/workflows/compliance-guard.yml` — the workflow that
  fails PRs containing unsigned commits.
- `scripts/git-hooks/pre-push` — the local pre-push gate.
- `.github/rulesets/main.json`: a ruleset draft that is not applied
  (see [`.github/BRANCH_PROTECTION.md`](../../.github/BRANCH_PROTECTION.md)).
- [GitHub: About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [GitHub: Telling Git about your SSH key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
