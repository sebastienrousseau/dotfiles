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

---

## 🅻🅸🆂🆃 🅰🅻🅸🅰🆂🅴🆂

This script defines a set of aliases for enhanced file listing using `eza`, or
falls back to `ls` if `eza` is not installed. These aliases provide intuitive
shortcuts for various listing styles and sorting options.

### **Aliases Overview**

- **`ls`**  
  Replaces the standard `ls` command with `eza`. If `eza` is not available,
  falls back to the standard `ls`.

- **`l`**  
  Mirrors the behavior of `ls` or `eza`, ensuring consistent usage.

- **`ll`**  
  Lists files in a long format, including hidden files (`--long -a`).

- **`llm`**  
  Lists files in long format, including hidden files, sorted by modification
  date (`--long -a --sort=modified`).

- **`la`**  
  Lists all files, including hidden ones, with directories listed
  first (`-a --group-directories-first`).

- **`lx`**  
  Lists all files and displays extended attributes, with directories listed
  first (`-a --group-directories-first --extended`).

- **`tree`**  
  Displays a directory tree using `eza --tree`. If `eza` is unavailable,
  falls back to the `tree` command or `ls -R`.

- **`lS`**  
  Lists files one entry per line (`--oneline`).

---

### **Installation**

1. Clone this repository:

   ```bash
   git clone https://github.com/sebastienrousseau/dotfiles.git
   ```

2. Source the `list.sh` script in your shell configuration:

   ```bash
   echo 'source /path/to/dotfiles/list.sh' >> ~/.bashrc
   source ~/.bashrc
   ```

---

### **Usage Examples**

Here are examples of how you can use the aliases:

- **Basic Listing**:

  ```bash
  ls    # Basic file listing (uses eza if available)
  l     # Same as ls
  ```

- **Detailed Listing**:

  ```bash
  ll    # Long format with hidden files
  llm   # Long format, sorted by modification date
  ```

- **Specialized Listings**:

  ```bash
  la    # Show all files, directories first
  lx    # Show extended attributes, directories first
  lS    # One entry per line
  ```

- **Tree View**:

  ```bash
  tree  # Show directory structure as a tree
  ```

---

### **Fallback Behavior**

If `eza` is not installed, the script automatically falls back to
standard `ls` with equivalent options where possible. For example:

- **`ls` and `l`**: Use standard `ls` if `eza` is unavailable.
- **`tree`**: Falls back to `tree` if installed, or `ls -R` otherwise.

---

### **Customization**

You can adjust the aliases or add additional ones in the `list.sh` script.
For example, modify the default `tree` depth by editing:

```bash
alias tree='eza --tree --level=2'
```

---

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
