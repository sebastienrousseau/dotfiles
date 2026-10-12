# Global Code Repositories Standard & Conventions

Mandatory across all repositories from `https://github.com/sebastienrousseau` and all portfolio workspaces under `~/Code` (`Public/`, `Private/`, `Work/`, `Forks/`).

The authoritative sources of truth are:
- [`/Users/seb/Code/AGENTS.md`](/Users/seb/Code/AGENTS.md) — Code Repositories Standard
- [`/Users/seb/Code/PR-TEMPLATE.md`](/Users/seb/Code/PR-TEMPLATE.md) — Pull Request Specification
- [`/Users/seb/Code/README-TEMPLATE.md`](/Users/seb/Code/README-TEMPLATE.md) — Canonical README Standard
- [`/Users/seb/Code/REPO-STANDARD.md`](/Users/seb/Code/REPO-STANDARD.md) — Repository Gold Standard

Agents MUST read the nearest repository `AGENTS.md` and consult these master files before modifying any code.

---

## Handover Commands & Script Execution Policy

All commands that the user needs to run MUST ALWAYS be provided as a self-contained executable script located at `/tmp/<repo-name>/<script-name>.sh` (for example, for a repo named `pain001`, the script will be created at `/tmp/pain001/<script-name>.sh`). Never output raw or multiline terminal command blocks directly in chat for copy-pasting. Handover commands MUST ALWAYS be presented as a single execution command working from any directory: `zsh /tmp/<repo-name>/<script-name>.sh`.
