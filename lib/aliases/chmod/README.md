<!-- markdownlint-disable MD033 MD041 MD043 -->
<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="Dotfiles logo"
  width="66"
  align="right"
/>
<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

---

## 🚀 Introduction

This script provides an enhanced set of shortcuts and functions for the
`chmod` command, making it easier to manage file and directory permissions.
With features like input validation, recursive confirmation, and user-friendly
aliases, you can efficiently customize permissions for files and directories.

---

## 🛠️ Features

### 🌟 Permission Aliases

Quickly apply common permission settings with pre-defined aliases:

| Alias        | Permissions      | Description                               |
|--------------|------------------|-------------------------------------------|
| `chmod_000`  | `----------`     | No permissions for anyone                 |
| `chmod_400`  | `r--------`      | Read-only for the owner                   |
| `chmod_444`  | `r--r--r--`      | Read-only for everyone                    |
| `chmod_600`  | `rw-------`      | Read/write for the owner                  |
| `chmod_644`  | `rw-r--r--`      | Read/write for the owner, read-only other |
| `chmod_666`  | `rw-rw-rw-`      | Read/write for everyone                   |
| `chmod_755`  | `rwxr-xr-x`      | Full owner, read/execute for others       |
| `chmod_764`  | `rwxrw-r--`      | Full owner, read/write for the group,     |
| `chmod_777`  | `rwxrwxrwx`      | Full permissions for everyone             |

---

### 🔧 Recursive Confirmation for Permissions

The `change_permission` function allows you to recursively apply permissions
with a confirmation prompt, displaying the number of items affected:

```bash
change_permission 755 /path/to/directory -R
```

---

### 📂 User, Group, and Others Shortcuts

Fine-tune permissions for specific user groups (owner, group, or others):

| Alias         | Description                                |
|---------------|--------------------------------------------|
| `chmod_u+x`   | Add execute permission for the owner       |
| `chmod_u-x`   | Remove execute permission for the owner    |
| `chmod_u+w`   | Add write permission for the owner         |
| `chmod_u-w`   | Remove write permission for the owner      |
| `chmod_u+r`   | Add read permission for the owner          |
| `chmod_u-r`   | Remove read permission for the owner       |
| `chmod_g+x`   | Add execute permission for the group       |
| `chmod_g-x`   | Remove execute permission for the group    |
| `chmod_g+w`   | Add write permission for the group         |
| `chmod_g-w`   | Remove write permission for the group      |
| `chmod_g+r`   | Add read permission for the group          |
| `chmod_g-r`   | Remove read permission for the group       |
| `chmod_o+x`   | Add execute permission for others          |
| `chmod_o-x`   | Remove execute permission for others       |
| `chmod_o+w`   | Add write permission for others            |
| `chmod_o-w`   | Remove write permission for others         |
| `chmod_o+r`   | Add read permission for others             |
| `chmod_o-r`   | Remove read permission for others          |

---

### 📄 Custom Aliases for File Types

Set permissions for specific file types with ease:

| Alias        | Description                                        |
|--------------|----------------------------------------------------|
| `chmod_755d` | Set permissions of all directories to `rwxr-xr-x`  |
| `chmod_644f` | Set permissions of all files to `rw-r--r--`        |

---

## 📦 Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/sebastienrousseau/dotfiles.git
   ```

2. Source the script in your shell configuration file:

   ```bash
   echo 'source /path/to/dotfiles/chmod.sh' >> ~/.bashrc
   ```

3. Reload your shell:

   ```bash
   source ~/.bashrc
   ```

---

## 🧑‍💻 Usage

Here are some examples of how to use the `chmod` aliases and functions:

- Apply common permissions:

  ```bash
  chmod_644 /path/to/file
  chmod_755 /path/to/directory
  ```

- Modify user, group, or others' permissions:

  ```bash
  chmod_u+x /path/to/script
  chmod_g-w /path/to/file
  chmod_o+r /path/to/file
  ```

- Recursively set permissions with confirmation:

  ```bash
  change_permission 755 /path/to/directory -R
  ```

---

## 🛡️ License

This project is licensed under the
[MIT License](https://opensource.org/licenses/MIT). See the `LICENSE` file for
more information.

---

## 👨‍💻 Author

Created with ♥ by [Sebastien Rousseau](https://sebastienrousseau.com)

- Website: [https://sebastienrousseau.com](https://sebastienrousseau.com)
- GitHub: [https://github.com/sebastienrousseau](https://github.com/sebastienrousseau)

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
