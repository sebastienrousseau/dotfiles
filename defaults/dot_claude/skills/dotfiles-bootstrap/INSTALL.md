# Installing the `dotfiles-bootstrap` Claude Code skill

This skill ships with the `sebastienrousseau/dotfiles` framework. There are two ways to make it visible to your Claude Code session.

## Option 1 — You already use this framework

If you `chezmoi apply` this repo, the skill auto-deploys to `~/.claude/skills/dotfiles-bootstrap/` (chezmoi's `dot_claude/` source strips to `.claude/` on apply). No further setup needed; the skill appears in `/skills` autocomplete on next Claude Code restart.

## Option 2 — You want the skill without adopting the framework

Drop the skill directory into your global Claude Code skills path:

```bash
mkdir -p ~/.claude/skills
curl -fsSL https://github.com/sebastienrousseau/dotfiles/archive/refs/heads/main.tar.gz \
  | tar -xz -C /tmp
cp -r /tmp/dotfiles-main/dot_claude/skills/dotfiles-bootstrap \
      ~/.claude/skills/
```

You then need `chezmoi` on PATH (the skill calls `dot init`, which calls `chezmoi init`). Install via:

```bash
brew install chezmoi          # macOS, Linuxbrew
sudo snap install chezmoi     # Ubuntu / Debian (snap)
scoop install chezmoi         # Windows (Scoop)
sh -c "$(curl -fsLS get.chezmoi.io)"  # everywhere else (verify the script first)
```

You also need the `dot` dispatcher binary on PATH. The minimum set is `bin/dot` from this repo plus the `scripts/dot/` directory; for the cleanest install run `dot init sebastienrousseau` once, which sets everything up.

## Verifying the skill loaded

```bash
$ claude --print "Run /skills and list every available skill"
# expected output includes:
# - dotfiles-bootstrap — Provision a workstation from a public dotfiles repo
```

If the skill doesn't appear: confirm `~/.claude/skills/dotfiles-bootstrap/SKILL.md` exists and that its front-matter YAML is valid (`yq eval . SKILL.md | head -5`).

## Uninstalling

```bash
rm -rf ~/.claude/skills/dotfiles-bootstrap
```

The skill is stateless — nothing else needs to be cleaned up. The repos and dotfiles it bootstrapped on your behalf are not touched.

## Permissions surface

This skill calls `dot init`, which calls `chezmoi init`, which runs the target repo's `run_onchange_*` scripts with your user's privileges. Treat the target dotfiles repo as untrusted code until you have read it. The `ask` and `audit` profiles default to dry-run / no-apply so you can review before any state mutation.

## Reporting issues

[`github.com/sebastienrousseau/dotfiles/issues`](https://github.com/sebastienrousseau/dotfiles/issues) — tag with `skill:dotfiles-bootstrap`.
