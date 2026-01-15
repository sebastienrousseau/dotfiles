# Phase A.M1: Alias Consolidation Plan

## Current State Analysis

**Total alias categories:** 34 directories + .sh files  
**Total aliases:** ~3000+ lines of aliases across 35+ files

### Current Structure
```
lib/aliases/
├── archives/           (3 files) - Archive handling (tar, zip, extract)
├── cd/                 (1 file)  - Directory navigation
├── chmod/              (1 file)  - Permission changes
├── clear/              (1 file)  - Clear command
├── configuration/      (2 files) - Config management
├── default/            (1 file)  - Default aliases
├── dig/                (1 file)  - DNS lookups
├── disk-usage/         (1 file)  - Disk space
├── docker/             (1 file)  - Docker commands
├── editor/             (1 file)  - Editor shortcuts
├── find/               (1 file)  - Find command variations
├── gcloud/             (1 file)  - Google Cloud
├── git/                (1 file)  - Git commands (544 lines)
├── gnu/                (1 file)  - GNU tool variations
├── heroku/             (2 files) - Heroku platform
├── interactive/        (1 file)  - Interactive commands
├── list/               (1 file)  - List variations
├── macOS/              (1 file)  - macOS specific
├── make/               (1 file)  - Make/build
├── mkdir/              (1 file)  - Directory creation
├── npm/                (1 file)  - npm commands
├── permission/         (1 file)  - Permission aliases
├── pnpm/               (1 file)  - pnpm commands
├── ps/                 (1 file)  - Process listing
├── python/             (1 file)  - Python aliases
├── rsync/              (1 file)  - rsync commands
├── rust/               (1 file)  - Rust/cargo
├── security/           (1 file)  - Security commands (744 lines)
├── subversion/         (1 file)  - SVN commands
├── sudo/               (1 file)  - sudo aliases
├── tmux/               (1 file)  - tmux commands
├── update/             (1 file)  - System update
├── uuid/               (1 file)  - UUID generation
└── wget/               (1 file)  - wget commands
```

---

## Proposed Consolidation: 6 Groups

### Group 1: Core (Essential for most users)
**Purpose:** Navigation, file management, basic commands  
**Includes:**
- cd/ → Core directory navigation
- chmod/ → Permission management
- mkdir/ → Directory creation
- clear/ → Screen clearing
- list/ → ls variations (list)

**Expected size:** ~200-300 lines  
**Load priority:** HIGH (always load)

### Group 2: Productivity (Development & version control)
**Purpose:** Development workflow tools  
**Includes:**
- git/ → Git commands (544 lines)
- configuration/ → Config management
- editor/ → Editor shortcuts
- make/ → Build system
- find/ → Find variations
- rsync/ → File sync

**Expected size:** ~800-1000 lines  
**Load priority:** HIGH (usually needed)

### Group 3: Utilities (System & file operations)
**Purpose:** System administration and utilities  
**Includes:**
- archives/ → Tar, zip, extract
- disk-usage/ → Disk space
- permission/ → Permission aliases
- ps/ → Process listing
- tmux/ → tmux commands
- dig/ → DNS utilities
- wget/ → Download utilities

**Expected size:** ~600-800 lines  
**Load priority:** MEDIUM (occasionally needed)

### Group 4: Development (Language-specific)
**Purpose:** Language/framework specific tools  
**Includes:**
- python/ → Python commands
- npm/ → npm/Node.js
- pnpm/ → pnpm package manager
- rust/ → Rust/cargo
- docker/ → Docker commands

**Expected size:** ~400-500 lines  
**Load priority:** MEDIUM (project specific)

### Group 5: Cloud & Deployment
**Purpose:** Cloud platforms and deployment tools  
**Includes:**
- heroku/ → Heroku platform (1053 lines)
- gcloud/ → Google Cloud (335 lines)

**Expected size:** ~1400 lines  
**Load priority:** LOW (project specific, can lazy-load)

### Group 6: System & Platform-Specific
**Purpose:** System administration and platform-specific  
**Includes:**
- sudo/ → sudo aliases
- update/ → System updates
- uuid/ → UUID generation
- interactive/ → Interactive commands
- gnu/ → GNU tool wrappers
- subversion/ → SVN commands
- macOS/ → macOS specific
- security/ → Security commands (744 lines)

