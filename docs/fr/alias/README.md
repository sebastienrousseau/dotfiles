# Aliases

Aliases allow you to create shortcuts for shell commands that you use
frequently. As an example, instead of typing `git status` you could type `gst`
to obtain the same result.

This is a great way to save time and reduce considerably the amount of typing
you have to do when using the terminal on a daily basis which helps you to be
more productive and efficient.

## 💻 Presets

Dotfiles has a collection of configuration presets and diverse recipes that you
can use to get started with.

### ❯ Automatic System detection

Dotfiles contains a utility function for detecting the current `ls` flavor that
is in use in order to help setting up the right `LS_COLORS` environment
variables to your system.

The `LS_COLORS` environment variable is used by the `ls` command to colorize the
output of the command.

### ❯ Check built-in aliases

Type the following alias command in your terminal:

```bash
alias
```

### ❯ GNU Find utilities aliases

macOS systems are based on BSD, rather than on GNU/Linux like RedHat, Debian,
and Ubuntu. As a result, a lot of the command line tools that ship with macOS
aren’t 100% compatible. For example, the `find` command on macOS doesn’t support
the `-printf` option, which is used by the `locate` command. This means that the
`locate` command doesn’t work on macOS. To fix this, you can install the GNU
versions of these commands, which are fully compatible with the Linux versions.

The GNU Find Utilities are the basic directory searching utilities of the GNU
operating system. These programs are typically used in conjunction with other
programs to provide modular and powerful directory search and file locating
capabilities to other commands.

The tools supplied with this package are:

- find - search for files in a directory hierarchy
- locate - list files in databases that match a pattern
- updatedb - update a file name database
- xargs - build and execute command lines from standard input

Type the following alias command in your terminal:

```bash
brew install findutils
```

### ❯ The Dotfiles aliases

The files provided in Dotfiles contain a few opinionated aliases that you might
find useful. These are defined in the `./dist/lib/aliases` directory and loaded
automatically when you start a new shell session.

The aliases are loaded either by the `~/.bashrc` file if you are using the Bash
shell, or in the `~/.zshrc` file if you are using the Zsh shell.

They have been grouped by logical categories:

- [default][default] - The default aliases that are loaded for all users,
  regardless of the shell they are using, and of the operating system they are
  on,
- [gcloud][gcloud] - The aliases for the Google Cloud SDK,
- [git][git] - The aliases for the Git version control system,
- [heroku][heroku] - The aliases for the Heroku Platform,
- [jekyll][jekyll] - The aliases for the Jekyll static site generator,
- [pnpm][pnpm] - The aliases for the pnpm package manager,
- [subversion][subversion] - The aliases for the Subversion version control
  system,
- [tmux][tmux] - The aliases for the tmux terminal multiplexer.

[default]: ./default/
[gcloud]: ./gcloud/
[git]: ./git/
[heroku]: ./heroku/
[jekyll]: ./jekyll/
[pnpm]: ./pnpm/
[subversion]: ./subversion/
[tmux]: ./tmux/
