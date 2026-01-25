# Legal & Licensing Aliases

Tools for managing open source compliance, license scanning, and attribution.

##  Aliases

### License Scanning
| Alias | Description | Type |
|-------|-------------|------|
| `fossology-start` | Start local FOSSology server on port 8081 | Docker |
| `fossology-stop` | Stop FOSSology server | Docker |
| `license-scan` | Quick license scan of current dir (via Trivy) | Binary |

### Copyright Headers
| Alias | Description | Type |
|-------|-------------|------|
| `add-headers` | recursively add MIT license headers to all source files | Docker (google/addlicense) |

### Attribution
| Alias | Description | Type |
|-------|-------------|------|
| `gen-notice` | Generate a `NOTICE` file for dependencies (Go support initially) | Docker |

### Contribution
| Alias | Description | Type |
|-------|-------------|------|
| `check-cla` | Watch GitHub PR checks (including CLA) | CLI (`gh`) |

## Requirements

- **Docker**: For isolation of compliance tools.
- **GitHub CLI (`gh`)**: For PR/CLA checking.
- **Trivy**: Automatically installed/suggested for fast scanning.
