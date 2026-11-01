<img
  src="https://cloudcdn.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Chezmoi Templates (v0.2.541)

Modular shell configuration managed by Chezmoi

![Dotfiles banner](https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg)

This directory contains modular templates that are aggregated into the shell environment during `chezmoi apply`.

## Current Organization

### Directory Structure

```text
.chezmoitemplates/
├── aliases/              # *.aliases.sh files, one subdirectory per domain
│   ├── ai/
│   ├── docker/
│   ├── git/
│   ├── kubernetes/
│   └── ...
├── functions/            # one function per .sh file, in category subdirectories
│   ├── api/ curl/ files/ interactive/ misc/ nav/ security/ system/ text/
│   ├── utils/            # loaded eagerly (logging helpers, yy)
│   ├── helpers/          # path-utils.tmpl
│   └── groups.json       # lazy-load groups for the files outside utils/
├── desktop/              # shell-theme.dconf.tmpl (no template includes it today)
├── go-build-command      # shared Go build snippet for the run_onchange build scripts
└── theme-name            # resolves the active theme name for themed templates
```

There is no `paths/` directory: PATH setup lives in `defaults/dot_config/shell/00-core-paths.sh.tmpl`.

### Template Categories

| Category | Organization | Documentation |
|----------|--------------|---------------|
| **Aliases** | Domain-specific subdirectories | [aliases/README.md](aliases/README.md) |
| **Functions** | Category subdirectories, `utils/` and `groups.json` | [functions/README.md](functions/README.md) |

## How Templates Work

1. **Chezmoi Scanning**: Templates in `defaults/dot_config/shell/` scan these directories:
   - Aliases: `aliases/**/*.aliases.sh`
   - Functions: `functions/utils/*.sh`, the files listed in `functions/groups.json`, and
     `functions/**/*.sh`

2. **Aggregation**: Files are combined into shell layers in `~/.config/shell/`:
   - `90-ux-aliases.sh` (eager aliases) and `91-ux-aliases-lazy.sh` (lazy aliases)
   - `50-logic-functions-core.sh` (`utils/`), `51-logic-functions-extra.sh` (lazy-loading
     stubs per group) and `50-logic-functions.sh` (every function, used by the fish bridge)

3. **Loading**: Bash (`dot_bashrc`) and zsh (`dot_config/zsh/dot_zshrc.tmpl`) source the layers;
   the [aliases](aliases/README.md#how-it-works) and [functions](functions/README.md#how-it-works)
   READMEs give the order.

## Namespace Structure Recommendations

### Current State Assessment

**Strengths:**

- Aliases use domain-based organization
- Functions are grouped into category subdirectories
- Each alias domain has its own README

**Growth Concerns:**

- No consistent versioning scheme across categories
- Potential namespace collisions between alias files, and between alias and function names
  (today `backup`, `extract` and `goto` exist in both; the alias-file version wins in zsh and bash)

### Recommended Namespace Structure for Future Growth

#### 1. Functions Reorganization

**Status**: Functions already live in category subdirectories (`api/`, `files/`, `nav/` and so
on). The structure below is a possible further split.

**Recommended Structure**:

```text
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

```text
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

### Phase 1: Functions Reorganization (Done)

Functions moved into category subdirectories, and the function templates scan them
(`functions/**/*.sh` and `groups.json`).

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
- **Functions**: `category/funcname.sh`, defining a function named `funcname`

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

1. Validate no regression in shell loading performance

Made With ❤️ in London, United Kingdom • [dotfiles.io](https://dotfiles.io)
