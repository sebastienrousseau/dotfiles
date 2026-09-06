<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Security policy

Canonical location for this project's security policy. `.github/SECURITY.md`
is a pointer at this file.

## Supported versions

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x (latest) | :white_check_mark: |
| main branch     | :white_check_mark: |
| older releases  | :x:                |

## Vulnerability severity levels

We classify vulnerabilities using the following severity levels:

| Severity | Description                                      |
| -------- | ------------------------------------------------ |
| Critical | Immediate threat, active exploitation possible   |
| High     | Significant risk, could lead to data exposure    |
| Medium   | Moderate risk, limited impact                    |
| Low      | Minimal risk, informational                      |

## Response SLA

We respond to security issues promptly:

| Severity | Initial response | Resolution target |
| -------- | ---------------- | ----------------- |
| Critical | 24 hours         | 48 hours          |
| High     | 72 hours         | 7 days            |
| Medium   | 5 business days  | 30 days           |
| Low      | 10 business days | 90 days           |

## Security contact

For security-related inquiries:

- **Primary**: GitHub Security Advisories (preferred)
- **Email**: <security@sebastienrousseau.com>

## Encrypted disclosure

For reports that contain PII, exploit chains, or details of internal
infrastructure, encrypt your message to the maintainer's GPG key
before sending.

> **Maintainer action required:** the fingerprint placeholder below
> needs the real value pasted in before this section is useful. The
> scaffold (DISCLOSURE.md, KEY_ROTATION.md, the WKD URL) is in
> place; once the key lands the placeholder gets swapped and the
> closure of #870 is complete.

**Key fingerprint** (verify before encrypting):

```text
55AF AD36 4FD9 DB38 19E6  1F0C 8D68 8FAF A914 4693
```

The same fingerprint without spaces (machine-friendly form):
`55AFAD364FD9DB3819E61F0C8D688FAFA9144693`

**Fetch the public key** via Web Key Directory (WKD):

```sh
gpg --auto-key-locate clear,wkd --locate-keys security@sebastienrousseau.com
```

Cross-verify the same fingerprint against the `signingkey` field in
`dot_config/git/allowed_signers.tmpl`. A mismatch means the key in
your hand isn't the one used to sign releases — stop and contact the
maintainer through GitHub.

Full reporter workflow (encrypt → send → verify acknowledgement) is
in [`docs/security/DISCLOSURE.md`](docs/security/DISCLOSURE.md).
Key rotation policy and history are in
[`docs/security/KEY_ROTATION.md`](docs/security/KEY_ROTATION.md).

## Signing keys

Commits and tags are signed with an SSH ed25519 key published in
[`KEYS.asc`](KEYS.asc), which doubles as a `git allowed_signers` file
and carries a verification guide. The GPG key described above is used
**only** for encrypted vulnerability reports and never signs releases.

Release artefacts carry stronger, CI-generated provenance — sigstore
keyless signatures, SLSA attestations, SHA256SUMS and a CycloneDX
SBOM. See [`pkg/VERIFY.md`](pkg/VERIFY.md) and
[`docs/security/VERIFY_RELEASE.md`](docs/security/VERIFY_RELEASE.md).

## Hardening posture and fuzzing

Architectural posture, the threat model, and the input-parsing fuzzing
story (Go harnesses ported from the shell surfaces, a committed
regression corpus replayed on every push, ClusterFuzzLite on PRs,
OSS-Fuzz pending) are documented in
[`docs/security/THREAT_MODEL.md`](docs/security/THREAT_MODEL.md) and
[`docs/security/FUZZING.md`](docs/security/FUZZING.md).

## Supply chain

Provenance policy, pinning rules, and the allowlists that back them
live in [`supply-chain/`](supply-chain/README.md).

## Reporting a vulnerability

Please use GitHub Security Advisories for private disclosure:

- <https://github.com/sebastienrousseau/dotfiles/security/advisories>

We'll acknowledge reports and provide a fix timeline when possible.

## Responsible disclosure policy

We kindly ask security researchers to:

1. **Report privately** - Use GitHub Security Advisories or email; do not open public issues
2. **Provide details** - Include steps to reproduce, affected versions, and potential impact
3. **Allow time** - Give us reasonable time to address the issue before public disclosure
4. **Act in good faith** - Do not access or modify data that is not yours

We commit to:

1. **Acknowledge** your report within the SLA timeframe
2. **Investigate** and keep you informed of progress
3. **Credit** researchers who follow responsible disclosure (unless anonymity is requested)
4. **Not pursue** legal action against researchers acting in good faith
