#!/usr/bin/env bash
# security.aliases.sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025.
# License: MIT

###############################################################################
# 🅾🅿🅴🅽🆂🆂🅻 (openssl) Aliases & Functions
###############################################################################
if command -v openssl >/dev/null 2>&1; then
    # Basic Aliases
    alias ssl='openssl'                # OpenSSL shortcut
    alias sslv='openssl version'       # Show OpenSSL version
    alias sslhelp='openssl help'       # Show OpenSSL help

    #-----------------------------------------------------------------------------
    # Certificate Operations
    #-----------------------------------------------------------------------------
    alias sslx509='openssl x509'       # X.509 certificate utility

    function sslx509info() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509info <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -text -noout
    }

    function sslx509fp() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509fp <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -fingerprint -noout
    }

    function sslx509dates() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509dates <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -dates -noout
    }

    function sslx509subject() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509subject <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -subject -noout
    }

    function sslx509issuer() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509issuer <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -issuer -noout
    }

    function sslx509check() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509check <certificate_file>"
            return 1
        }
        openssl x509 -purpose -in "$1" -noout
    }

    function sslx509extract() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: sslx509extract <in_cert> <out_format> <out_file>"
            echo "Example: sslx509extract cert.pem DER cert.der"
            return 1
        }
        openssl x509 -in "$1" -outform "$2" -out "$3"
    }

    #-----------------------------------------------------------------------------
    # CSR (Certificate Signing Request) Operations
    #-----------------------------------------------------------------------------
    alias sslreq='openssl req'

    function sslreqnew() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslreqnew <key_out> <csr_out>"
            return 1
        }
        openssl req -new -nodes -keyout "$1" -out "$2"
    }

    function sslreqinfo() {
        [[ -z "$1" ]] && {
            echo "Usage: sslreqinfo <csr_file>"
            return 1
        }
        openssl req -in "$1" -text -noout
    }

    function sslreqverify() {
        [[ -z "$1" ]] && {
            echo "Usage: sslreqverify <csr_file>"
            return 1
        }
        openssl req -verify -in "$1"
    }

    #-----------------------------------------------------------------------------
    # Key Operations
    #-----------------------------------------------------------------------------
    function sslgenrsa() {
        [[ -z "$1" ]] && {
            echo "Usage: sslgenrsa <key_file> [size]"
            echo "Default size: 2048"
            return 1
        }
        openssl genrsa -out "$1" "${2:-2048}"
    }

    function sslgenpkey() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslgenpkey <algorithm> <key_out>"
            echo "Example: sslgenpkey RSA mykey.pem"
            return 1
        }
        openssl genpkey -algorithm "$1" -out "$2"
    }

    function sslecparam() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslecparam <curve_name> <out_key>"
            echo "Example: sslecparam prime256v1 eckey.pem"
            return 1
        }
        openssl ecparam -name "$1" -genkey -out "$2"
    }

    function sslrsa() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrsa <rsa_private_key_file>"
            return 1
        }
        openssl rsa -in "$1" -check
    }

    function sslrsainfo() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrsainfo <rsa_private_key_file>"
            return 1
        }
        openssl rsa -in "$1" -text -noout
    }

    function sslrsapub() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslrsapub <rsa_private_key_file> <pub_key_out>"
            return 1
        }
        openssl rsa -in "$1" -pubout -out "$2"
    }

    function sslpkey() {
        [[ -z "$1" ]] && {
            echo "Usage: sslpkey <key_file> [additional_params]"
            return 1
        }
        openssl pkey -in "$1" "${@:2}"
    }

    #-----------------------------------------------------------------------------
    # Conversion Operations
    #-----------------------------------------------------------------------------
    function sslpkcs12() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: sslpkcs12 <cert_in> <key_in> <p12_out>"
            return 1
        }
        openssl pkcs12 -export -in "$1" -inkey "$2" -out "$3"
    }

    function sslpkcs12extract() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslpkcs12extract <p12_file> <out_file>"
            return 1
        }
        openssl pkcs12 -in "$1" -nodes -out "$2"
    }

    function sslpkcs8() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslpkcs8 <key_in> <key_out>"
            return 1
        }
        openssl pkcs8 -in "$1" -topk8 -out "$2"
    }

    #-----------------------------------------------------------------------------
    # Connection Testing
    #-----------------------------------------------------------------------------
    function sslconnect() {
        [[ -z "$1" ]] && {
            echo "Usage: sslconnect <host> [port]"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}"
    }

    function sslconnectsni() {
        [[ -z "$1" ]] && {
            echo "Usage: sslconnectsni <host> [port]"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -servername "$1"
    }

    function sslciphers() {
        [[ -z "$1" || -z "$3" ]] && {
            echo "Usage: sslciphers <host> <port> <cipher_list>"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -cipher "$3"
    }

    function sslshowcerts() {
        [[ -z "$1" ]] && {
            echo "Usage: sslshowcerts <host> [port]"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -showcerts
    }

    function sslprotocol() {
        [[ -z "$1" || -z "$3" ]] && {
            echo "Usage: sslprotocol <host> <port> <protocol>"
            echo "Example: sslprotocol example.com 443 tls1_2"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -"$3"
    }

    #-----------------------------------------------------------------------------
    # Certificate Verification
    #-----------------------------------------------------------------------------
    function sslverify() {
        [[ -z "$1" ]] && {
            echo "Usage: sslverify <certificate_file> [more_files]"
            return 1
        }
        openssl verify "$@"
    }

    function sslverifycapath() {
        [[ -z "$1" ]] && {
            echo "Usage: sslverifycapath <certificate_file> [more_files]"
            return 1
        }
        openssl verify -CApath /etc/ssl/certs/ "$@"
    }

    function sslcrl() {
        [[ -z "$1" ]] && {
            echo "Usage: sslcrl <crl_file>"
            return 1
        }
        openssl crl -in "$1" -text -noout
    }

    #-----------------------------------------------------------------------------
    # Hash and Digest Functions
    #-----------------------------------------------------------------------------
    function ssldigest() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: ssldigest <algorithm> <file>"
            echo "Example: ssldigest sha256 file.txt"
            return 1
        }
        openssl dgst -"$1" "$2"
    }

    alias sslsha1='openssl dgst -sha1'
    alias sslsha256='openssl dgst -sha256'
    alias sslsha384='openssl dgst -sha384'
    alias sslsha512='openssl dgst -sha512'
    alias sslmd5='openssl dgst -md5'  # Not recommended for security

    #-----------------------------------------------------------------------------
    # Random Generation
    #-----------------------------------------------------------------------------
    # Default to hex output for readability
    function sslrand() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrand <size>"
            return 1
        }
        openssl rand -hex "$1"
    }

    function sslrandraw() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrandraw <size>"
            return 1
        }
        openssl rand "$1"
    }

    function sslrandhex() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrandhex <size>"
            return 1
        }
        openssl rand -hex "$1"
    }

    function sslrandbase64() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrandbase64 <size>"
            return 1
        }
        openssl rand -base64 "$1"
    }

    #-----------------------------------------------------------------------------
    # Encryption and Decryption
    #-----------------------------------------------------------------------------
    function sslenc() {
        if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
            echo "Usage: sslenc <cipher> <in_file> <out_file> [additional_params]"
            echo "Example: sslenc aes-256-cbc secret.txt secret.enc -pbkdf2 -iter 10000"
            return 1
        fi
        openssl enc -"$1" -e -in "$2" -out "$3" "${@:4}"
    }

    function ssldec() {
        if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
            echo "Usage: ssldec <cipher> <in_file> <out_file> [additional_params]"
            echo "Example: ssldec aes-256-cbc secret.enc secret.dec -pbkdf2 -iter 10000"
            return 1
        fi
        openssl enc -"$1" -d -in "$2" -out "$3" "${@:4}"
    }

    function sslaesenc() {
        if [[ -z "$1" || -z "$2" ]]; then
            echo "Usage: sslaesenc <in_file> <out_file>"
            return 1
        fi
        openssl enc -aes-256-cbc -salt -in "$1" -out "$2" -iter 10000 -pbkdf2
    }

    function sslaesdec() {
        if [[ -z "$1" || -z "$2" ]]; then
            echo "Usage: sslaesdec <in_file> <out_file>"
            return 1
        fi
        openssl enc -aes-256-cbc -d -in "$1" -out "$2" -iter 10000 -pbkdf2
    }

    #-----------------------------------------------------------------------------
    # CA Operations
    #-----------------------------------------------------------------------------
    function sslca() {
        # Typically requires a CA config file. Adjust as needed.
        openssl ca "$@"
    }

    #-----------------------------------------------------------------------------
    # Speed Testing
    #-----------------------------------------------------------------------------
    alias sslspeed='openssl speed'

    #-----------------------------------------------------------------------------
    # Server Testing and Setup
    #-----------------------------------------------------------------------------
    function sslserver() {
        if [[ -z "$1" || -z "$2" ]]; then
            echo "Usage: sslserver <cert_file> <key_file> [port]"
            echo "Default port: 4433"
            return 1
        fi
        openssl s_server -cert "$1" -key "$2" -port "${3:-4433}"
    }
