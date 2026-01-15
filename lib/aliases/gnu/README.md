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

## 🅶🅽🆄 🅲🅾🆁🅴🆄🆃🅸🅻🆂 🅰🅻🅸🅰🆂🅴🆂

This is a collection of aliases for the GNU Coreutils package, which is
a set of standard Unix utilities often included in Linux distributions.
These aliases allow for easier use of these utilities by providing
shorthand commands that replace the full utility name with a shorter
alias.

The aliases in this collection cover a wide range of utilities, from
basic file manipulation commands like "cp" and "rm" to more advanced
text processing commands like "awk" and "sed". There are also aliases
for various checksum and hash utilities like "md5sum" and "sha256sum".

## 🅰🅻🅸🅰🆂🅴🆂

### Basic file management utilities

- `basename` Strip directory and suffix from filenames.
- `cp` Copy files and directories.
- `dirname` Strip non-directory suffix from filenames.
- `ln` Create links between files.
- `loname` Print the name of the link.
- `ls` List directory contents.
- `mkdir` Create directories.
- `mkfifo` Make named pipes (FIFOs).
- `mknod` Make block or character special files.
- `mv` Move or rename files or directories.
- `pathchk` Check file name validity and portability.
- `pwd` Print working directory name.
- `readlink` Print resolved symbolic links or canonical file names.
- `realpath` Print the resolved physical path of the specified path.
- `rm` Remove files or directories.
- `rmdir` Remove empty directories.
- `unlink` Remove files or directories.

### File content manipulation utilities

- `awk` Pattern scanning and processing language.
- `cat` Concatenate and display files.
- `csplit` Split a file into context-determined pieces.
- `cut` Remove sections from each line of files.
- `diff` Compare files line by line.
- `fold` Wrap each input line to fit in specified width.
- `grep` Print lines matching a pattern.
- `head` Output the first part of files.
- `nl` Number lines of files.
- `paste` Merge lines of files.
- `patch` Apply a diff file to an original.
- `ptx` Produce a permuted index of file contents.
- `sed` Stream editor for filtering and transforming text.
- `sort` Sort lines of text files.
- `split` Split a file into pieces.
- `tail` Output the last part of files.
- `tr` Translate or delete characters.

### File checksum and encryption utilities

- `b2sum` Print or check BLAKE2 message digests.
- `cksum` Print CRC checksum and byte counts.
- `sha1sum` Print or check SHA1 message digests.
- `sha224sum` Print or check SHA224 message digests.
- `sha256sum` Print or check SHA256 message digests.
- `sha384sum` Print or check SHA384 message digests.
- `sha512sum` Print or check SHA512 message digests.

### Other file utilities

- `base32` Print or convert base32 data.
- `base64` Encode or decode base64 data.
- `basenc` Encode or decode base64, base32,

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
