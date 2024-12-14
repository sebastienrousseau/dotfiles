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

This code provides a set of miscellaneous functions to enhance your
shell experience and productivity.

The functions are organized by category and are listed below.

## 🅵🆄🅽🅲🆃🅸🅾🅽🆂 🅻🅸🆂🆃

<!-- markdownlint-disable MD013-->

### Navigation elements

| Function | Description | Usage |
| :--- | :--- | :--- |
| `cdls` | Function to combine cd and ls. | `cdls <path>` |
| `goto` | Function to change to the directory inputed. | `goto <path>` |

### Web Related Functions

| Function | Description | Usage |
| :--- | :--- | :--- |
| `curlheader` | Function to return only a specific response header or all response headers for a given URL. | `curlheader <url> [<header>]` |
| `curlstatus` | Function to return only the HTTP status code for a given URL. | `curlstatus <url>` |
| `curltime` | Function to return only the time it took to execute a given URL. | `curltime <url>` |
| `httpdebug` | Function to download a web page and show info on what took time. | `httpdebug <url>` |
| `view-source` | Function to view the source code of a web page. | `view-source <url>` |
| `whoisport` | Function to check if a port is open on a remote host. | `whoisport <host> <port>` |

### System Info and Utilities Functions

| Function | Description | Usage |
| :--- | :--- | :--- |
| `environment` | Function to detect the current environment. | `environment` |
| `extract` | Function to extract most know archives with one command. The supported file formats include: tar.bz2, tar.gz, bz2, rar, gz, tar, tbz2, tgz, zip, Z, and 7z. | `extract <file>` |
| `filehead` | Function to display the first lines of a file. | `filehead <file>` |
| `freespace` | Function to display the free space on the disk. | `freespace` |
| `genpwd` | Function to generates a strong random password of 20 characters (similar to Apple) | `genpwd` |
| `hidehiddenfiles` | Function to hide hidden files in Finder. | `hidehiddenfiles` |
| `hostinfo` | Function to display useful host related information. | `hostinfo` |
| `hstats` | Function to display Ze Shell history stats informaton (requires zsh). | `hstats` |
| `keygen` | Function to generates SSH key pairs. | `keygen <name> <email>` |
| `last` | List the modified files within 60 minutes. | `last` |
| `logout` | Function to logout from OS X via the Terminal. | `logout` |
| `lowercase` | Function to move filenames or directory names to lowercase. | `lowercase <file>` |
| `matrix` | Function to Enable Matrix Effect in the terminal. | `matrix` |
| `mount_read_only` | Function to mount a read-only disk image as read-write (OS X). | `mount_read_only <image>` |
| `myproc` | Function to list processes owned by an user.` | `myproc` |
| `prependpath` | Prepend $PATH without duplicates. | `prependpath <path>` |
| `ql` | Function to open any file in MacOS Quicklook Preview mode. | `ql <file>` |
| `rd` | Function to remove a directory and its files (OS X). | `rd <directory>` |
| `remove_disk` | Spin down unneeded disk drives (OS X). | `remove_disk <disk>` |
| `ren` | Function to rename files extension. | `ren <old> <new>` |
| `showhiddenfiles` | Function to show hidden files in Finder. | `showhiddenfiles` |
| `size` | Function to display the size of a file or total size of a directory. | `size <file>` |
| `stopwatch` | Function to measure the time it takes to execute a program. | `stopwatch <program>` |
| `uppercase` | Function to move filenames or directory names to uppercase. | `uppercase <file>` |
| `vsc` | Function to open a file or folder in Visual Studio Code. | `vsc <file>` |
| `zipf` | Function to zip a file. | `zipf <file>` |

<!-- markdownlint-enable MD013-->

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
