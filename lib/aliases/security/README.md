<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🆂🅴🅲🆄🆁🅸🆃🆈 🅰🅻🅸🅰🆂🅴🆂

This code provides a comprehensive set of aliases and functions for
enhanced security workflows using **OpenSSL**, **GnuPG (GPG)**, **SSH**,
**UFW**, **fail2ban**, **nmap**, and more. It is designed to work across
both **macOS** and **Linux** systems.

> **Important**: You must **source** this script (e.g., `source security.aliases.sh`)
> in your shell to enable the aliases and functions in your current session.

---

### Table of Contents

- [Dotfiles (v0.2.470)](#dotfiles-v02470)
  - [🆂🅴🅲🆄🆁🅸🆃🆈 🅰🅻🅸🅰🆂🅴🆂](#-)
    - [Table of Contents](#table-of-contents)
  - [OpenSSL Aliases](#openssl-aliases)
    - [Basic Commands](#basic-commands)
    - [Certificate Operations](#certificate-operations)
    - [CSR Operations](#csr-operations)
    - [Key Operations](#key-operations)
    - [Conversion Operations](#conversion-operations)
    - [Connection Testing](#connection-testing)
    - [Certificate Verification](#certificate-verification)
    - [Hash and Digest Functions](#hash-and-digest-functions)
    - [Random Generation](#random-generation)
    - [Encryption and Decryption](#encryption-and-decryption)
    - [CA Operations](#ca-operations)
    - [Speed Testing](#speed-testing)
    - [Server Testing and Setup](#server-testing-and-setup)
  - [GPG Aliases](#gpg-aliases)
    - [Key Management](#key-management)
    - [Encryption and Decryption](#encryption-and-decryption-1)
    - [Signing and Verification](#signing-and-verification)
    - [Key Server Operations](#key-server-operations)
    - [Fingerprints and Trust](#fingerprints-and-trust)
    - [Miscellaneous](#miscellaneous)
  - [SSH Aliases](#ssh-aliases)
    - [Key Management](#key-management-1)
    - [Configuration and Connections](#configuration-and-connections)
    - [Tunnels and Forwarding](#tunnels-and-forwarding)
    - [Security Checks](#security-checks)
  - [UFW (Uncomplicated Firewall) Aliases](#ufw-uncomplicated-firewall-aliases)
  - [Cryptographic Tools](#cryptographic-tools)
    - [Hashing Utilities](#hashing-utilities)
    - [Password Generation](#password-generation)
    - [File Encryption](#file-encryption)
  - [Vulnerability Scanning](#vulnerability-scanning)
    - [nmap](#nmap)
    - [lynis](#lynis)
  - [Security Misc (fail2ban)](#security-misc-fail2ban)
  - [Common Workflows](#common-workflows)
    - [Generating Random Data](#generating-random-data)
    - [Checking Certificate Expiration](#checking-certificate-expiration)
    - [Encrypting/Decrypting Files](#encryptingdecrypting-files)
    - [Managing SSH Keys](#managing-ssh-keys)
    - [Quick Firewall Rule Setup](#quick-firewall-rule-setup)
    - [Fail2ban Unban Example](#fail2ban-unban-example)
  - [License](#license)

---

## OpenSSL Aliases

### Basic Commands

- **`ssl`** — Shortcut for `openssl`
- **`sslv`** — Show OpenSSL version
- **`sslhelp`** — Display OpenSSL help

### Certificate Operations

- **`sslx509`** — X.509 certificate utility
- **`sslx509info <cert>`** — Display certificate details
- **`sslx509fp <cert>`** — Show certificate fingerprint
- **`sslx509dates <cert>`** — Show certificate valid dates
- **`sslx509subject <cert>`** — Show certificate subject
- **`sslx509issuer <cert>`** — Show certificate issuer
- **`sslx509check <cert>`** — Check certificate purposes
- **`sslx509extract <cert> <format> <out>`** — Convert certificate format (e.g. PEM to DER)

### CSR Operations

- **`sslreq`** — Alias for `openssl req`
- **`sslreqnew <key_out> <csr_out>`** — Generate new private key and CSR
- **`sslreqinfo <csr_file>`** — View CSR info
- **`sslreqverify <csr_file>`** — Verify CSR integrity

### Key Operations

- **`sslgenrsa <key_file> [size]`** — Generate RSA key (default 2048 bits)
- **`sslgenpkey <algo> <out>`** — Generate private key (e.g. RSA, EC)
- **`sslecparam <curve> <out>`** — Generate EC key with specified curve
- **`sslrsa <rsa_key>`** — Check RSA private key
- **`sslrsainfo <rsa_key>`** — Show RSA key details
- **`sslrsapub <rsa_key> <pub_out>`** — Extract RSA public key
- **`sslpkey <key_file>`** — Generic private key operations

### Conversion Operations

- **`sslpkcs12 <cert> <key> <p12_out>`** — Create PKCS#12 bundle
- **`sslpkcs12extract <p12_file> <out>`** — Extract from PKCS#12
- **`sslpkcs8 <key_in> <key_out>`** — Convert key to PKCS#8 format

### Connection Testing

- **`sslconnect <host> [port]`** — Test SSL/TLS connection
- **`sslconnectsni <host> [port]`** — Connect with SNI
- **`sslciphers <host> <port> <ciphers>`** — Test ciphers
- **`sslshowcerts <host> [port]`** — Show certificates
- **`sslprotocol <host> <port> <protocol>`** — Test with specific TLS/SSL protocol

### Certificate Verification

- **`sslverify <cert>`** — Verify certificate
- **`sslverifycapath <cert>`** — Verify with system CA path
- **`sslcrl <crl_file>`** — Show CRL info

### Hash and Digest Functions

- **`ssldigest <algo> <file>`** — Generate digest (e.g. `sha256`)
- **`sslsha1`**, **`sslsha256`**, **`sslsha384`**, **`sslsha512`** — Hash shortcuts
- **`sslmd5`** — MD5 hash (not recommended)

### Random Generation

- **`sslrand <size>`** — Generate random hex data (default hex)
- **`sslrandraw <size>`** — Generate raw binary data
- **`sslrandhex <size>`** — Generate hex data
- **`sslrandbase64 <size>`** — Generate base64 data

### Encryption and Decryption

- **`sslenc <cipher> <in> <out>`** — Encrypt file
- **`ssldec <cipher> <in> <out>`** — Decrypt file
- **`sslaesenc <in> <out>`** — AES-256-CBC encrypt with PBKDF2
- **`sslaesdec <in> <out>`** — AES-256-CBC decrypt with PBKDF2

### CA Operations

- **`sslca`** — CA operations (requires CA config)

### Speed Testing

- **`sslspeed`** — Benchmark OpenSSL performance

### Server Testing and Setup

- **`sslserver <cert> <key> [port]`** — Run test TLS server

---

## GPG Aliases

### Key Management

- **`gpgk`** — List public keys
- **`gpgks`** — List secret keys
- **`gpggen`** — Generate new key pair
- **`gpgexport`** — Export public key
- **`gpgexports`** — Export secret key
- **`gpgimp`** — Import key
- **`gpgdel`** — Delete public key
- **`gpgdels`** — Delete secret key
- **`gpgrenew`** — Edit key (e.g. renew expiration)

### Encryption and Decryption

- **`gpgencrypt <recipient> <file>`** — Encrypt file for specific recipient
- **`gpgesign <recipient> <file>`** — Encrypt and sign file
- **`gpgsym`** — Symmetric encryption
- **`gpgdec`** — Decrypt file
- **`gpgdecfiles`** — Decrypt multiple files

### Signing and Verification

- **`gpgsign`** — Create binary signature
- **`gpgclear`** — Create cleartext signature
- **`gpgdetach`** — Detached signature
- **`gpgdetacha`** — Detached ASCII signature
- **`gpgverify`** — Verify signature
- **`gpgverifyf`** — Verify multiple signatures

### Key Server Operations

- **`gpgsearch`** — Search keys on key server
- **`gpgserver`** — Set default key server
- **`gpgkrecv <key_id>`** — Receive key from server
- **`gpgksend <key_id>`** — Send key to server
- **`gpgkrefresh`** — Refresh keys from server

### Fingerprints and Trust

- **`gpgfp`** — Show fingerprints
- **`gpgcheck`** — Check signatures
- **`gpgsig`** — List signatures
- **`gpgtrust <key_id>`** — Edit key trust level

### Miscellaneous

- **`gpgconf`** — Show GPG config
- **`gpgver`** — Show GPG version
- **`gpgminexp`** — Minimal key export
- **`gpgclean`** — Remove expired keys from keyring

---

## SSH Aliases

### Key Management

- **`sshkeyed25519 <comment>`** — Generate Ed25519 key
- **`sshkeyrsa <comment>`** — Generate RSA-4096 key
- **`sshkeylist`** — List `~/.ssh` directory
- **`sshkeycp`** — Copy SSH key to server
- **`sshagent`** — Start agent and add key
- **`sshagentls`** — List keys in agent
- **`sshagentdel`** — Remove key from agent
- **`sshagentdelall`** — Remove all keys from agent

### Configuration and Connections

- **`sshedit`** — Edit `~/.ssh/config`
- **`sshconfig`** — View `~/.ssh/config`
- **`sshls`** — List hosts from `~/.ssh/config`
- **`sshcheck`** — Test GitHub SSH connection
- **`sshv`**, **`sshvv`**, **`sshvvv`** — Verbose SSH connections

### Tunnels and Forwarding

- **`sshtunl <L:R:R> <host>`** — Local port forwarding
- **`sshtunr <R:L:L> <host>`** — Remote port forwarding
- **`sshtund <host>`** — Dynamic port forwarding (SOCKS)
- **`sshtunnel <L> <R> <host>`** — Persistent SSH tunnel

### Security Checks

- **`sshfp <key_file>`** — Show key fingerprint
- **`sshfpsha256 <key_file>`** — Show SHA256 fingerprint
- **`sshkeyaudit`** — Audit SSH server config (3rd-party)
- **`sshscan`** — Scan SSH auth methods with `nmap`

---

## UFW (Uncomplicated Firewall) Aliases

- **`fws`** — Show firewall status
- **`fwsv`** — Verbose status
- **`fwsn`** — Numbered status
- **`fwe`** — Enable firewall
- **`fwdis`** — Disable firewall
- **`fwds`** — Default deny incoming
- **`fwda`** — Default allow outgoing
- **`fwallow <port>`** — Allow
- **`fwdeny <port>`** — Deny
- **`fwdelete <rule>`** — Delete rule
- **`fwdeln <rule_num>`** — Delete by number
- **`fwlog <level>`** — Set log level
- **`fwreset`** — Reset rules
- **`fwassh`** — Allow SSH
- **`fwdssh`** — Deny SSH
- **`fwahttp`** — Allow HTTP
- **`fwahttps`** — Allow HTTPS
- (Plus more for MySQL, Mongo, Redis, etc.)

---

## Cryptographic Tools

### Hashing Utilities

Depending on your OS, you’ll have either `sha256sum`/`md5sum` or `shasum -a 256`/`md5`.

- **`sha256 <file>`** — Calculate SHA-256 hash
- **`sha1 <file>`** — Calculate SHA-1 hash
- **`sha512 <file>`** — Calculate SHA-512 hash
- **`md5 <file>`** — Calculate MD5 hash

### Password Generation

If `pwgen` is installed:

- **`pwgen8`**, **`pwgen12`**, **`pwgen16`**, **`pwgen20`**, **`pwgen32`**, **`pwgen64`** — Generate secure passwords of various lengths

### File Encryption

If `ccrypt` is installed:

- **`cce`** — Encrypt file (`ccrypt -e`)
- **`ccd`** — Decrypt file (`ccrypt -d`)
- **`ccc`** — Decrypt to stdout (`ccrypt -c`)

---

## Vulnerability Scanning

### nmap

- **`nms`** — TCP SYN scan
- **`nma`** — Aggressive scan
- **`nmv`** — Version detection
- **`nmo`** — OS detection
- **`nmp`** — Skip host discovery
- **`nmfast`** — Fast scan
- **`nmping`** — Ping scan only
- **`nmscript <script> <target>`** — Run nmap script
- **`nmvuln`** — Vulnerability scan
- **`nmall`** — Full aggressive scan

### lynis

- **`lyna`** — Audit system
- **`lynr`** — Show reports
- **`lyns`** — Show update info
- **`lynsu`** — Update Lynis

---

## Security Misc (fail2ban)

If `fail2ban-client` is installed:

- **`f2b`** — Fail2ban client
- **`f2bs`** — Show status
- **`f2bsa`** — Show all jails
- **`f2bssh`** — Show SSH jail status
- **`f2br`** — Reload config
- **`f2bunban <IP>`** — Unban an IP address

---

## Common Workflows

### Generating Random Data

```bash
# Generate 16 bytes of random hex
sslrand 16

# Generate 8 bytes of raw binary
sslrandraw 8

# Generate 32 bytes in Base64
sslrandbase64 32
```

### Checking Certificate Expiration

```bash
# Display certificate valid dates
sslx509dates mycert.pem

# Quickly verify with local CA store
sslverifycapath mycert.pem
```

### Encrypting/Decrypting Files

```bash
# Encrypt a file with AES-256-CBC
sslaesenc secrets.txt secrets.enc

# Decrypt a file
sslaesdec secrets.enc secrets-dec.txt
```

### Managing SSH Keys

```bash
# Generate a new Ed25519 key
sshkeyed25519 "dev@example.com"

# Copy key to remote server
sshkeycp -i ~/.ssh/id_ed25519.pub user@server
```

### Quick Firewall Rule Setup

```bash
# Default deny inbound, allow outbound
fwds
fwda

# Allow inbound on port 80
fwallow 80
```

### Fail2ban Unban Example

```bash
# Unban a specific IP
f2bunban 203.0.113.42
```

---

## License

[MIT License](https://opensource.org/licenses/MIT)

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