**Expected size:** ~1000-1200 lines  
**Load priority:** LOW-MEDIUM (depends on system)

---

## Implementation Strategy

### Phase 1: Planning & Validation
1. Map all aliases in each directory
2. Test dependencies between alias modules
3. Verify no conflicts when consolidating
4. Create backup of current structure

### Phase 2: Create New Structure
1. Create lib/aliases/01-core.sh
2. Create lib/aliases/02-productivity.sh
3. Create lib/aliases/03-utilities.sh
4. Create lib/aliases/04-development.sh
5. Create lib/aliases/05-cloud.sh
6. Create lib/aliases/06-system.sh

### Phase 3: Migrate Aliases
1. Extract aliases from source directories
2. Concatenate into new consolidated files
3. Remove duplicate aliases (if any)
4. Maintain comments and organization

### Phase 4: Testing
1. Source new files in Bash → verify all aliases work
2. Source new files in Zsh → verify all aliases work
3. Test with cache disabled → ensure no caching issues
4. Test startup time before/after

### Phase 5: Deprecation
1. Keep old directories as deprecated
2. Update lib/aliases.sh to source new files
3. Add migration guide for users
4. Plan for removal in future version

### Phase 6: Documentation
1. Update lib/aliases/README.md
2. Update docs/INDEX.md
3. Document migration path
4. Note performance implications

---

## Risk Assessment

### High Risk Items
- **Dependency issues:** Some aliases might depend on others
- **Breakage:** Consolidation could break existing workflows
- **User confusion:** Existing scripts might reference old paths
- **Performance:** Larger files might load slower (offset by lazy loading)

### Mitigation Strategies
1. **Extensive testing** in both Bash and Zsh
2. **Keep old structure initially** (parallel loading)
3. **Fallback mechanism** - can easily revert
4. **Clear documentation** of changes
5. **Use lazy loading** for Group 5 (Cloud) by default

### Testing Plan
```bash
# Test each new group loads correctly
for group in 01-core 02-productivity 03-utilities 04-development 05-cloud 06-system; do
    bash -c "source ~/.dotfiles/lib/aliases/$group.sh && echo '$group: OK'" || echo "$group: FAILED"
done

# Test all aliases accessible
bash -c "source ~/.dotfiles/lib/aliases/*.sh && alias | wc -l"

# Test no conflicts
bash -c "source ~/.dotfiles/lib/aliases/*.sh 2>&1 | grep -i error"

# Measure startup time
time bash -i -c 'exit'
```

---

## Rollback Plan

If consolidation causes issues:
1. Revert lib/aliases.sh to source old directories
2. Keep new consolidated files as optional alternative
3. Document issues encountered
4. Plan for future iteration

---

## Performance Impact

### Before Consolidation
- 35 separate files loaded in sequence
- Each file requires individual shell parsing
- Slower I/O (35 file opens)

### After Consolidation  
- 6 consolidated files
- Faster I/O (6 file opens vs 35)
- Slightly larger file sizes (offset by lazy loading)
- Potential startup improvement: 10-15%

### With Lazy Loading (Phase D)
- Group 5 (Cloud) lazy-loaded → saves ~250ms
- Additional improvement when combined

---

## Success Criteria

✅ All 3000+ aliases work in both Bash and Zsh  
✅ No broken dependencies  
✅ Startup time maintains or improves  
✅ Clear documentation provided  
✅ Fallback/rollback plan in place  
✅ Backward compatible (with deprecation notice)

---

## Timeline

- **Phase 1:** 30 minutes (planning)
- **Phase 2-3:** 1 hour (consolidation)
- **Phase 4:** 1 hour (testing)
- **Phase 5-6:** 30 minutes (documentation)
- **Total:** ~3 hours for complete implementation

---

## Notes

- This is HIGH RISK and requires careful testing
- Can be done incrementally (consolidate one group at a time)
- Lazy loading (Phase D) complements this well
- Consider making user configurable (old vs new structure)
- Document thoroughly for future maintainers

---

**Status:** PLAN READY FOR REVIEW  
**Recommendation:** Proceed with caution, test thoroughly
