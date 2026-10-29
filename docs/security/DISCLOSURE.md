# Encrypted Security Disclosure — Reporter Workflow

This document is for **external security researchers** who have found
an issue in this repository and want to report it without exposing
sensitive details (PII, exploit chains, internal infrastructure) in
transit or at rest on third-party servers.

If your report doesn't need encryption, please use
[GitHub Security Advisories](https://github.com/sebastienrousseau/dotfiles/security/advisories)
instead — it's faster and the GitHub-side audit trail is stronger.

## 1. Fetch the maintainer's public key

The key is committed to this repository as
[`docs/security/security-pubkey.asc`](security-pubkey.asc):

```sh
curl -fsSL \
  https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/docs/security/security-pubkey.asc \
  | gpg --import
```

It is also served by Web Key Directory (WKD):

```sh
gpg --auto-key-locate clear,wkd \
    --locate-keys security@sebastienrousseau.com
```

If WKD lookup fails (corporate proxy, old gpg), fetch the WKD URL
directly:

```sh
curl -fsSL \
  https://sebastienrousseau.com/.well-known/openpgpkey/hu/t5s8ztdbon8yzntexy6oz5y48etqsnbb \
  | gpg --import
```

The `verify-gpg-wkd.yml` workflow checks that the in-repo key, the WKD
key and the fingerprint pinned in `SECURITY.md` all agree.

## 2. Verify the fingerprint

**Do not skip this step.** A MITM attacker can serve their own key.

```sh
gpg --fingerprint security@sebastienrousseau.com
```

The fingerprint must match the one published in
[`SECURITY.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/SECURITY.md):
`55AF AD36 4FD9 DB38 19E6  1F0C 8D68 8FAF A914 4693`. This GPG key is
used only for encrypted reports; commits are signed with separate SSH
keys, so there is no SSH fingerprint to compare it with.

If the fingerprints don't match, **stop**. Open a private
[Security Advisory](https://github.com/sebastienrousseau/dotfiles/security/advisories/new)
and ask the maintainer to confirm the key out-of-band.

## 3. Encrypt your report

```sh
cat <<EOF | gpg --encrypt --armor \
  --recipient security@sebastienrousseau.com \
  --output disclosure.asc
Subject: <short description of the issue>

<full details — repro steps, affected versions, exploit, screenshots
referenced by base64-encoded attachments, contact info for follow-up>
EOF
```

Verify the output is an ASCII-armored OpenPGP message before sending:

```sh
head -1 disclosure.asc
# Expected: -----BEGIN PGP MESSAGE-----
```

## 4. Send

Attach `disclosure.asc` to an email to
**<security@sebastienrousseau.com>**.

Subject line: `[dotfiles] <severity>: <short description>` (no
encryption-sensitive content in the subject; mail relays log
subjects in plain text).

## 5. Acknowledgement

You should receive an acknowledgement within the SLA in
[`SECURITY.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/SECURITY.md):

| Severity | Initial response |
|---|---|
| Critical | 24 hours |
| High | 72 hours |
| Medium | 5 business days |
| Low | 10 business days |

The acknowledgement will be signed with the same key you encrypted
to. Verify the signature:

```sh
gpg --verify response.asc
```

If you don't receive an acknowledgement in the SLA window, or the
acknowledgement signature doesn't verify, escalate by:

1. Opening a private GitHub Security Advisory.
2. DM-ing the maintainer on Mastodon: `@sebastienrousseau@hachyderm.io`.

## 6. After disclosure

The maintainer commits to:

- A fix timeline communicated within the SLA.
- A CVE assignment when severity ≥ Medium and the issue affects
  published releases (npm package, release tarballs).
- Public credit at fix time in the release notes (unless you
  request anonymity at report time).
- A backport to any actively-supported release line listed in
  `SECURITY.md`.

## What NOT to do

- Don't post details in a public issue, even a "I found a bug, ping
  me for details" placeholder — every public reference is a tip-off
  to attackers monitoring the repo.
- Don't disclose to third parties (other dotfile maintainers,
  security mailing lists, blog posts) before the embargo lifts.
- Don't access data or systems you don't own.
- Don't run automated scans against `*.sebastienrousseau.com` that
  exceed normal browser-like traffic.

## See also

- [`SECURITY.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/SECURITY.md) — policy
  overview + fingerprint.
- [`docs/security/KEY_ROTATION.md`](KEY_ROTATION.md) — schedule for
  when the disclosure key is rotated.
- [`docs/security/AUDIT_BYPASS.md`](AUDIT_BYPASS.md) — separate flow
  for the pre-push audit bypass (not for disclosure).
