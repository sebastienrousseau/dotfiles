# shellcheck shell=bash
# Terraform & IaC Aliases

# Terraform
if command -v terraform &>/dev/null; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tfp='terraform plan'
  alias tfa='terraform apply'
  alias tfaa='terraform apply -auto-approve'
  alias tfd='terraform destroy'
  alias tfda='terraform destroy -auto-approve'
  alias tff='terraform fmt'
  alias tfv='terraform validate'
  alias tfo='terraform output'
  alias tfs='terraform state'
fi

# OpenTofu (Drop-in replacement support)
if command -v tofu &>/dev/null; then
  alias tofu='tofu'
  alias tip='tofu init && tofu plan'
fi

# Ansible
if command -v ansible &>/dev/null; then
  alias ans='ansible'
  alias ansp='ansible-playbook'
  alias ansg='ansible-galaxy'
  alias anslint='ansible-lint'
fi
