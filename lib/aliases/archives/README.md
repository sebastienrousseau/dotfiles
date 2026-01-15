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

## 🅰🆁🅲🅷🅸🆅🅴 🅰🅽🅳 🅲🅾🅼🅿🆁🅴🆂🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂

This module provides comprehensive tools for handling various archive and
compression formats.

### Universal Extract Function

The `extract` (or shorthand `x`) command automatically handles various archive formats:

```bash
extract archive.tar.gz  # Automatically detects format and extracts
```

Supported formats:

- `.tar.bz2`, `.tbz2`
- `.tar.gz`, `.tgz`
- `.tar.xz`
- `.tar.zst`
- `.tar`
- `.bz2`
- `.gz`
- `.rar`
- `.zip`
- `.Z`
- `.7z`
- `.zst`
- `.xz`
- `.lz4`
- `.lha`, `.lzh`
- `.arj`
- `.arc`
- `.dms`

### Advanced Compression Function

The new `compress` function (shorthand `c`) provides a unified interface for all compression formats with support for compression levels and multiple files:

```bash
compress tgz file1 file2 directory output.tar.gz  # Create tar.gz with multiple inputs
compress zip -l 9 important_files backup.zip      # Create zip with maximum compression level
```

Supported formats: `tar`, `tgz`, `tbz2`, `txz`, `tzst`, `zip`, `7z`, `gz`, `bz2`, `xz`, `zst`, `lz4`, `rar`

### Quick Backup Function

The `backup` (or shorthand `b`) function creates timestamped backups of files or directories:

```bash
backup important_folder            # Creates important_folder-backup-20250312-123045.tar.gz
backup database.sql zip            # Creates database.sql-backup-20250312-123045.zip
```

### Archive Content Listing

The `list_archive` (or shorthand `la`) function displays the contents of any supported archive:

```bash
list_archive backup.tar.gz         # Lists all files in the archive
```

### Large File Compression (Legacy)

The `compress_large` (shorthand `cl`) function is maintained for backward compatibility:

```bash
compress_large gz largefile.dat    # Creates largefile.dat.gz
compress_large xz data.bin output.xz  # Specific output name
```

### Archive Tools

#### 7-Zip Aliases

- `c7z` - Create 7z archive
- `x7z` - Extract 7z archive
- `l7z` - List contents

#### Tar Aliases

- `ctar` - Create tar archive
- `xtar` - Extract tar archive
- `ltar` - List contents
- `ctgz` - Create tar.gz archive
- `xtgz` - Extract tar.gz archive
- `ltgz` - List tar.gz contents
- `ctbz` - Create tar.bz2 archive
- `xtbz` - Extract tar.bz2 archive
- `ltbz` - List tar.bz2 contents
- `ctxz` - Create tar.xz archive
- `xtxz` - Extract tar.xz archive
- `ltxz` - List tar.xz contents
- `ctzst` - Create tar.zst archive
- `xtzst` - Extract tar.zst archive
- `ltzst` - List tar.zst contents

#### Zip Aliases

- `czip` - Create zip archive
- `xzip` - Extract zip archive
- `lzip` - List contents

#### RAR Aliases

- `crar` - Create rar archive
- `xrar` - Extract rar archive
- `lrar` - List contents

### Compression Tools

#### Gzip

- `cgz` - Compress with gzip
- `xgz` - Extract gzip

#### Bzip2

- `cbz` - Compress with bzip2
- `xbz` - Extract bzip2

#### XZ

- `cxz` - Compress with xz
- `xxz` - Extract xz

#### Zstandard

- `czst` - Compress with zstd
- `xzst` - Extract zstd

#### LZ4

- `clz4` - Compress with lz4
- `xlz4` - Extract lz4

### Enhanced Features

- Automatic format detection
- Tab completion for commands
- Robust error handling with logging
- File and directory name handling with spaces
- Progress indicators for large files (when `pv` is available)
- Multi-file input support
- Compression level options
- Archive integrity checking
- Content listing for all formats
- Timestamped backups
- Cross-platform compatibility

### Usage Examples

```bash
# Extract any supported archive
extract archive.tar.gz
# or use the shorthand
x archive.tar.gz

# List contents of any archive
list_archive archive.zip
# or use the shorthand
la archive.zip

# Create a tar.gz archive with multiple files
compress tgz file1.txt file2.txt docs/ archive.tar.gz

# Create a zip archive with maximum compression
compress zip -l 9 important/ backup.zip

# Create a timestamped backup
backup project_folder
# or with a specific format
backup database.sql 7z

# Compress a large file with progress indication (requires pv)
compress gz -l 9 largefile.dat compressed.gz

# Legacy large file compression
compress_large xz largefile.dat

# Create a 7z archive with the alias
c7z archive.7z files/  # No additional parameters needed
```

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
