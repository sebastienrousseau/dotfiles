# Shadow vendor `/opt/homebrew/share/fish/vendor_conf.d/mise-activate.fish`.
# fish dedupes conf.d files by basename — user conf.d wins. Mise is loaded
# lazily by `_dotfiles_async_init` in init.fish via `_cached_eval mise
# activate fish`, which is ~10× faster than the vendor's eager hook-env
# call on every shell start (saves ~140ms in fish startup).
