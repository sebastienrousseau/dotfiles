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

## 🅰🆁🅲🅷🅸🆅🅴🆂 🅰🅻🅸🅰🆂🅴🆂

This code provides a set of command aliases to help users compress and
extract files and directories in various formats on a Unix-based system.

The following compression formats are supported:

* 7z
* bzip2
* gzip
* jar
* lz4
* lzma
* lzo
* pigz
* tar
* xz
* zstd
* zip

These aliases enable users to compress or extract files and directories
quickly by using simple commands. Here are examples for each operation:

* To compress a directory to a 7z file: `compress_7z <archive_name.7z> <directory>`
* To extract from a 7z file: `extract_7z <archive_name.7z>`

Similar commands apply for all supported formats, ensuring ease of use.

**New Features:**

* Defensive coding practices ensure aliases are only defined if the required
archive programs are present, improving the script's robustness.
* Enhanced portability with updates to support a wider range of archive formats
and systems.

Please note that some of the compression formats may require additional
software to be installed on your system.

Enjoy the convenience of quickly compressing and extracting files and
directories with these command aliases!

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
