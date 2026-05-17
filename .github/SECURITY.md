# Security policy

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
in [`docs/security/DISCLOSURE.md`](../docs/security/DISCLOSURE.md).
Key rotation policy and history are in
[`docs/security/KEY_ROTATION.md`](../docs/security/KEY_ROTATION.md).

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