fi

###############################################################################
# 🅶🅿🅶 (GnuPG) Aliases & Functions
###############################################################################
if command -v gpg >/dev/null 2>&1; then
    # Key Management
    alias gpgk='gpg --list-keys'
    alias gpgka='gpg --list-keys --with-colons'
    alias gpgks='gpg --list-secret-keys'
    alias gpgksa='gpg --list-secret-keys --with-colons'
    alias gpggen='gpg --full-generate-key'
    alias gpgexport='gpg --export --armor'
    alias gpgexports='gpg --export-secret-keys --armor'
    alias gpgimp='gpg --import'
    alias gpgdel='gpg --delete-key'
    alias gpgdels='gpg --delete-secret-key'
    alias gpgrenew='gpg --edit-key'

    # Encryption & Decryption
    function gpgencrypt() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: gpgencrypt <recipient> <file>"
            return 1
        }
        gpg --encrypt --recipient "$1" "$2"
    }

    function gpgesign() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: gpgesign <recipient> <file>"
            return 1
        }
        gpg --encrypt --sign --recipient "$1" "$2"
    }

    alias gpgsym='gpg --symmetric'
    alias gpgdec='gpg --decrypt'
    alias gpgdecfiles='gpg --decrypt-files'

    # Signing & Verification
    alias gpgsign='gpg --sign'
    alias gpgclear='gpg --clearsign'
    alias gpgdetach='gpg --detach-sign'
    alias gpgdetacha='gpg --detach-sign --armor'
    alias gpgverify='gpg --verify'
    alias gpgverifyf='gpg --verify-files'

    # Key Server Operations
    alias gpgsearch='gpg --search-keys'
    alias gpgserver='gpg --keyserver hkps://keys.openpgp.org'
    function gpgkrecv() {
        [[ -z "$1" ]] && {
            echo "Usage: gpgkrecv <key_id>"
            return 1
        }
        gpg --keyserver hkps://keys.openpgp.org --recv-keys "$1"
    }
    function gpgksend() {
        [[ -z "$1" ]] && {
            echo "Usage: gpgksend <key_id>"
            return 1
        }
        gpg --keyserver hkps://keys.openpgp.org --send-keys "$1"
    }
    alias gpgkrefresh='gpg --keyserver hkps://keys.openpgp.org --refresh-keys'

    # Fingerprints & Trust
    alias gpgfp='gpg --fingerprint'
    alias gpgcheck='gpg --check-signatures'
    alias gpgsig='gpg --list-signatures'
    function gpgtrust() {
        [[ -z "$1" ]] && {
            echo "Usage: gpgtrust <key_id>"
            return 1
        }
        gpg --edit-key "$1" trust quit
    }

    # Miscellaneous
    alias gpgconf='gpg --list-config'
    alias gpgver='gpg --version'
    alias gpgminexp='gpg --export-options export-minimal --export'

    function gpgclean() {
        # Deletes expired keys from keyring
        # NOTE: Ensure your grep/awk usage aligns with your local gpg output format
        local EXPIRED
        EXPIRED="$(gpg --list-keys 2>/dev/null | grep expired | awk '{print $2}')"
        [[ -z "$EXPIRED" ]] && {
            echo "No expired keys found."
            return 0
        }
        sudo gpg --batch --yes --delete-keys "$EXPIRED"
    }
