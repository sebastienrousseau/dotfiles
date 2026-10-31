# Security Aliases

Tools for GPG, OpenSSL, SSH, firewall rules and configuration immutability. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `crypto-utils.aliases.sh`, `gpg-crypto.aliases.sh`, `gpg-keys.aliases.sh`, `gpg-keyserver.aliases.sh`, `gpg-trust.aliases.sh`, `immutability.aliases.sh`, `nmap-scanning.aliases.sh`, `openssl-certs.aliases.sh`, `openssl-connections.aliases.sh`, `openssl-conversion.aliases.sh`, `openssl-crypto.aliases.sh`, `openssl-csr.aliases.sh`, `openssl-keys.aliases.sh`, `openssl-server.aliases.sh`, `openssl-verification.aliases.sh`, `security-audit.aliases.sh`, `security.aliases.sh`, `ssh-config.aliases.sh`, `ssh-keys.aliases.sh`, `ssh-tunnels.aliases.sh` and `ufw-rules.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `network`.

## Aliases

### `crypto-utils.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sha256` | `dot_hash_sha256` | Hashing Utilities (with fallback for macOS) |
| `sha1` | `dot_hash_sha1` |  |
| `sha512` | `dot_hash_sha512` |  |
| `md5` | `dot_hash_md5` |  |
| `pwgen8` | `pwgen -s 8 1` | Only when `pwgen` is on PATH. |
| `pwgen12` | `pwgen -s 12 1` | Only when `pwgen` is on PATH. |
| `pwgen16` | `pwgen -s 16 1` | Only when `pwgen` is on PATH. |
| `pwgen20` | `pwgen -s 20 1` | Only when `pwgen` is on PATH. |
| `pwgen32` | `pwgen -s 32 1` | Only when `pwgen` is on PATH. |
| `pwgen64` | `pwgen -s 64 1` | Only when `pwgen` is on PATH. |
| `cce` | `ccrypt -e` | Only when `ccrypt` is on PATH. |
| `ccd` | `ccrypt -d` | Only when `ccrypt` is on PATH. |
| `ccc` | `ccrypt -c` | Only when `ccrypt` is on PATH. |

### `gpg-crypto.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `gpgencrypt` | function |  |
| `gpgesign` | function |  |
| `gpgsym` | `gpg --symmetric` |  |
| `gpgdec` | `gpg --decrypt` |  |
| `gpgdecfiles` | `gpg --decrypt-files` |  |
| `gpgsign` | `gpg --sign` |  |
| `gpgclear` | `gpg --clearsign` |  |
| `gpgdetach` | `gpg --detach-sign` |  |
| `gpgdetacha` | `gpg --detach-sign --armor` |  |
| `gpgverify` | `gpg --verify` |  |
| `gpgverifyf` | `gpg --verify-files` |  |

### `gpg-keys.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `gpgk` | `gpg --list-keys` |  |
| `gpgka` | `gpg --list-keys --with-colons` |  |
| `gpgks` | `gpg --list-secret-keys` |  |
| `gpgksa` | `gpg --list-secret-keys --with-colons` |  |
| `gpggen` | `gpg --full-generate-key` |  |
| `gpgexport` | `gpg --export --armor` |  |
| `gpgexports` | `gpg --export-secret-keys --armor` |  |
| `gpgimp` | `gpg --import` |  |
| `gpgdel` | `gpg --delete-key` |  |
| `gpgdels` | `gpg --delete-secret-key` |  |
| `gpgrenew` | `gpg --edit-key` |  |
| `gpgver` | `gpg --version` |  |
| `gpgminexp` | `gpg --export-options export-minimal --export` |  |

### `gpg-keyserver.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `gpgsearch` | `gpg --search-keys` |  |
| `gpgserver` | `gpg --keyserver hkps://keys.openpgp.org` |  |
| `gpgkrecv` | function |  |
| `gpgksend` | function |  |
| `gpgkrefresh` | `gpg --keyserver hkps://keys.openpgp.org --refresh-keys` |  |

