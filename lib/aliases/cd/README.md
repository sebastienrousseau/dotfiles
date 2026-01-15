<!-- markdownlint-disable MD033 MD041 MD043 -->
<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="Dotfiles logo"
  width="66"
  align="right"
/>
<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v1.1.0)

Seamlessly enhance your shell environment 🐚

![Dotfiles banner][banner]

---

## 🚀 Introduction

This repository includes a robust set of shell aliases and scripts designed to
streamline your command-line experience. The enhanced directory navigation system delivers:

- **Smart directory history tracking**
- **Persistent bookmarking system**
- **Project root detection**
- **Cross-platform compatibility**
- **Dynamic error handling**
- **Automatic directory listing**
- **Performance optimization for large directories**
- **Enhanced security and validation**

---

## 🛠️ Features

### 🌟 Navigation Shortcuts

| Alias           | Description                           |
|------------------|--------------------------------------|
| `-`             | Switch to the previous directory      |
| `..`, `...`     | Ascend one or two levels in the tree  |
| `....`, `.....` | Ascend three or four levels           |
| `hom`           | Navigate to the home directory (`~`)  |

---

### 📂 Custom Directory Access

Quickly access frequently used directories with consistent shortcuts:

| Alias | Directory Path          | Description            |
|-------|--------------------------|------------------------|
| `app` | `${HOME}/Applications`  | Applications directory |
| `cod` | `${HOME}/Code`          | Code directory         |
| `dsk` | `${HOME}/Desktop`       | Desktop directory      |
| `doc` | `${HOME}/Documents`     | Documents directory    |
| `dot` | `${HOME}/.dotfiles`     | Dotfiles directory     |
| `dwn` | `${HOME}/Downloads`     | Downloads directory    |
| `mus` | `${HOME}/Music`         | Music directory        |
| `pic` | `${HOME}/Pictures`      | Pictures directory     |
| `vid` | `${HOME}/Videos`        | Videos directory       |

---

### 📌 Bookmark System

Create and manage persistent bookmarks for any directory:

| Command             | Alias | Description                       |
|---------------------|-------|-----------------------------------|
| `bookmark [name]`   | `bm`  | Create bookmarks                 |
| `bookmark_list`     | `bml` | List all bookmarks               |
| `bookmark_update`   | `bmu` | Update existing bookmark         |
| `bookmark_remove`   | `bmr` | Delete a bookmark                |
| `goto <name>`       | `bmg` | Navigate to bookmarked directory |

```bash
# Create a bookmark for the current directory
bm work-project

# Navigate to the bookmarked directory from anywhere
bmg work-project

# List all bookmarks
bml
```

---

### 🕒 Directory History

Track and navigate to recently visited directories:

| Command      | Alias | Description                         |
|--------------|-------|-------------------------------------|
| `dirhistory` | `dh`  | Show and navigate history          |
| `lwd`        | `ld`  | Return to last working directory    |

---

### 🏗️ Advanced Navigation

| Command          | Alias | Description                                |
|------------------|-------|--------------------------------------------|
| `mkcd <dir>`     | `mk`  | Create and immediately enter directory    |
| `proj`           | `pr`  | Navigate to project root (Git, npm, etc.) |
| `pushd`          | `pd`  | Push directory onto stack                 |
| `popd`           |       | Pop directory from stack                   |
| `dirs`           |       | List directory stack with indices         |

---

### 🔧 System Directories

Effortlessly navigate to critical system directories:

| Alias | Directory Path | Description                    |
|-------|----------------|--------------------------------|
| `etc` | `/etc`         | System configuration directory |
| `var` | `/var`         | Variable files directory       |
| `tmp` | `/tmp`         | Temporary files directory      |
| `usr` | `/usr`         | User programs directory        |

---

### ⚙️ Enhanced Customization

- **Cross-Platform Support**: Works on macOS, Linux, and other Unix-like systems
- **Configurable Options**: Customize behavior through environment variables:

  ```bash
  # In your .bashrc or .zshrc
  export SHOW_HIDDEN_FILES=true        # Show hidden files in listings
  export ENABLE_COLOR_OUTPUT=true      # Enable colorized output
  export ENABLE_DIR_GROUPING=true      # Group directories first
  export AUTO_LIST_AFTER_CD=true       # List directory after navigation
  export LARGE_DIR_THRESHOLD=1000      # Skip listing for large dirs
  export MAX_RECENT_DIRS=15            # Number of dirs in history
  export RESTORE_LAST_DIR=true         # Restore last dir on shell start
  ```

- **Tab Completion**: Smart completion for bookmarks and commands
- **Help System**: Run `cdhelp` to view all available commands
- **Version Tracking**: Run `cdversion` to display version information

---

## 📦 Installation

1. **Clone the repository**:

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git
```

2. **Source the script in your shell configuration**:

```bash
echo 'source /path/to/dotfiles/cd.aliases.sh' >> ~/.bashrc
```

3. **Reload your shell**:

```bash
source ~/.bashrc
```

---

## 🧑‍💻 Usage Examples

```bash
# Navigate to a directory with history tracking
cd ~/projects/website

# Create a new directory and navigate to it
mk ~/projects/new-project

# Create a bookmark for current directory
bm website

# List all bookmarks
bml

# Navigate to a bookmarked directory
bmg website

# Find and navigate to project root
pr

# Create a directory structure and navigate to it
mk ~/projects/app/src/components

# View recent directory history
dh

# Return to previous working directory
ld

# Push current directory to stack and go to another
pd ~/downloads

# Return to the pushed directory
popd

# View version information
cdversion

# Display help information
cdhelp
```

---

## 🛡️ Security Features

The enhanced version includes improved security and validation:

- **Directory Validation**: All directories are checked for existence and permissions before navigation
- **Bookmark Validation**: Bookmark names are validated to prevent injection attacks
- **Safe File Operations**: File operations use secure methods to prevent corruption
- **Input Sanitation**: User inputs are validated before processing

---

## 📋 Performance Optimizations

- **Large Directory Handling**: Automatic directory listing is skipped for large directories to avoid performance issues
- **Improved Bookmark Storage**: Bookmarks are stored more efficiently
- **Duplicate Prevention**: Directory history prevents duplicate entries
- **Optimized File Operations**: File operations are optimized for speed and safety

---

## 📚 Documentation

For advanced configuration and detailed usage examples, run `cdhelp` or visit the
[official documentation](https://dotfiles.io).

---

## 🛡️ License

This project is licensed under the
[MIT License](https://opensource.org/licenses/MIT).

---

## 👨‍💻 Author

Created with ♥ by [Sebastien Rousseau](https://sebastienrousseau.com)

- Website: [https://sebastienrousseau.com](https://sebastienrousseau.com)
- GitHub: [https://github.com/sebastienrousseau](https://github.com/sebastienrousseau)

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
