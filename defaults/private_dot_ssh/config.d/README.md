# SSH Config.d

Drop per-host configs in `~/.ssh/config.d/` as `*.conf`.

Note: `defaults/.chezmoiignore.tmpl` ignores both `.ssh/config` and
`.ssh/config.d`, so chezmoi deploys neither the generated
`~/.ssh/config` (from `config.tmpl`, which carries
`Include ~/.ssh/config.d/*.conf`) nor this directory. Create
`~/.ssh/config.d/` yourself and make sure your `~/.ssh/config` has that
`Include` line.

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

Made with ❤️ by [Sebastien Rousseau](https://sebastienrousseau.com)
