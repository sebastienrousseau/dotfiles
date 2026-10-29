# GNU Aliases

GNU coreutils aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `gnucoreutils.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `gdate` is on PATH.

Each alias maps a name to itself (`alias sed=sed`), so loading the file changes nothing: it does not point the names at the `g`-prefixed GNU tools that Homebrew installs on macOS.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `basename` | `basename` | Strip directory and suffix from filenames. |
| `dirname` | `dirname` | Strip non-directory suffix from filenames. |
| `loname` | `loname` | Print the name of the link. |
| `mkfifo` | `mkfifo` | Make named pipes (FIFOs). |
| `mknod` | `mknod` | Make block or character special files. |
| `pathchk` | `pathchk` | Check file name validity and portability. |
| `pwd` | `pwd` | Print working directory name. |
| `readlink` | `readlink` | Print resolved symbolic links or canonical file names. |
| `realpath` | `realpath` | Print the resolved physical path of the specified path. |
| `rmdir` | `rmdir` | Remove empty directories. |
| `unlink` | `unlink` | Remove files or directories. |
| `awk` | `awk` | Pattern scanning and processing language. |
| `csplit` | `csplit` | Split a file into context-determined pieces. |
| `cut` | `cut` | Remove sections from each line of files. |
| `fold` | `fold` | Wrap each input line to fit in specified width. |
| `grep` | `grep` | Print lines matching a pattern. |
| `head` | `head` | Output the first part of files. |
| `nl` | `nl` | Number lines of files. |
| `paste` | `paste` | Merge lines of files. |
| `patch` | `patch` | Apply a diff file to an original. |
| `ptx` | `ptx` | Produce a permuted index of file contents. |
| `sed` | `sed` | Stream editor for filtering and transforming text. |
| `sort` | `sort` | Sort lines of text files. |
| `split` | `split` | Split a file into pieces. |
| `tail` | `tail` | Output the last part of files. |
| `tr` | `tr` | Translate or delete characters. |
| `b2sum` | `b2sum` | Print or check BLAKE2 message digests. |
| `cksum` | `cksum` | Print CRC checksum and byte counts. |
| `sha1sum` | `sha1sum` | Print or check SHA1 message digests. |
| `sha224sum` | `sha224sum` | Print or check SHA224 message digests. |
| `sha256sum` | `sha256sum` | Print or check SHA256 message digests. |
| `sha384sum` | `sha384sum` | Print or check SHA384 message digests. |
| `sha512sum` | `sha512sum` | Print or check SHA512 message digests. |
| `base32` | `base32` | Print or convert base32 data. |
| `base64` | `base64` | Encode or decode base64 data. |
| `basenc` | `basenc` | Encode or decode data in base64, base32 and other encodings. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
