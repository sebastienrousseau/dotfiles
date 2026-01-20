# shellcheck shell=bash
# Kubernetes Aliases

# Check if kubectl is installed
if command -v kubectl &>/dev/null; then
  alias k='kubectl'
  
  # Core
  alias kg='kubectl get'
  alias kgp='kubectl get pods'
  alias kga='kubectl get all'
  alias kd='kubectl describe'
  alias kdel='kubectl delete'
  alias kl='kubectl logs'
  alias kex='kubectl exec -it'
  
  # Context / Namespace
  alias kcx='kubectl config get-contexts'
  alias kuse='kubectl config use-context'
  alias kns='kubectl config set-context --current --namespace'
  
  # Apply / File
  alias kaf='kubectl apply -f'
  alias kdf='kubectl delete -f'
fi

# Helm
if command -v helm &>/dev/null; then
  alias h='helm'
  alias hi='helm install'
  alias hu='helm upgrade'
  alias hls='helm list'
  alias hrm='helm uninstall'
fi

# k9s
if command -v k9s &>/dev/null; then
  alias k9='k9s'
fi
