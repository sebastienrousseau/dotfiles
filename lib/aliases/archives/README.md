<!-- markdownlint-disable MD033 MD041 MD043 -->
<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>
<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.469)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🅰🆁🅲🅷🅸🆅🅴 🅰🅽🅳 🅲🅾🅼🅿🆁🅴🆂🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂

This module provides comprehensive tools for handling various archive and
compression formats.

### Universal Extract Function

The `extract` command automatically handles various archive formats:

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

### Large File Compression

The `compress_large` function handles large file compression with streaming:

```bash
compress_large gz largefile.dat  # Creates largefile.dat.gz
compress_large xz data.bin output.xz  # Specific output name
```

Supported formats: `gz`, `bz2`, `xz`, `zst`, `lz4`

### Archive Tools

#### 7-Zip Aliases

- `a7z` - Create 7z archive
- `x7z` - Extract 7z archive
- `l7z` - List contents
- `t7z` - Test integrity

#### Tar Aliases

- `ctar` - Create tar archive
- `xtar` - Extract tar archive
- `ltar` - List contents
- `ctgz` - Create tar.gz archive
- `xtgz` - Extract tar.gz archive
- `ctbz` - Create tar.bz2 archive
- `xtbz` - Extract tar.bz2 archive
- `ctxz` - Create tar.xz archive
- `xtxz` - Extract tar.xz archive
- `ctzst` - Create tar.zst archive
- `xtzst` - Extract tar.zst archive

#### Zip Aliases

- `czip` - Create zip archive
- `xzip` - Extract zip archive
- `lzip` - List contents

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

### Features

- Automatic format detection
- Tab completion for the extract command
- Error handling with helpful messages
- Large file support with streaming
- Archive integrity checking
- Content listing
- Cross-platform compatibility

### Usage Examples

```bash
# Extract any supported archive
extract archive.tar.gz

# Create a tar.gz archive
ctgz output.tar.gz folder/

# List contents of a zip file
lzip archive.zip

# Compress a large file
compress_large xz largefile.dat

# Create a 7z archive with maximum compression
a7z a -mx=9 archive.7z files/

# Test archive integrity
t7z archive.7z
```

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
