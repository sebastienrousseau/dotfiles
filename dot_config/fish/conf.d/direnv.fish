# Shadow vendor `/opt/homebrew/share/fish/vendor_conf.d/direnv.fish`.
# fish dedupes conf.d files by basename — user conf.d wins. Direnv is
# loaded lazily by `_dotfiles_async_init` in init.fish via `_cached_eval
# direnv hook fish`, avoiding the unconditional cost on every shell start.
