#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅲🅰🆁🅶🅾 🅰🅻🅸🅰🆂🅴🆂
if command -v cargo &>/dev/null; then
  alias cg='cargo'                 # c: Cargo shortcut.
  alias cgb='cg  build'            # cgb: Cargo build.
  alias cgbh='cg  bench'           # cgbh: Cargo bench.
  alias cgbr='cg  build --release' # cbr: Cargo build release.
  alias cgc='cg  check'            # cgc: Cargo check.
  alias cgcl='cg  clean'           # cgcl: Cargo clean.
  alias cgcy='cg  clippy'          # cgcy: Cargo clippy.
  alias cgd='cg  doc --open'       # cgd: Cargo doc.
  alias cgdr='cg  doc --release'   # cgdr: Cargo doc release.
  alias cgf='cg  fmt'              # cgf: Cargo format.
  alias cgi='cg  install'          # cgi: Cargo install.
  alias cginit='cg  init'          # cginit: Cargo init.
  alias cgn='cg  new'              # cgn: Cargo new.
  alias cgp='cg  publish'          # cgp: Cargo publish.
  alias cgr='cg  run'              # cgr: Cargo run.
  alias cgrr='cg  run --release'   # cgrr: Cargo run release.
  alias cgs='cg  search'           # cgs: Cargo search.
  alias cgt='cg  test'             # cgt: Cargo test.
  alias cgtr='cg  test --release'  # cgtr: Cargo test release.
  alias cgtt='cg  tree'            # cgtt: Cargo tree.
  alias cgu='cg  update'           # cgu: Cargo update.
  alias cgun='cg  uninstall'       # cgun: Cargo uninstall.
fi

# 🆁🆄🆂🆃🆄🅿 🅰🅻🅸🅰🆂🅴🆂
if command -v rustup &>/dev/null; then
  alias ru='rustup update'               # ru: Rustup update.
  alias rca='rustup component add'       # rca: Rustup component add.
  alias rcl='rustup component list'      # rcl: Rustup component list.
  alias rcr='rustup component remove'    # rcr: Rustup component remove.
  alias rde='rustup default'             # rde: Rustup default.
  alias rnn='rustup run nightly'         # rnn: Run rustup nightly.
  alias rns='rustup run stable'          # rls: Run rustup stable.
  alias rtaa='rustup target add'         # rtaa: Rustup target add.
  alias rtal='rustup target list'        # rtal: Rustup target list.
  alias rtar='rustup target remove'      # rtar: Rustup target remove.
  alias rti='rustup toolchain install'   # rti: Rustup toolchain install.
  alias rtl='rustup toolchain list'      # rtl: Rustup toolchain list.
  alias rtu='rustup toolchain uninstall' # rtu: Rustup toolchain uninstall.
  alias ruc='rustup update nightly'      # ruc: Update rustup nightly.
  alias rus='rustup update stable'       # rus: Update rustup stable.
fi
