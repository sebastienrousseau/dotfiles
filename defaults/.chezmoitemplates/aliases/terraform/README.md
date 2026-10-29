# Terraform Aliases

Manage Infrastructure as Code aliases (Terraform, OpenTofu, Ansible). Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `terraform.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `tf` | `terraform` | Only when `terraform` is on PATH. |
| `tfi` | `terraform init` | Only when `terraform` is on PATH. |
| `tfp` | `terraform plan` | Only when `terraform` is on PATH. |
| `tfa` | `terraform apply` | Only when `terraform` is on PATH. |
| `tfaa` | `terraform apply -auto-approve` | Only when `terraform` is on PATH. |
| `tfd` | `terraform destroy` | Only when `terraform` is on PATH. |
| `tfda` | `terraform destroy -auto-approve` | Only when `terraform` is on PATH. |
| `tff` | `terraform fmt` | Only when `terraform` is on PATH. |
| `tfv` | `terraform validate` | Only when `terraform` is on PATH. |
| `tfo` | `terraform output` | Only when `terraform` is on PATH. |
| `tfs` | `terraform state` | Only when `terraform` is on PATH. |
| `tofu` | `tofu` | Only when `tofu` is on PATH. |
| `tip` | `tofu init && tofu plan` | Only when `tofu` is on PATH. |
| `ans` | `ansible` | Only when `ansible` is on PATH. |
| `ansp` | `ansible-playbook` | Only when `ansible` is on PATH. |
| `ansg` | `ansible-galaxy` | Only when `ansible` is on PATH. |
| `anslint` | `ansible-lint` | Only when `ansible` is on PATH. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
