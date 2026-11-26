---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# Agent governance (ask / plan / apply / audit)

Agents run under a named profile that bounds what they may do, and
every run leaves evidence:

```bash
dot agent mode list                  # ask / plan / apply / audit
dot agent mode set plan              # switch the active profile
dot agent mode run plan git status   # run one command under a profile, with a checkpoint
dot agent check                      # validate agent-profiles.json and the default
dot agent log                        # tail the session audit log
dot agent checkpoint list            # saved run checkpoints (save / list / show / replay)
dot fleet policy set strict          # advisory → strict RBAC for agent profiles
```

The MCP side is policy-first: `dot mcp check` audits configured
Model Context Protocol servers against
`defaults/dot_config/dotfiles/mcp-policy.json` (allowlist, supply
chain, config), and `dot mcp list` shows the configured servers.
`dot attest export` writes the workstation's version,
platform, signing settings, active profile, and policy hash as
tracked JSON ([`docs/operations/ATTESTATION.md`](../../../docs/operations/ATTESTATION.md)).
The A2A agent card and conformance suite are in
[`docs/interop/A2A.md`](../../../docs/interop/A2A.md); the trust model that
ties signing, secrets, profiles, and attestation together is
[`docs/manual/01-concepts/02-trust-model.md`](../../../docs/manual/01-concepts/02-trust-model.md).
