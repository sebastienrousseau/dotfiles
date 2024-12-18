<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles (v0.2.469)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

This code provides a set of miscellaneous functions to enhance your
shell experience and productivity.

The functions are organized by category and are listed below.

## 🅵🆄🅽🅲🆃🅸🅾🅽🆂 🅻🅸🆂🆃

<!-- markdownlint-disable MD013-->

### Navigation

| Function        | Description                            | Usage                |
| :-------------- | :------------------------------------- | :------------------- |
| `cdls`          | Combine `cd` and `ls` into one command. | `cdls <path>`       |
| `goto`          | Change to the specified directory.     | `goto <path>`       |

### API Utilities

| Function        | Description                                      | Usage                    |
| :-------------- | :----------------------------------------------- | :----------------------- |
| `apihealth`     | Check API health status.           | `apihealth <url>`       |
| `apilatency`    | Measure API latency.               | `apilatency <url>`      |
| `apiload`       | Analyze API load.                  | `apiload <url>`         |
| `curlheader`    | Fetch specific/all response headers for a URL.   | `curlheader <url> [<header>]` |
| `curlstatus`    | Fetch HTTP status code for a URL.                | `curlstatus <url>`      |
| `curltime`      | Measure time taken for a URL request.            | `curltime <url>`        |
| `httpdebug`     | Debug HTTP requests and measure timings.         | `httpdebug <url>`       |
| `whoisport`     | Check if a port is open on a remote host.        | `whoisport <host> <port>` |

### File Operations

| Function         | Description                                      | Usage                     |
| :--------------- | :----------------------------------------------- | :------------------------ |
| `encode64`       | Encode data in Base64 format.      | `encode64 <input>`       |
| `extract`        | Extract known archive formats.                  | `extract <file>`         |
| `hexdump`        | Display a hexadecimal dump of a file. | `hexdump <file>`    |
| `hiddenfiles`    | List hidden files in the current directory. | `hiddenfiles` |
| `kebabcase`      | Convert filenames to kebab-case.   | `kebabcase <file>`       |
| `lowercase`      | Convert filenames to lowercase.                 | `lowercase <file>`       |
| `prependpath`    | Add a directory to the `$PATH` environment variable. | `prependpath <path>` |
| `ren`            | Rename file extensions.                         | `ren <old> <new>`        |
| `showhiddenfiles`| Show hidden files in Finder (macOS).            | `showhiddenfiles`        |
| `snakecase`      | Convert filenames to snake_case.   | `snakecase <file>`       |
| `titlecase`      | Convert filenames to Title Case.   | `titlecase <file>`       |
| `uppercase`      | Convert filenames to uppercase.                 | `uppercase <file>`       |
| `zipf`           | Zip a file.                                     | `zipf <file>`            |

### System Information

| Function         | Description                                      | Usage                     |
| :--------------- | :----------------------------------------------- | :------------------------ |
| `backup`         | Create system backups.             | `backup`                 |
| `environment`    | Detect the current environment.                 | `environment`            |
| `freespace`      | Display free disk space.                        | `freespace`              |
| `hostinfo`       | Display host-related information.               | `hostinfo`               |
| `last`           | List files modified within the last 60 minutes. | `last`                   |
| `logout`         | Log out from the current session (macOS).       | `logout`                 |
| `matrix`         | Enable matrix effect in the terminal.           | `matrix`                 |
| `mount_read_only`| Mount a read-only disk image as read-write (macOS). | `mount_read_only <image>` |
| `myproc`         | List processes owned by the user.               | `myproc`                 |
| `size`           | Display size of a file or total directory size. | `size <file>`            |
| `stopwatch`      | Measure execution time of a program.            | `stopwatch <program>`    |
| `sysinfo`        | Display system information.        | `sysinfo`                |

### Miscellaneous

| Function         | Description                                      | Usage                     |
| :--------------- | :----------------------------------------------- | :------------------------ |
| `genpwd`         | Generate a strong random password.              | `genpwd`                 |
| `keygen`         | Generate SSH key pairs.                         | `keygen <name> <email>`  |
| `ql`             | Open any file in Quick Look preview (macOS).    | `ql <file>`              |
| `rd`             | Remove a directory and its files (macOS).       | `rd <directory>`         |
| `remove_disk`    | Spin down unneeded disk drives (macOS).         | `remove_disk <disk>`     |
| `vscode`         | Open a file or folder in Visual Studio Code.    | `vscode <file>`          |
| `view-source`    | View the source code of a web page.             | `view-source <url>`      |

<!-- markdownlint-enable MD013-->

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