fi

###############################################################################
# 🆂🆂🅷 (Secure Shell) Aliases & Functions
###############################################################################
if command -v ssh >/dev/null 2>&1; then
    # Key Management
    function sshkeyed25519() {
        [[ -z "$1" ]] && {
            echo "Usage: sshkeyed25519 <comment/email>"
            return 1
        }
        ssh-keygen -t ed25519 -C "$1"
    }

    function sshkeyrsa() {
        [[ -z "$1" ]] && {
            echo "Usage: sshkeyrsa <comment/email>"
            return 1
        }
        ssh-keygen -t rsa -b 4096 -C "$1"
    }

    alias sshkeylist='ls -la ~/.ssh'
    alias sshkeycp='ssh-copy-id'
    alias sshagent='eval "$(ssh-agent -s)" && ssh-add'
    alias sshagentls='ssh-add -l'
    alias sshagentdel='ssh-add -d'
    alias sshagentdelall='ssh-add -D'

    # Configuration & Connections
    alias sshedit='${EDITOR:-vi} ~/.ssh/config'
    alias sshconfig='cat ~/.ssh/config'
    alias sshls='grep "^Host " ~/.ssh/config | sed "s/Host //"'
    alias sshcheck='ssh -T git@github.com'
    alias sshv='ssh -v'
    alias sshvv='ssh -vv'
    alias sshvvv='ssh -vvv'

    # Tunnels & Forwarding
    function sshtunl() {
        [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && {
            echo "Usage: sshtunl <local_port:host:remote_port> <ssh_host>"
            echo "Example: sshtunl 8080:127.0.0.1:80 user@server"
            return 1
        }
        ssh -L "$1:$2:$3" "$4"
    }

    function sshtunr() {
        [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && {
            echo "Usage: sshtunr <remote_port:host:local_port> <ssh_host>"
            echo "Example: sshtunr 8080:127.0.0.1:80 user@server"
            return 1
        }
        ssh -R "$1:$2:$3" "$4"
    }

    function sshtund() {
        [[ -z "$1" ]] && {
            echo "Usage: sshtund <ssh_host>"
            return 1
        }
        ssh -D 8080 "$1"
    }

    function sshtunnel() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: sshtunnel <local_port> <remote_port> <ssh_host>"
            echo "Example: sshtunnel 8000 8080 user@server"
            return 1
        }
        ssh -N -L "$1:localhost:$2" "$3"
    }

    # Security Checks
    function sshfp() {
        [[ -z "$1" ]] && {
            echo "Usage: sshfp <key_file>"
            return 1
        }
        ssh-keygen -l -f "$1"
    }

    function sshfpsha256() {
        [[ -z "$1" ]] && {
            echo "Usage: sshfpsha256 <key_file>"
            return 1
        }
        ssh-keygen -l -E sha256 -f "$1"
    }

    alias sshkeyaudit='ssh-audit'  # 3rd-party tool
    alias sshscan='nmap -p 22 --script ssh-auth-methods'