### `gpg-trust.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `gpgfp` | `gpg --fingerprint` |  |
| `gpgcheck` | `gpg --check-signatures` |  |
| `gpgsig` | `gpg --list-signatures` |  |
| `gpgtrust` | function |  |
| `gpgclean` | function |  |

### `immutability.aliases.sh`

These wrap `scripts/security/lock-configs.sh` from the source checkout (`$DOTFILES_DIR`, `~/.dotfiles` when unset), or from the legacy source location `~/.local/share/chezmoi`. With neither present, the aliases are not defined.

Every definition in this file exists only when file `$script_path` exists.

| Name | Definition | Notes |
| --- | --- | --- |
| `lock-configs` | `bash $script_path lock` | Lock critical files such as `~/.zshrc` (`chflags uchg` on macOS, `chattr +i` on Linux). |
| `unlock-configs` | `bash $script_path unlock` | Remove the immutable flag. |
| `check-locks` | `bash $script_path check` | Show which files are locked. |

### `nmap-scanning.aliases.sh`

Every definition in this file exists only when `nmap` is on PATH.

| Name | Definition | Notes |
| --- | --- | --- |
| `nmscript` | function |  |

### `openssl-certs.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslx509` | `openssl x509` | X.509 certificate utility. |
| `sslx509info` | function |  |
| `sslx509fp` | function |  |
| `sslx509dates` | function |  |
| `sslx509subject` | function |  |
| `sslx509issuer` | function |  |
| `sslx509check` | function |  |
| `sslx509extract` | function |  |

### `openssl-connections.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslconnect` | function |  |
| `sslconnectsni` | function |  |
| `sslciphers` | function |  |
| `sslshowcerts` | function |  |
| `sslprotocol` | function |  |

### `openssl-conversion.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslpkcs12` | function |  |
| `sslpkcs12extract` | function |  |
| `sslpkcs8` | function |  |

### `openssl-crypto.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `ssldigest` | function | Hash and Digest Functions. |
| `sslsha1` | `openssl dgst -sha1` |  |
| `sslsha256` | `openssl dgst -sha256` |  |
| `sslsha384` | `openssl dgst -sha384` |  |
| `sslsha512` | `openssl dgst -sha512` |  |
| `sslmd5` | `openssl dgst -md5` | Not recommended for security. |
| `sslrand` | function |  |
| `sslrandraw` | function |  |
| `sslrandhex` | function |  |
| `sslrandbase64` | function |  |
| `sslenc` | function |  |
| `ssldec` | function |  |
| `sslaesenc` | function |  |
| `sslaesdec` | function |  |

### `openssl-csr.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslreq` | `openssl req` |  |
| `sslreqnew` | function |  |
| `sslreqinfo` | function |  |
| `sslreqverify` | function |  |

### `openssl-keys.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslgenrsa` | function |  |
| `sslgenpkey` | function |  |
| `sslecparam` | function |  |
| `sslrsa` | function |  |
| `sslrsainfo` | function |  |
| `sslrsapub` | function |  |
| `sslpkey` | function |  |

### `openssl-server.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslca` | function |  |
| `sslspeed` | `openssl speed` |  |
| `sslserver` | function | Server Testing and Setup. |

### `openssl-verification.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sslverify` | function |  |
| `sslverifycapath` | function |  |
| `sslcrl` | function |  |

