# Kubernetes Aliases

Manage Kubernetes aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `kubernetes.aliases.sh` and are automatically loaded by `chezmoi`.

## Aliases

### core
- `k` - kubectl shortcut
- `kg` - `kubectl get`
- `kgp` - `kubectl get pods`
- `kga` - `kubectl get all`
- `kd` - `kubectl describe`
- `kdel` - `kubectl delete`
- `kl` - `kubectl logs`
- `kex` - `kubectl exec -it`

### context
- `kcx` - List contexts
- `kuse` - Switch context
- `kns` - Switch namespace

### helm
- `h` - Helm shortcut
- `hls` - List releases
- `hi` - Install chart

### ui
- `k9` - k9s terminal UI

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
