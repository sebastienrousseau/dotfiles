<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Chezmoi Templates (v0.2.480)

Simply designed to fit your shell life

![Dotfiles banner](https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg)

This directory contains modular templates that are aggregated into the shell environment during `chezmoi apply`.

## Current Organization

### Directory Structure

```
.chezmoitemplates/
├── aliases/          # 97 files across 46 functional domains
│   ├── ai/
│   ├── docker/
│   ├── git/
│   ├── kubernetes/
│   └── ... (42 more)
├── functions/        # Utility functions and template helpers
│   ├── helpers/      # Reusable template patterns
│   │   ├── feature-flags.tmpl   # Feature flag resolution
│   │   ├── git-vars.tmpl        # Git variable helpers
│   │   ├── os-detection.tmpl    # OS/platform detection
│   │   └── path-utils.tmpl      # XDG and path utilities
│   ├── utils/        # Common utilities (logging.sh)
│   └── *.sh          # Individual function files
└── paths/            # 3 priority-ordered PATH files
    ├── 00-default.paths.sh    # Base system paths
    ├── 05-pipx.paths.sh       # pipx paths
    └── 99-custom.paths.sh     # User custom paths
```

## Template Helpers

The `functions/helpers/` directory contains reusable template patterns to reduce
complexity in `.tmpl` files:

| Helper | Purpose |
|--------|---------|
| `git-vars.tmpl` | Resolve git user/email/signing variables with fallbacks |
| `feature-flags.tmpl` | Consistent feature flag resolution with defaults |
| `os-detection.tmpl` | OS, architecture, and package manager detection |
| `path-utils.tmpl` | XDG Base Directory and common tool paths |

### Usage Pattern

Instead of repetitive variable resolution (old pattern):

    # Old verbose pattern - don't use
    $git_name := ""
    if hasKey . "git_name" then $git_name = .git_name
    if hasKey . "name" then $git_name = .name
    if (not $git_name) and $name then $git_name = $name

Use the idiomatic `coalesce` pattern (recommended):

    # New concise pattern - use this
    $git_name := coalesce .git_name .name ""

See actual implementation in `dot_gitconfig.tmpl` for working examples.

### Template Categories

| Category | Files | Organization | Documentation |
|----------|-------|--------------|---------------|
| **Aliases** | 97 | Domain-specific subdirectories | [aliases/README.md](aliases/README.md) |
| **Functions** | 52 | Flat structure + utils/ | [functions/README.md](functions/README.md) |
| **Paths** | 3 | Priority-based numbering | [paths/README.md](paths/README.md) |

## How Templates Work

1. **Chezmoi Scanning**: Template aggregators scan these directories for specific patterns:
   - Aliases: `**/*.aliases.sh`
   - Functions: `**/*.sh`
   - Paths: `*.paths.sh`

2. **Aggregation**: Files are combined into single shell configuration files:
   - `~/.config/shell/aliases.sh`
   - `~/.config/shell/functions.sh`
   - `~/.config/shell/paths.sh`

3. **Loading**: Shell startup (`.zshrc`) sources the aggregated files

## Namespace Structure Recommendations

### Current State Assessment

**Strengths:**
- Aliases use excellent domain-based organization (46 functional categories)
- Paths use priority-based numbering system (00-, 05-, 99-)
- Each category has comprehensive documentation

**Growth Concerns:**
- Functions directory is flat with 52 files (will become unwieldy at scale)
- No consistent versioning scheme across categories
- Potential namespace collisions in functions

### Recommended Namespace Structure for Future Growth

#### 1. Functions Reorganization (Priority: HIGH)

**Current Issue**: 52 functions in flat structure will become unmaintainable.

**Recommended Structure**:
```
functions/
├── core/                # Essential system utilities
│   ├── filesystem/      # File operations (backup, extract, zipf)
│   ├── navigation/      # Directory navigation (cdls, goto, rd)
│   └── system/         # System info (hostinfo, sysinfo, environment)
├── development/         # Development tools
│   ├── api/            # API testing (apihealth, apilatency, httpdebug)
│   ├── security/       # Security tools (genpass, keygen)
│   └── web/            # Web utilities (curlheader, view-source)
├── productivity/        # User productivity
│   ├── text/           # Text processing (case conversion functions)
│   └── media/          # Media tools (ql, matrix)
└── utils/              # Shared utilities (logging, common functions)
```

#### 2. Versioning Strategy (Priority: MEDIUM)

**Current Issue**: No version coordination between template categories.

**Recommended Approach**:
- Maintain single version in top-level README
- Template categories reference parent version
- Individual templates can have micro-versions for breaking changes

#### 3. Cross-Platform Namespace (Priority: MEDIUM)

**Current State**: Some platform-specific organization (macOS directory in aliases).

**Recommended Structure**:
```
aliases/
├── core/               # Cross-platform commands
├── platform/
│   ├── macos/         # macOS-specific aliases
│   ├── linux/         # Linux-specific aliases
│   └── windows/       # Windows/WSL-specific aliases
└── vendor/            # Third-party tools (docker, kubernetes, etc.)
```

#### 4. Dependency Management (Priority: LOW)

**Future Consideration**: As template count grows, consider dependency declarations:
```yaml
# In function headers
# REQUIRES: utils/logging.sh
# CONFLICTS: legacy/oldfunction.sh
# PLATFORM: macos,linux
```

## Migration Strategy

### Phase 1: Functions Reorganization (Immediate)
1. Create new subdirectory structure in `functions/`
2. Move existing functions to appropriate categories
3. Update documentation to reflect new structure
4. Test aggregation still works correctly

### Phase 2: Platform Abstraction (Future)
1. Abstract platform-specific logic into dedicated namespaces
2. Create platform detection in aggregation templates
3. Conditional loading based on detected platform

### Phase 3: Dependency System (Future)
1. Implement dependency validation in aggregation
2. Add conflict detection
3. Create template registry with metadata

## Quality Standards

### Naming Conventions
- **Aliases**: `category/toolname.aliases.sh`
- **Functions**: `category/subcategory/funcname.sh`
- **Paths**: `##-purpose.paths.sh` (priority prefix)

### Documentation Requirements
- Each category MUST have README.md with usage examples
- Individual functions MUST include `--help` documentation
- Breaking changes MUST increment category micro-version

### Testing Considerations
- Aggregation MUST remain functional after reorganization
- Platform detection MUST be reliable
- No namespace collisions between categories

---

**Next Actions:**
1. Implement functions reorganization (Phase 1)
2. Update aggregation templates to handle subdirectories
3. Validate no regression in shell loading performance

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
