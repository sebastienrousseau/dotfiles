# Documentation

Start here. Then go deeper.

## The Manual

The complete reference is the `.dotfiles` Manual — a multi-format book covering every concept, tutorial, reference, and recipe.

- Online: <https://sebastienrousseau.github.io/dotfiles/manual/> (HTML, PDF, EPUB, ASCII)
- Locally: `dot manual` opens the HTML in your browser
- Sources: [`docs/manual/`](manual/)

Quick jumps into the Manual:

- [Introduction](manual/00-introduction.md) — who, what, how
- [Concepts](manual/01-concepts/) — architecture, trust model, theme engine, fleet, self-healing
- [Tutorials](manual/02-tutorials/) — first install, wallpaper→theme, profiles, secrets, fleet
- [Reference](manual/03-reference/) — CLI, config files, environment, templates, feature flags
- [Cookbook](manual/04-cookbook/) — 40+ recipes, troubleshooting, FAQ

## Start

- [Install](guides/INSTALL.md)
- [Troubleshooting](guides/TROUBLESHOOTING.md)
- [Support matrix](reference/SUPPORT_MATRIX.md)

## Daily use

- [Utilities and `dot` CLI](reference/UTILS.md)
- [Operations](operations/OPERATIONS.md)
- [Trusted agent workstation](operations/TRUSTED_AGENT_WORKSTATION.md)
- [Workstation attestation](operations/ATTESTATION.md)
- [Interoperability](architecture/INTEROP.md)
- [Agent interoperability](interop/A2A.md)
- [AI integrations](AI.md)

## Security and trust

- [Security overview](security/SECURITY.md)
- [Security checklist](security/SECURITY_CHECKLIST.md)
- [Policy bundle releases](security/POLICY_RELEASES.md)
- [Secrets](security/SECRETS.md)
- [Compliance](security/COMPLIANCE.md)
- [Threat model](security/THREAT_MODEL.md)

## Build and maintain

- [Testing](operations/TESTING.md)
- [Reliability](operations/RELIABILITY.md)
- [Naming conventions](NAMING_CONVENTIONS.md)
- [Architecture](architecture/ARCHITECTURE.md)
- [Repository layout](architecture/REPO_LAYOUT.md)
- [Architecture decisions](adr/README.md)

## Repository map

| Path | Purpose |
| :--- | :--- |
| `docs/` | Guides, reference, security, and architecture |
| `scripts/` | Repo-only scripts and `dot` command internals |
| `install/` | Installer and provisioning helpers |
| `dot_config/` | Managed user configuration files |
| `dot_local/` | Managed local executables |
| `examples/` | Executable examples |
| `tests/` | Unit, integration, and framework coverage |

## Platform guides

- [WSL2 and Nix](guides/WSL2_NIX_TROUBLESHOOTING.md)
- [Neovim IDE](guides/NEOVIM_IDE_GUIDE.md)

## Reference

- [Features](reference/FEATURES.md)
- [Tools](reference/TOOLS.md)
- [Aliases](reference/ALIASES.md)
- [Roadmap](operations/ROADMAP.md)
- [Version sync](operations/VERSION_SYNC.md)
