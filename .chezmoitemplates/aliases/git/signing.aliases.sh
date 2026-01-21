#!/usr/bin/env bash
# Git Signing & Security Aliases
# Simplifies GPG/SSH signing configuration.

# Enable Git Signing (Wizard)
enable_signing_fn() {
    echo "🔐 Git Signing Configuration Wizard"
    echo "-------------------------------------"
    echo "1) GPG (Standard)"
    echo "2) SSH (Modern/GitHub)"
    echo "3) Cancel"
    
    read -r -p "Select signing method [1-3]: " choice
    
    case "$choice" in
        1)
            local key_id
            read -r -p "Enter GPG Key ID: " key_id
            if [[ -n "$key_id" ]]; then
                git config --global user.signingkey "$key_id"
                git config --global commit.gpgsign true
                echo "✅ GPG signing enabled globally for key: $key_id"
            else
                echo "❌ No key ID provided."
            fi
            ;;
        2)
            local key_path
            read -r -p "Enter path to SSH public key (default: ~/.ssh/id_ed25519.pub): " key_path
            key_path="${key_path:-$HOME/.ssh/id_ed25519.pub}"
            if [[ -f "$key_path" ]]; then
                git config --global gpg.format ssh
                git config --global user.signingkey "$key_path"
                git config --global commit.gpgsign true
                echo "✅ SSH signing enabled globally using: $key_path"
            else
                echo "❌ Key file not found: $key_path"
            fi
            ;;
        *)
            echo "Operation cancelled."
            ;;
    esac
}
alias enable-signing=enable_signing_fn

# Verify signatures of latest commits
alias verify-signatures='git log --show-signature -n 10'

# Check if current config has signing enabled
alias check-signing='git config --list | grep "gpg\|signing"'
