# Security Policy Enforcement for Dotfiles Repository
# This policy enforces security best practices and compliance requirements

package dotfiles.security

import rego.v1

# Default deny
default allow_commit := false
default allow_file := false
default allow_workflow := false

# Allow commits that pass all security checks
allow_commit if {
    no_hardcoded_secrets
    no_sensitive_files
    valid_file_permissions
    proper_environment_usage
}

# Allow files that meet security criteria
allow_file if {
    input.file_path
    ext := file_extension(input.file_path)
    not ext in forbidden_extensions
    not contains_hardcoded_credentials
    proper_file_permissions
}

# Allow workflows that follow security best practices
allow_workflow if {
    input.workflow_path
    workflow_has_proper_permissions
    workflow_uses_pinned_actions
    workflow_has_security_scanning
}

# Security Rules

# Check for hardcoded secrets
no_hardcoded_secrets if {
    not contains(input.content, "password=")
    not contains(input.content, "token=")
    not contains(input.content, "secret=")
    not contains(input.content, "key=")
    not regex.match(`[A-Za-z0-9+/]{40,}`, input.content)
}

# Check for sensitive files
no_sensitive_files if {
    fname := base_filename(input.file_path)
    not fname in forbidden_files
}

# Validate file permissions
valid_file_permissions if {
    input.file_mode
    input.file_mode <= 755
}

proper_file_permissions if {
    input.file_path
    not endswith(input.file_path, ".key")
    not endswith(input.file_path, ".pem")
}

# Environment variable usage patterns
proper_environment_usage if {
    # Allow environment variable references
    not regex.match(`\$[A-Z_]+\s*=\s*["\'][^"\']*["\']`, input.content)

    # Encourage proper defaulting
    count(regex.find_n(`\$\{[A-Z_]+:-[^}]*\}`, input.content, -1)) >= 0
}

# Workflow security checks
workflow_has_proper_permissions if {
    input.workflow.permissions
    input.workflow.permissions.contents == "read"
}

workflow_uses_pinned_actions if {
    all_actions := [action |
        some j, k
        action := input.workflow.jobs[j].steps[k].uses
        action != null
    ]

    count([action |
        some i
        action := all_actions[i]
        not regex.match(`.*@v\d+\.\d+\.\d+$|.*@[a-f0-9]{40}$`, action)
    ]) == 0
}

workflow_has_security_scanning if {
    some i
    input.workflow.jobs[i].name
    contains(input.workflow.jobs[i].name, "Security")
}

# Helper functions
file_extension(path) := ext if {
    parts := split(path, ".")
    ext := parts[count(parts) - 1]
}

base_filename(path) := filename if {
    parts := split(path, "/")
    filename := parts[count(parts) - 1]
}

contains_hardcoded_credentials if {
    # Check for common credential patterns
    regex.match(`(?i)(password|pwd|secret|token|key|credential)\s*[=:]\s*["\']?[^"\'\s]+`, input.content)
}

# Forbidden file extensions and names
forbidden_extensions := {
    "p12", "pfx", "key", "pem", "crt", "cert", "jks", "keystore"
}

forbidden_files := {
    ".env", ".env.local", ".env.production", ".env.development",
    "credentials.json", "service-account.json", "private-key.pem",
    "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519"
}

# Test cases for validation
test_allow_safe_file if {
    allow_file with input as {
        "file_path": "scripts/install.sh",
        "content": "#!/bin/bash\necho 'Installing packages'",
        "file_mode": 644,
    }
}

test_deny_secret_file if {
    not allow_file with input as {
        "file_path": "config/secret.key",
        "content": "secret_key_content",
        "file_mode": 600,
    }
}

test_deny_hardcoded_password if {
    not no_hardcoded_secrets with input as {
        "content": "password=secret123",
    }
}

test_allow_environment_variable if {
    no_hardcoded_secrets with input as {
        "content": "DB_PASSWORD=${DB_PASSWORD:-default}",
    }
}

test_allow_secure_workflow if {
    allow_workflow with input as {
        "workflow_path": ".github/workflows/test.yml",
        "workflow": {
            "permissions": {"contents": "read"},
            "jobs": {
                "security": {
                    "name": "Security / Scan",
                    "steps": [
                        {"uses": "actions/checkout@v4.1.2"},
                    ],
                },
            },
        },
    }
}

# Security metrics and reporting
security_score := score if {
    checks := [
        no_hardcoded_secrets,
        no_sensitive_files,
        valid_file_permissions,
        proper_environment_usage,
    ]

    passed := count([check | some i; check := checks[i]; check == true])
    total := count(checks)
    score := (passed * 100) / total
}
