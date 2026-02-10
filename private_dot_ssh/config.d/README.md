# SSH Config.d

Drop per-host configs here as `*.conf`.

Example:

```
Host bastion
  HostName bastion.example.com
  User your_user
  IdentityFile ~/.ssh/id_ed25519

Host internal-*
  ProxyJump bastion
```

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
