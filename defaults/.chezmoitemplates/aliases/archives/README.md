# Archives Aliases

Manage archive and compression aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `archives.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category), after every other core category.

## Aliases

`extract` (shorthand `x`) detects the format from the file name. `list_archive` (`lar`) lists any supported archive, `compress` (`ac`) creates one from several inputs, `compress_large` (`acl`) compresses one large file, and `backup` (`bak`) writes a timestamped archive. Run any of them with no arguments for its usage. Operations are logged to `$ARCHIVE_LOG_FILE` (default `~/.archive_operations.log`).

| Name | Definition | Notes |
| --- | --- | --- |
| `extract` | function | `extract <archive>`: unpack any supported archive, detecting the format from the name. |
| `list_archive` | function | `list_archive <archive>`: list the contents of any supported archive. |
| `compress` | function | `compress <format> [-l <1-9>] <inputs...> [output]`: formats tar, tgz, tbz2, txz, tzst, zip, 7z, gz, bz2, xz, zst, lz4, rar. |
| `compress_large` | function | `compress_large <format> <input> [output]`: compress one file with gz, bz2, xz, zst or lz4 (output defaults to `<input>.<format>`). |
| `backup` | function | `backup <file-or-dir> [format]`: write `<name>-backup-<timestamp>` as tgz (default), tbz2, txz, tzst, zip or 7z. |
| `zap` | `dot_confirm_destructive "rm -vi (zap)" && rm -vi` | Asks for confirmation, then removes interactively and verbosely. Only when `DOTFILES_SAFE_ALIASES=1`. |
| `x` | `extract` | Extract any supported archive with `extract`. |
| `l7z` | `7z l` | List 7z archive contents. |
| `ltar` | `tar -tvf` | List tar archive contents. |
| `ltgz` | `tar -tzvf` | List tar.gz archive contents. |
| `ltbz` | `tar -tjvf` | List tar.bz2 archive contents. |
| `ltxz` | `tar -tJvf` | List tar.xz archive contents. |
| `ltzst` | `tar --zstd -tvf` | List tar.zst archive contents. |
| `lzip` | `unzip -l` | List zip archive contents. |
| `lrar` | `unrar l` | List rar archive contents. Only when `unrar` is on PATH. |
| `lar` | `list_archive` | Generic list archive contents. |
| `c7z` | `7z a` | Create 7z archive. |
| `x7z` | `7z x` | Extract 7z archive. |
| `ctar` | `tar -cvf` | Create tar archive. |
| `xtar` | `tar -xvf` | Extract tar archive. |
| `ctgz` | `tar -zcvf` | Create tar.gz archive. |
| `xtgz` | `tar -zxvf` | Extract tar.gz archive. |
| `ctbz` | `tar -jcvf` | Create tar.bz2 archive. |
| `xtbz` | `tar -jxvf` | Extract tar.bz2 archive. |
| `ctxz` | `tar -Jcvf` | Create tar.xz archive. |
| `xtxz` | `tar -Jxvf` | Extract tar.xz archive. |
| `ctzst` | `tar --zstd -cvf` | Create tar.zst archive. |
| `xtzst` | `tar --zstd -xvf` | Extract tar.zst archive. |
| `czip` | `zip -r` | Create zip archive. |
| `xzip` | `unzip` | Extract zip archive. |
| `crar` | `rar a` | Create rar archive. Only when `rar` is on PATH. |
| `xrar` | `unrar x` | Extract rar archive. Only when `unrar` is on PATH. |
| `cgz` | `gzip -cv` | Compress with gzip. |
| `xgz` | `gzip -dv` | Extract gzip. |
| `cbz` | `bzip2 -zk` | Compress with bzip2. |
| `xbz` | `bzip2 -dk` | Extract bzip2. |
| `cxz` | `xz -z` | Compress with xz. |
| `xxz` | `xz -d` | Extract xz. |
| `czst` | `zstd -z` | Compress with zstd. |
| `xzst` | `zstd -d` | Extract zstd. |
| `clz4` | `lz4 -zc` | Compress with lz4. |
| `xlz4` | `lz4 -dc` | Extract lz4. |
| `ac` | `compress` | Generic compression (Archive Create) |
| `acl` | `compress_large` | Legacy compress_large. |
| `bak` | `backup` | Quick backup function. |

### Shell differences

The function layer (`~/.config/shell/51-logic-functions-extra.sh`) defines loader stubs named `extract` and `backup` for the files in `.chezmoitemplates/functions/files/`. Bash sources that layer before the alias layers, so the functions above win. Zsh sources it after the alias layers, so the stubs replace them:

- `backup` becomes the version in `functions/files/backup.sh`.
- `extract`, and so `x`, currently fails in zsh: the stub loads `functions/files/extract.sh`, whose `declare -f extract` guard sees the stub and skips its own definition, and the stub then calls itself again.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
