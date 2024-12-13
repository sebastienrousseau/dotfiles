#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅲🅰🆁🅶🅾 🅰🅻🅸🅰🆂🅴🆂

if command -v 'cargo' >/dev/null; then
  # c: Cargo shortcut.
  alias cg='cargo'

  # cgb: Cargo build.
  alias cgb='cg build'

  # cgbh: Cargo bench.
  alias cgbh='cg bench'

  # cbr: Cargo build release.
  alias cgbr='cg build --release'

  # cgc: Cargo check.
  alias cgc='cg check'

  # cgcl: Cargo clean.
  alias cgcl='cg clean'

  # cgcy: Cargo clippy.
  alias cgcy='cg clippy'

  # cgd: Cargo doc.
  alias cgd='cg doc --open'

  # cgdr: Cargo doc release.
  alias cgdr='cg doc --release'

  # cgf: Cargo format.
  alias cgf='cg fmt'

  # cgi: Cargo install.
  alias cgi='cg install'

  # cginit: Cargo init.
  alias cginit='cg init'

  # cgn: Cargo new.
  alias cgn='cg new'

  # cgp: Cargo publish.
  alias cgp='cg publish'

  # cgr: Cargo run.
  alias cgr='cg run'

  # cgrr: Cargo run release.
  alias cgrr='cg run --release'

  # cgs: Cargo search.
  alias cgs='cg search'

  # cgt: Cargo test.
  alias cgt='cg test'

  # cgtr: Cargo test release.
  alias cgtr='cg test --release'

  # cgtt: Cargo tree.
  alias cgtt='cg tree'

  # cgu: Cargo update.
  alias cgu='cg update'

  # cgun: Cargo uninstall.
  alias cgun='cg uninstall'

fi

# 🆁🆄🆂🆃🆄🅿 🅰🅻🅸🅰🆂🅴🆂
if command -v 'rustup' >/dev/null; then

  # Rustup update.
  alias ru='rustup update'

  # Rustup component add.
  alias rca='rustup component add'

  # Rustup component list.
  alias rcl='rustup component list'

  # Rustup component remove.
  alias rcr='rustup component remove'

  # Rustup default.
  alias rde='rustup default'

  # Run rustup nightly.
  alias rnn='rustup run nightly'

  # Run rustup stable.
  alias rns='rustup run stable'

  # Rustup target add.
  alias rtaa='rustup target add'

  # Rustup target list.
  alias rtal='rustup target list'

  # Rustup target remove.
  alias rtar='rustup target remove'

  # Rustup toolchain install.
  alias rti='rustup toolchain install'

  # Rustup toolchain list.
  alias rtl='rustup toolchain list'

  # Rustup toolchain uninstall.
  alias rtu='rustup toolchain uninstall'

  # Update rustup nightly.
  alias ruc='rustup update nightly'

  # Update rustup stable.
  alias rus='rustup update stable'

fi
