# Configuration Aliases

Open common configuration files in `$EDITOR`. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `configuration.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `dot` | `$HOME/.local/bin/dot` | Points `dot` at `~/.local/bin/dot`. Only when that file is executable. |
| `edit_apache_config` | `${EDITOR} /etc/apache2/apache2.conf` | Open Apache configuration file in default text editor. Only when file `/etc/apache2/apache2.conf` exists. |
| `edit_bashrc` | `${EDITOR} $HOME/.bashrc` | Open Bash configuration file in default text editor. |
| `edit_bash_profile` | `${EDITOR} $HOME/.bash_profile` | Open Bash profile in default text editor. |
| `edit_docker_compose` | `${EDITOR} docker-compose.yml` | Open Docker Compose file in default text editor. |
| `edit_current_directory` | `${EDITOR} .` | Open current directory in default text editor. |
| `eddot` | `${EDITOR} $HOME/.dotfiles` | Open the dotfiles source directory. |
| `edit_git_config` | `${EDITOR} $HOME/.gitconfig` | Open Git configuration file in default text editor. |
| `edit_git_ignore` | `${EDITOR} $HOME/.gitignore` | Open Git ignore file in default text editor. |
| `edit_hosts` | `${EDITOR} /etc/hosts` | Open hosts file in default text editor (cross-platform) Only when file `/etc/hosts` exists. |
| `edit_nginx_config` | `${EDITOR} /etc/nginx/nginx.conf` | Open Nginx configuration file in default text editor. Only when file `/etc/nginx/nginx.conf` exists. |
| `edit_ssh_config` | `${EDITOR} $HOME/.ssh/config` | Open SSH configuration file in default text editor. |
| `edit_zshrc` | `${EDITOR} $HOME/.zshrc` | Open Zsh configuration file in default text editor. |
| `edit_zsh_profile` | `${EDITOR} $HOME/.zsh_profile` | Open Zsh profile in default text editor. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
