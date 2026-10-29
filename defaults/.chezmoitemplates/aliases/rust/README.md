# Rust Aliases

Manage Rust aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `rust.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `rust`.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `cg` | `cargo` | Cargo shortcut. Only when `cargo` is on PATH. |
| `cgn` | `cg new` | Create new binary project. Only when `cargo` is on PATH. |
| `cgni` | `cg new --lib` | Create new library project. Only when `cargo` is on PATH. |
| `cginit` | `cg init` | Initialize project in current directory. Only when `cargo` is on PATH. |
| `cgb` | `cg build` | Build debug. Only when `cargo` is on PATH. |
| `cgbr` | `cg build --release` | Build release. Only when `cargo` is on PATH. |
| `cgr` | `cg run` | Run debug. Only when `cargo` is on PATH. |
| `cgrr` | `cg run --release` | Run release. Only when `cargo` is on PATH. |
| `cgw` | `cg watch` | Watch and rebuild. Only when `cargo` is on PATH. |
| `cw` | `cargo watch -x run` | Live run loop. Only when `cargo` is on PATH. |
| `cgt` | `cg test` | Run tests. Only when `cargo` is on PATH. |
| `cgtr` | `cg test --release` | Run tests in release mode. Only when `cargo` is on PATH. |
| `cnt` | `cargo nextest run` | Faster nextest runner. Only when `cargo` is on PATH. |
| `cgbh` | `cg bench` | Run benchmarks. Only when `cargo` is on PATH. |
| `cgta` | `cg test --all` | Test all targets. Only when `cargo` is on PATH. |
| `cgtt` | `cg test -- --test-threads=1` | Single threaded tests. Only when `cargo` is on PATH. |
| `cgc` | `cg check` | Check compilation. Only when `cargo` is on PATH. |
| `cgcl` | `cg clean` | Clean build artifacts. Only when `cargo` is on PATH. |
| `cgcy` | `cg clippy` | Run clippy lints. Only when `cargo` is on PATH. |
| `cgf` | `cg fmt` | Format code. Only when `cargo` is on PATH. |
| `cnfmt` | `cargo +nightly fmt` | Nightly format. Only when `cargo` is on PATH. |
| `cgfa` | `cg fmt --all` | Format all code. Only when `cargo` is on PATH. |
| `cgfx` | `cg fix` | Auto-fix code issues. Only when `cargo` is on PATH. |
| `cgaud` | `cg audit` | Security vulnerabilities check. Only when `cargo` is on PATH. |
| `cnclip` | `cargo +nightly clippy` | Nightly clippy. Only when `cargo` is on PATH. |
| `cgd` | `cg doc --open` | Build and open documentation. Only when `cargo` is on PATH. |
| `cgdr` | `cg doc --release` | Build release documentation. Only when `cargo` is on PATH. |
| `cgdo` | `cg doc --document-private-items` | Document private items. Only when `cargo` is on PATH. |
| `cga` | `cg add` | Add dependency. Only when `cargo` is on PATH. |
| `cgad` | `cg add --dev` | Add dev dependency. Only when `cargo` is on PATH. |
| `cgu` | `cg update` | Update dependencies. Only when `cargo` is on PATH. |
| `cup` | `cargo update` | Update dependencies (short form) Only when `cargo` is on PATH. |
| `cgo` | `cg outdated` | Check outdated dependencies. Only when `cargo` is on PATH. |
| `cgv` | `cg vendor` | Vendor dependencies. Only when `cargo` is on PATH. |
| `cgtree` | `cg tree` | Display dependency tree. Only when `cargo` is on PATH. |
| `cgx` | `cg zigbuild` | Build using Zig. Only when `cargo` is on PATH. |
| `cgxw` | `cg cross` | Cross compilation. Only when `cargo` is on PATH. |
| `cgxt` | `cg target` | Target specific platform. Only when `cargo` is on PATH. |
| `cgfl` | `cg flamegraph` | Generate flamegraph. Only when `cargo` is on PATH. |
| `cgbl` | `cg bloat` | Binary size analysis. Only when `cargo` is on PATH. |
| `cgl` | `cg llvm-cov` | Code coverage. Only when `cargo` is on PATH. |
| `cgm` | `cg modules` | Module structure. Only when `cargo` is on PATH. |
| `cgex` | `cg expand` | Expand macros. Only when `cargo` is on PATH. |
| `cgi` | `cg install` | Install binary. Only when `cargo` is on PATH. |
| `cgun` | `cg uninstall` | Uninstall binary. Only when `cargo` is on PATH. |
| `cgp` | `cg publish` | Publish to crates.io. Only when `cargo` is on PATH. |
| `cgs` | `cg search` | Search crates.io. Only when `cargo` is on PATH. |
| `cgcp` | `cg package` | Create release package. Only when `cargo` is on PATH. |
| `cgba` | `cg build --all-targets` | Build all targets. Only when `cargo` is on PATH. |
| `cgbt` | `cg build --all-features` | Build with all features. Only when `cargo` is on PATH. |
| `cgbp` | `cg build --release --profile` | Build with specific profile. Only when `cargo` is on PATH. |
| `cgnb` | `cg generate --bin` | New binary from template. Only when `cargo` is on PATH. |
| `cgnl` | `cg generate --lib` | New library from template. Only when `cargo` is on PATH. |
| `cgnt` | `cg generate` | New from custom template. Only when `cargo` is on PATH. |
| `ru` | `rustup update` | Update all toolchains. Only when `rustup` is on PATH. |
| `rus` | `rustup update stable` | Update stable toolchain. Only when `rustup` is on PATH. |
| `rnightly` | `rustup update nightly` | Update nightly toolchain. Only when `rustup` is on PATH. |
| `rti` | `rustup toolchain install` | Install specific toolchain. Only when `rustup` is on PATH. |
| `rca` | `rustup component add` | Add component. Only when `rustup` is on PATH. |
| `rcl` | `rustup component list` | List components. Only when `rustup` is on PATH. |
| `rcr` | `rustup component remove` | Remove component. Only when `rustup` is on PATH. |
| `rtl` | `rustup toolchain list` | List installed toolchains. Only when `rustup` is on PATH. |
| `rtu` | `rustup toolchain uninstall` | Uninstall toolchain. Only when `rustup` is on PATH. |
| `rde` | `rustup default` | Set default toolchain. Only when `rustup` is on PATH. |
| `rtaa` | `rustup target add` | Add compilation target. Only when `rustup` is on PATH. |
| `rtal` | `rustup target list` | List available targets. Only when `rustup` is on PATH. |
| `rtar` | `rustup target remove` | Remove compilation target. Only when `rustup` is on PATH. |
| `rns` | `rustup run stable` | Run command with stable. Only when `rustup` is on PATH. |
| `rnn` | `rustup run nightly` | Run command with nightly. Only when `rustup` is on PATH. |
| `rdo` | `rustup doc --open` | Open Rust documentation. Only when `rustup` is on PATH. |
| `rpr` | `rustup override set` | Set directory toolchain. Only when `rustup` is on PATH. |
| `rpl` | `rustup override list` | List directory overrides. Only when `rustup` is on PATH. |
| `rpn` | `rustup override none` | Remove directory override. Only when `rustup` is on PATH. |
| `rws` | `rustup which rustc` | Show active rustc path. Only when `rustup` is on PATH. |
| `rsh` | `rustup show` | Show toolchain info. Only when `rustup` is on PATH. |

### Common Workflows

```bash
# Create a new project with common dependencies
cgn myproject && cd myproject && cga serde && cgad tokio

# Check, test, and build for release
cgcy && cgt && cgbr && cgaud

# Format code and update documentation
cgfa && cgd && cgdo

# Check the build for a different architecture
cgxw check --target aarch64-unknown-linux-gnu
```

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
