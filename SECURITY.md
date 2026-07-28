# Security Policy

Thank you for helping keep this project secure. This file is the
canonical GitHub-discoverable entry point; the full security
documentation lives under [`docs/security/`](docs/security/).

## Reporting a vulnerability

**Preferred — [GitHub Security Advisories][gh-adv].** Private,
audited, and integrates with the maintainer's triage workflow.

**Alternative — encrypted email** to
[`security@sebastienrousseau.com`](mailto:security@sebastienrousseau.com)
using the maintainer's PGP key. Fetch the public key via WKD:

```sh
gpg --auto-key-locate clear,wkd --locate-keys security@sebastienrousseau.com
```

Or download it from
[`docs/security/security-pubkey.asc`](docs/security/security-pubkey.asc).
Full disclosure workflow — including message-format guidance and
what *not* to include in a report — is in
[`docs/security/DISCLOSURE.md`](docs/security/DISCLOSURE.md).

**Do not** open a public issue for security reports. Do not disclose
the vulnerability on social media, Discord, or other public forums
before the maintainer has had a reasonable opportunity to respond.

## Supported versions

The latest `0.2.x` release line receives security fixes. Older
releases are supported on a best-effort basis until an
end-of-life notice is published (see
[`docs/security/POLICY_RELEASES.md`](docs/security/POLICY_RELEASES.md)).

## Response expectations

| Phase | Target |
|---|---|
| Acknowledgement | 48 hours |
| Initial triage + severity assessment | 5 business days |
| Fix + coordinated disclosure | 30 days for critical / high, 90 days for medium / low |

Deviations from these targets are documented in the eventual
advisory when they occur.

## Further reading

- [Threat model](docs/security/THREAT_MODEL.md)
- [Incident response](docs/security/INCIDENT_RESPONSE.md)
- [Security checklist](docs/security/SECURITY_CHECKLIST.md)
- [Compliance overview](docs/security/COMPLIANCE.md)
- [Key rotation](docs/security/KEY_ROTATION.md)
- [Install verification](docs/security/INSTALL_VERIFICATION.md)

Additional operational security documents (audit-bypass, egress
allowlist, secrets, encryption, fuzzing, MCP policy, verification &
validation) also live under [`docs/security/`](docs/security/).

[gh-adv]: https://github.com/sebastienrousseau/dotfiles/security/advisories/new