### `security-audit.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `lyna` | `sudo lynis audit system` | Only when `lynis` is on PATH. |
| `lynr` | `sudo lynis show reports` | Only when `lynis` is on PATH. |
| `lyns` | `sudo lynis update info` | Only when `lynis` is on PATH. |
| `lynsu` | `sudo lynis update release` | Only when `lynis` is on PATH. |
| `f2b` | `sudo fail2ban-client` | Only when `fail2ban-client` is on PATH. |
| `f2bs` | `sudo fail2ban-client status` | Only when `fail2ban-client` is on PATH. |
| `f2bsa` | `sudo fail2ban-client status all` | Only when `fail2ban-client` is on PATH. |
| `f2bssh` | `sudo fail2ban-client status sshd` | Only when `fail2ban-client` is on PATH. |
| `f2br` | `sudo fail2ban-client reload` | Only when `fail2ban-client` is on PATH. |
| `f2bunban` | function | Only when `fail2ban-client` is on PATH. |

### `security.aliases.sh`

Every definition in this file exists only when `openssl` is on PATH.

| Name | Definition | Notes |
| --- | --- | --- |
| `ssl` | `openssl` | OpenSSL shortcut. |
| `sslv` | `openssl version` | Show OpenSSL version. |
| `sslhelp` | `openssl help` | Show OpenSSL help. |

### `ssh-config.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sshedit` | `${EDITOR:-vi} ~/.ssh/config` |  |
| `sshconfig` | `cat ~/.ssh/config` |  |
| `sshls` | `grep "^Host " ~/.ssh/config \| sed "s/Host //"` |  |
| `sshcheck` | `ssh -T git@github.com` |  |
| `sshv` | `ssh -v` |  |
| `sshvv` | `ssh -vv` |  |
| `sshvvv` | `ssh -vvv` |  |
| `sshkeyaudit` | `ssh-audit` | 3rd-party tool. |
| `sshscan` | `nmap -p 22 --script ssh-auth-methods` |  |

### `ssh-keys.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sshkeyed25519` | function |  |
| `sshkeyrsa` | function |  |
| `sshkeylist` | `ls -la ~/.ssh` |  |
| `sshkeycp` | `ssh-copy-id` |  |
| `sshagent` | `eval "$(ssh-agent -s)" && ssh-add` |  |
| `sshagentls` | `ssh-add -l` |  |
| `sshagentdel` | `ssh-add -d` |  |
| `sshagentdelall` | `ssh-add -D` |  |
| `sshfp` | function |  |
| `sshfpsha256` | function |  |

### `ssh-tunnels.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `sshtunl` | function |  |
| `sshtunr` | function |  |
| `sshtund` | function |  |
| `sshtunnel` | function |  |

### `ufw-rules.aliases.sh`

Every definition in this file exists only when `ufw` is on PATH.

| Name | Definition | Notes |
| --- | --- | --- |
| `fws` | `sudo ufw status` |  |
| `fwsv` | `sudo ufw status verbose` |  |
| `fwsn` | `sudo ufw status numbered` |  |
| `fwe` | `sudo ufw enable` |  |
| `fwdis` | `sudo ufw disable` |  |
| `fwds` | `sudo ufw default deny incoming` |  |
| `fwda` | `sudo ufw default allow outgoing` |  |
| `fwallow` | function |  |
| `fwallowproto` | function |  |
| `fwdeny` | function |  |
| `fwdenyproto` | function |  |
| `fwdelete` | function |  |
| `fwdeln` | function |  |
| `fwlog` | function |  |
| `fwreset` | `sudo ufw reset` |  |
| `fwassh` | `sudo ufw allow ssh` |  |
| `fwdssh` | `sudo ufw deny ssh` |  |
| `fwahttp` | `sudo ufw allow http` |  |
| `fwahttps` | `sudo ufw allow https` |  |
| `fwamysql` | `sudo ufw allow mysql` |  |
| `fwasftp` | `sudo ufw allow sftp` |  |
| `fwamongo` | `sudo ufw allow 27017` |  |
| `fwaredis` | `sudo ufw allow 6379` |  |
| `fwasmtp` | `sudo ufw allow smtp` |  |
| `fwaimaps` | `sudo ufw allow imaps` |  |
| `fwapop3s` | `sudo ufw allow pop3s` |  |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
