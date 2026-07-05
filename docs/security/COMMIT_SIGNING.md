# Commit Signing — Policy & Setup

Every commit that reaches `main` in this repository must carry a
cryptographic signature that GitHub can verify. The policy is enforced
in three independent layers, so a single bypass does not break the
chain. This document explains the policy, walks through SSH and GPG
setup, and lists the verification commands you can run locally before
pushing.

## Why

Closes [#853](https://github.com/sebastienrousseau/dotfiles/issues/853).
Local hooks alone are bypassable — `git commit --no-verify`,
`git push --no-verify`, or unsetting `DOTFILES_ALLOW_UNSKIPPED_PUSH`
all let an unsigned commit reach a remote if GitHub-side enforcement
is missing. The chain below removes every escape hatch.

## Enforcement layers

1. **Local commit hook** — `dot_config/git/hooks/executable_commit-msg`
   is deployed by chezmoi. It rejects an unsigned commit at the
   `commit-msg` stage on the developer machine.
2. **Local pre-push hook** — `scripts/git-hooks/pre-push` runs
   `git verify-commit` against every commit in the push range. A
   single unverified commit aborts the push. `--no-verify` skips
   this layer; the next two catch it.
3. **GitHub Rulesets** — `.github/rulesets/main.json` declares
   `required_signatures` on `refs/heads/main`. The rule is part
   of the repo so it's reproducible across forks. Apply with
   `gh ruleset import .github/rulesets/main.json`.
4. **`compliance-guard.yml` workflow** — runs on every PR targeting
   `main`. Walks the commit range with `git verify-commit` and
   marks unsigned commits in the PR summary; fails the workflow
   when `unsigned_count > 0`.

A merge to `main` therefore requires (Ruleset accepts the push) AND
(the workflow's signed-commit check passes) AND (the maintainer's
push key is allowed). The protection holds even if a contributor's
local hooks are missing or skipped.

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
    || echo "✗ $c — unsigned, will be rejected by main ruleset"
done
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `error: gpg failed to sign the data` | gpg-agent isn't running, or `GPG_TTY` not exported | `export GPG_TTY=$(tty)` in your shell rc; restart agent with `gpgconf --kill gpg-agent` |
| `error: Load key "/.../id_ed25519": Permission denied` | SSH key permissions too open | `chmod 600 ~/.ssh/id_ed25519` |
| GitHub shows "Unverified" on a commit signed locally | Signing key not uploaded to GitHub | `gh ssh-key add … --type signing` (SSH) or `gh gpg-key add` (GPG) |
| Pre-push hook rejects a merge commit you didn't author | Upstream commit lacks a signature | Either pull the rebased branch, or fast-forward instead of merging |
| Ruleset import via `gh` complains "invalid JSON" | Rulesets API expects the `target` + `rules` envelope, not just the rules array | Use the file as-is — `gh ruleset import .github/rulesets/main.json` |

## Re-applying the ruleset after a manual edit

If someone edits the ruleset in the GitHub UI by mistake, the
file-of-truth wins. Re-apply:

```sh
gh api -X POST repos/{owner}/{repo}/rulesets \
  --input .github/rulesets/main.json
```

(or `-X PUT` against the existing ruleset's ID if it already exists).

## References

- `.github/rulesets/main.json` — the enforced policy.
- `.github/workflows/compliance-guard.yml` — the workflow that
  fails PRs containing unsigned commits.
- `scripts/git-hooks/pre-push` — the local pre-push gate.
- `dot_config/git/hooks/executable_commit-msg` — the local
  commit-msg gate.
- [GitHub: About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [GitHub: Telling Git about your SSH key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