fi

###############################################################################
# 🆄🅵🆆 (Uncomplicated Firewall) Aliases & Functions
###############################################################################
if command -v ufw >/dev/null 2>&1; then
    # Basic Commands
    alias fws='sudo ufw status'
    alias fwsv='sudo ufw status verbose'
    alias fwsn='sudo ufw status numbered'
    alias fwe='sudo ufw enable'
    alias fwdis='sudo ufw disable'
    alias fwds='sudo ufw default deny incoming'
    alias fwda='sudo ufw default allow outgoing'

    # Rule Management
    function fwallow() {
        [[ -z "$1" ]] && {
            echo "Usage: fwallow <service_or_port>"
            return 1
        }
        sudo ufw allow "$1"
    }

    function fwallowproto() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: fwallowproto <protocol> <from_IP> <to_IP>"
            return 1
        }
        sudo ufw allow proto "$1" from "$2" to "$3"
    }

    function fwdeny() {
        [[ -z "$1" ]] && {
            echo "Usage: fwdeny <service_or_port>"
            return 1
        }
        sudo ufw deny "$1"
    }

    function fwdenyproto() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: fwdenyproto <protocol> <from_IP> <to_IP>"
            return 1
        }
        sudo ufw deny proto "$1" from "$2" to "$3"
    }

    function fwdelete() {
        [[ -z "$1" ]] && {
            echo "Usage: fwdelete <rule>"
            return 1
        }
        sudo ufw delete "$1"
    }

    function fwdeln() {
        [[ -z "$1" ]] && {
            echo "Usage: fwdeln <rule_number>"
            return 1
        }
        sudo ufw delete "$1"
    }

    function fwlog() {
        [[ -z "$1" ]] && {
            echo "Usage: fwlog <off|low|medium|high|full>"
            return 1
        }
        sudo ufw logging "$1"
    }

    alias fwreset='sudo ufw reset'

    # Common Rules
    alias fwassh='sudo ufw allow ssh'
    alias fwdssh='sudo ufw deny ssh'
    alias fwahttp='sudo ufw allow http'
    alias fwahttps='sudo ufw allow https'
    alias fwamysql='sudo ufw allow mysql'
    alias fwasftp='sudo ufw allow sftp'
    alias fwamongo='sudo ufw allow 27017'
    alias fwaredis='sudo ufw allow 6379'
    alias fwasmtp='sudo ufw allow smtp'
    alias fwaimaps='sudo ufw allow imaps'
    alias fwapop3s='sudo ufw allow pop3s'
