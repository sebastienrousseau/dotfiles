<!-- markdownlint-disable MD033 MD041 MD043 -->
<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>
<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🆁🆄🆂🆃🆄🅿 🅰🅽🅳 🅲🅰🆁🅶🅾 🅰🅻🅸🅰🆂🅴🆂

This code provides a comprehensive set of aliases for Rust development
using `cargo` and `rustup` commands.

### Cargo Aliases

#### Basic Commands

- `cg` - Cargo shortcut
- `cgn` - Create new binary project
- `cgni` - Create new library project
- `cginit` - Initialize project in current directory

#### Build and Run

- `cgb` - Build debug
- `cgbr` - Build release
- `cgr` - Run debug
- `cgrr` - Run release
- `cgw` - Watch and rebuild

#### Testing and Benchmarking

- `cgt` - Run tests
- `cgtr` - Run tests in release mode
- `cgbh` - Run benchmarks
- `cgta` - Test all targets
- `cgtt` - Single threaded tests

#### Code Quality

- `cgc` - Check compilation
- `cgcl` - Clean build artifacts
- `cgcy` - Run clippy lints
- `cgf` - Format code
- `cgfa` - Format all code
- `cgfx` - Auto-fix code issues
- `cgaud` - Security vulnerabilities check

#### Documentation

- `cgd` - Build and open documentation
- `cgdr` - Build release documentation
- `cgdo` - Document private items

#### Dependencies

- `cga` - Add dependency
- `cgad` - Add dev dependency
- `cgu` - Update dependencies
- `cgo` - Check outdated dependencies
- `cgv` - Vendor dependencies
- `cgtree` - Display dependency tree

#### Cross Compilation

- `cgx` - Build using Zig
- `cgxw` - Cross compilation
- `cgxt` - Target specific platform

#### Analysis and Profiling

- `cgfl` - Generate flamegraph
- `cgbl` - Binary size analysis
- `cgl` - Code coverage
- `cgm` - Module structure
- `cgex` - Expand macros

#### Package Management

- `cgi` - Install binary
- `cgun` - Uninstall binary
- `cgp` - Publish to crates.io
- `cgs` - Search crates.io
- `cgcp` - Create release package

#### Advanced Build

- `cgba` - Build all targets
- `cgbt` - Build with all features
- `cgbp` - Build with specific profile

#### Project Templates

- `cgnb` - New binary from template
- `cgnl` - New library from template
- `cgnt` - New from custom template

### Rustup Aliases

#### Updates and Installation

- `ru` - Update all toolchains
- `rus` - Update stable toolchain
- `run` - Update nightly toolchain
- `rti` - Install specific toolchain

#### Components Management

- `rca` - Add component
- `rcl` - List components
- `rcr` - Remove component

#### Toolchain Management

- `rtl` - List installed toolchains
- `rtu` - Uninstall toolchain
- `rde` - Set default toolchain

#### Target Management

- `rtaa` - Add compilation target
- `rtal` - List available targets
- `rtar` - Remove compilation target

#### Environment Running

- `rns` - Run command with stable
- `rnn` - Run command with nightly

#### Documentation and Help

- `rdo` - Open Rust documentation

#### Override Management

- `rpr` - Set directory toolchain
- `rpl` - List directory overrides
- `rpn` - Remove directory override

#### Toolchain Information

- `rws` - Show active rustc path
- `rsh` - Show toolchain info

### Common Workflows

#### New Project Setup

```bash
# Create new project with common dependencies
cgn myproject && cd myproject && cga serde && cgad tokio
```

#### Release Workflow

```bash
# Check, test, and build for release
cgcy && cgt && cgbr && cgaud
```

#### Documentation Update

```bash
# Format code and update documentation
cgfa && cgd && cgdo
```

#### Cross-compilation Check

```bash
# Check build for different architecture
cgxw check --target aarch64-unknown-linux-gnu
```

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
