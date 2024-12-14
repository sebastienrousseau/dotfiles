<!-- markdownlint-disable MD033 MD041 MD043 -->
<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="Dotfiles logo"
  width="66"
  align="right"
/>
<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.469)

**Seamlessly enhance your shell environment 🐚**

![Dotfiles banner][banner]

---

## 🚀 Introduction

This repository includes a robust set of shell aliases and scripts designed to streamline your command-line experience. The `cd` aliases script simplifies filesystem navigation with:

- **Dynamic error handling**
- **Automatic directory listing**
- **Customizable paths for frequent directories**

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

Quickly access frequently used directories with predefined shortcuts. You can customize these paths to fit your needs:

| Alias | Directory Path          | Description            |
|-------|--------------------------|------------------------|
| `app` | `${HOME}/Applications`  | Applications directory |
| `cod` | `${HOME}/Code`          | Code directory         |
| `des` | `${HOME}/Desktop`       | Desktop directory      |
| `doc` | `${HOME}/Documents`     | Documents directory    |
| `dot` | `${HOME}/.dotfiles`     | Dotfiles directory     |
| `dow` | `${HOME}/Downloads`     | Downloads directory    |
| `mus` | `${HOME}/Music`         | Music directory        |
| `pic` | `${HOME}/Pictures`      | Pictures directory     |
| `vid` | `${HOME}/Videos`        | Videos directory       |

---

### 🔧 System Directories

Effortlessly navigate to critical system directories:

| Alias | Directory Path | Description                    |
|-------|----------------|--------------------------------|
| `etc` | `/etc`         | System configuration directory |
| `var` | `/var`         | Variable files directory       |
| `tmp` | `/tmp`         | Temporary files directory      |

---

### ⚙️ Enhanced Customization

- **Dynamic Directory Paths**: Customize aliases through environment variables
- **Error Handling**: Provides clear messages for invalid directories
- **Optional Directory Listing**: Automatically lists contents after navigation
- **Tab Completion**: Supports custom tab completion for aliases

---

## 📦 Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/sebastienrousseau/dotfiles.git
   ```

2. **Source the script in your shell configuration**:

   ```bash
   echo 'source /path/to/dotfiles/cd.sh' >> ~/.bashrc
   ```

3. **Reload your shell**:

   ```bash
   source ~/.bashrc
   ```

---

## 🧑‍💻 Usage

Here are some examples of how you can use the `cd` aliases:

```bash
# Navigate to the Code directory
cod

# Ascend two levels in the directory tree
...

# Access the Documents directory
doc

# Navigate to the system configuration directory
etc
```

---

## 📚 Documentation

For advanced configuration and detailed usage examples, visit the [official documentation](https://dotfiles.io).

---

## 🛡️ License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👨‍💻 Author

Created with ♥ by [Sebastien Rousseau](https://sebastienrousseau.com)

- Website: [https://sebastienrousseau.com](https://sebastienrousseau.com)
- GitHub: [https://github.com/sebastienrousseau](https://github.com/sebastienrousseau)

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
