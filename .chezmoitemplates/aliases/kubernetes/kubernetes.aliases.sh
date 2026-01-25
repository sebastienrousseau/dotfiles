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

# kubectx / kubens - context and namespace switcher
if command -v kubectx &>/dev/null; then
  alias kctx='kubectx'
  alias kctxc='kubectx -c'  # Current context
fi

if command -v kubens &>/dev/null; then
  alias kn='kubens'
  alias knc='kubens -c'  # Current namespace
fi

# stern - log tailer
if command -v stern &>/dev/null; then
  alias klog='stern'
  alias klogs='stern --since 1h'
  alias klogsf='stern --tail 100'
fi

# kube-linter - manifest linter
if command -v kube-linter &>/dev/null; then
  alias klint='kube-linter lint'
  alias klintc='kube-linter lint --config'
fi

# kubesec - security scanner
if command -v kubesec &>/dev/null; then
  alias ksec='kubesec scan'
fi

# minikube
if command -v minikube &>/dev/null; then
  alias mk='minikube'
  alias mkstart='minikube start'
  alias mkstop='minikube stop'
  alias mkstatus='minikube status'
  alias mkdash='minikube dashboard'
  alias mkip='minikube ip'
  alias mkssh='minikube ssh'
fi

# Helm
if command -v helm &>/dev/null; then
  # alias h='helm' # Reserved for history
  alias hi='helm install'
  alias hu='helm upgrade'
  alias hls='helm list'
  alias hrm='helm uninstall'
  alias hrepo='helm repo'
  alias hsearch='helm search repo'
fi

# k9s
if command -v k9s &>/dev/null; then
  alias k9='k9s'
fi