fi

###############################################################################
# 🅲🆁🆈🅿🆃🅾🅶🆁🅰🅿🅷🅸🅲 Tools (Checksums, Encryption, etc.)
###############################################################################
# Hashing Utilities (with fallback for macOS)
if command -v sha256sum >/dev/null 2>&1; then
    alias sha256='sha256sum'
    alias sha1='sha1sum'
    alias sha512='sha512sum'
    alias md5='md5sum'
elif command -v shasum >/dev/null 2>&1; then
    # macOS default
    alias sha256='shasum -a 256'
    alias sha1='shasum -a 1'
    alias sha512='shasum -a 512'
    alias md5='md5'  # macOS has `md5` by default
fi

# Password Generation
if command -v pwgen >/dev/null 2>&1; then
    alias pwgen8='pwgen -s 8 1'
    alias pwgen12='pwgen -s 12 1'
    alias pwgen16='pwgen -s 16 1'
    alias pwgen20='pwgen -s 20 1'
    alias pwgen32='pwgen -s 32 1'
    alias pwgen64='pwgen -s 64 1'
fi

# File Encryption with ccrypt
if command -v ccrypt >/dev/null 2>&1; then
    alias cce='ccrypt -e'
    alias ccd='ccrypt -d'
    alias ccc='ccrypt -c'
fi

###############################################################################
# 🆅🆄🅻🅽🅴🆁🅰🅱🅸🅻🅸🆃🆈 / 🆂🅲🅰🅽🅽🅸🅽🅶 Tools
###############################################################################
# Nmap
if command -v nmap >/dev/null 2>&1; then
    alias nms='nmap -sS'
    alias nma='nmap -A'
    alias nmv='nmap -sV'
    alias nmo='nmap -O'
    alias nmp='nmap -Pn'
    alias nmfast='nmap -F'
    alias nmping='nmap -sn'

    function nmscript() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: nmscript <script_name> <target>"
            return 1
        }
        nmap --script "$1" "$2"
    }

    alias nmvuln='nmap --script vuln'
    alias nmall='nmap -A -T4 -p-'
fi

# Lynis
if command -v lynis >/dev/null 2>&1; then
    alias lyna='sudo lynis audit system'
    alias lynr='sudo lynis show reports'
    alias lyns='sudo lynis update info'
    alias lynsu='sudo lynis update release'
fi

###############################################################################
# 🆂🅴🅲🆄🆁🅸🆃🆈 🅼🅸🆂🅲 (fail2ban, etc.)
###############################################################################
if command -v fail2ban-client >/dev/null 2>&1; then
    alias f2b='sudo fail2ban-client'
    alias f2bs='sudo fail2ban-client status'
    alias f2bsa='sudo fail2ban-client status all'
    alias f2bssh='sudo fail2ban-client status sshd'
    alias f2br='sudo fail2ban-client reload'

    function f2bunban() {
        [[ -z "$1" ]] && {
            echo "Usage: f2bunban <IP>"
            return 1
        }
        sudo fail2ban-client unban "$1"
    }
fi
