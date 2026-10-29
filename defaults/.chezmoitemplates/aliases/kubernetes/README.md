# Kubernetes Aliases

Manage Kubernetes aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `kubernetes.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `k` | `kubectl` | Only when `kubectl` is on PATH. |
| `kg` | `kubectl get` | Only when `kubectl` is on PATH. |
| `kgp` | `kubectl get pods` | Only when `kubectl` is on PATH. |
| `kga` | `kubectl get all` | Only when `kubectl` is on PATH. |
| `kd` | `kubectl describe` | Only when `kubectl` is on PATH. |
| `kdel` | `kubectl delete` | Only when `kubectl` is on PATH. |
| `kl` | `kubectl logs` | Only when `kubectl` is on PATH. |
| `kex` | `kubectl exec -it` | Only when `kubectl` is on PATH. |
| `kcx` | `kubectl config get-contexts` | Only when `kubectl` is on PATH. |
| `kuse` | `kubectl config use-context` | Only when `kubectl` is on PATH. |
| `kns` | `kubectl config set-context --current --namespace` | Only when `kubectl` is on PATH. |
| `kaf` | `kubectl apply -f` | Only when `kubectl` is on PATH. |
| `kdf` | `kubectl delete -f` | Only when `kubectl` is on PATH. |
| `kctx` | `kubectx` | Only when `kubectx` is on PATH. |
| `kctxc` | `kubectx -c` | Current context. Only when `kubectx` is on PATH. |
| `kn` | `kubens` | Only when `kubens` is on PATH. |
| `knc` | `kubens -c` | Current namespace. Only when `kubens` is on PATH. |
| `klog` | `stern` | Only when `stern` is on PATH. |
| `klogs` | `stern --since 1h` | Only when `stern` is on PATH. |
| `klogsf` | `stern --tail 100` | Only when `stern` is on PATH. |
| `klint` | `kube-linter lint` | Only when `kube-linter` is on PATH. |
| `klintc` | `kube-linter lint --config` | Only when `kube-linter` is on PATH. |
| `ksec` | `kubesec scan` | Only when `kubesec` is on PATH. |
| `mkg` | `minikube` | Only when `minikube` is on PATH. |
| `mkstart` | `minikube start` | Only when `minikube` is on PATH. |
| `mkstop` | `minikube stop` | Only when `minikube` is on PATH. |
| `mkstatus` | `minikube status` | Only when `minikube` is on PATH. |
| `mkdash` | `minikube dashboard` | Only when `minikube` is on PATH. |
| `mkip` | `minikube ip` | Only when `minikube` is on PATH. |
| `mkssh` | `minikube ssh` | Only when `minikube` is on PATH. |
| `hm` | `helm` | Only when `helm` is on PATH. |
| `hi` | `helm install` | Only when `helm` is on PATH. |
| `hu` | `helm upgrade` | Only when `helm` is on PATH. |
| `hls` | `helm list` | Only when `helm` is on PATH. |
| `hrm` | `helm uninstall` | Only when `helm` is on PATH. |
| `hrepo` | `helm repo` | Only when `helm` is on PATH. |
| `hsearch` | `helm search repo` | Only when `helm` is on PATH. |
| `k9` | `k9s` | Only when `k9s` is on PATH. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
