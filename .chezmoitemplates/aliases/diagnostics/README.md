# Diagnostics Aliases

Tools for self-healing and system health checks.

## Health & Repair

| Alias | Description |
|-------|-------------|
| `doc`, `dot-doctor` | Run the system health check script (`doctor.sh`). |
| `drift`, `dot-drift` | Verify drift against the source (`chezmoi verify`). |
| `heal`, `dot-heal` | Apply the managed state to repair drift (`chezmoi apply`). |
| `doc-full` | Run doctor with extended path debugging info. |

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
