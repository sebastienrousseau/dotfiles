#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅲🅰🆁🅶🅾 🅰🅻🅸🅰🆂🅴🆂
if command -v 'cargo' >/dev/null; then
    # Basic Commands
    alias cg='cargo'                             # Cargo shortcut
    alias cgn='cg new'                           # Create new binary project
    alias cgni='cg new --lib'                    # Create new library project
    alias cginit='cg init'                       # Initialize project in current directory

    # Build and Run
    alias cgb='cg build'                         # Build debug
    alias cgbr='cg build --release'              # Build release
    alias cgr='cg run'                           # Run debug
    alias cgrr='cg run --release'                # Run release
    alias cgw='cg watch'                         # Watch and rebuild

    # Testing and Benchmarking
    alias cgt='cg test'                          # Run tests
    alias cgtr='cg test --release'               # Run tests in release mode
    alias cgbh='cg bench'                        # Run benchmarks
    alias cgta='cg test --all'                   # Test all targets
    alias cgtt='cg test -- --test-threads=1'     # Single threaded tests

    # Code Quality
    alias cgc='cg check'                         # Check compilation
    alias cgcl='cg clean'                        # Clean build artifacts
    alias cgcy='cg clippy'                       # Run clippy lints
    alias cgf='cg fmt'                           # Format code
    alias cgfa='cg fmt --all'                    # Format all code
    alias cgfx='cg fix'                          # Auto-fix code issues
    alias cgaud='cg audit'                       # Security vulnerabilities check

    # Documentation
    alias cgd='cg doc --open'                    # Build and open documentation
    alias cgdr='cg doc --release'                # Build release documentation
    alias cgdo='cg doc --document-private-items' # Document private items

    # Dependencies
    alias cga='cg add'                           # Add dependency
    alias cgad='cg add --dev'                    # Add dev dependency
    alias cgu='cg update'                        # Update dependencies
    alias cgo='cg outdated'                      # Check outdated dependencies
    alias cgv='cg vendor'                        # Vendor dependencies
    alias cgtree='cg tree'                       # Display dependency tree

    # Cross Compilation
    alias cgx='cg zigbuild'                      # Build using Zig
    alias cgxw='cg cross'                        # Cross compilation
    alias cgxt='cg target'                       # Target specific platform

    # Analysis and Profiling
    alias cgfl='cg flamegraph'                   # Generate flamegraph
    alias cgbl='cg bloat'                        # Binary size analysis
    alias cgl='cg llvm-cov'                      # Code coverage
    alias cgm='cg modules'                       # Module structure
    alias cgex='cg expand'                       # Expand macros

    # Package Management
    alias cgi='cg install'                       # Install binary
    alias cgun='cg uninstall'                    # Uninstall binary
    alias cgp='cg publish'                       # Publish to crates.io
    alias cgs='cg search'                        # Search crates.io
    alias cgcp='cg package'                      # Create release package

    # Advanced Build
    alias cgba='cg build --all-targets'          # Build all targets
    alias cgbt='cg build --all-features'         # Build with all features
    alias cgbp='cg build --release --profile'    # Build with specific profile

    # Project Templates
    alias cgnb='cg generate --bin'               # New binary from template
    alias cgnl='cg generate --lib'               # New library from template
    alias cgnt='cg generate'                     # New from custom template
fi

# 🆁🆄🆂🆃🆄🅿 🅰🅻🅸🅰🆂🅴🆂
if command -v 'rustup' >/dev/null; then
    # Updates and Installation
    alias ru='rustup update'                     # Update all toolchains
    alias rus='rustup update stable'             # Update stable toolchain
    alias run='rustup update nightly'            # Update nightly toolchain
    alias rti='rustup toolchain install'         # Install specific toolchain

    # Components Management
    alias rca='rustup component add'             # Add component
    alias rcl='rustup component list'            # List components
    alias rcr='rustup component remove'          # Remove component

    # Toolchain Management
    alias rtl='rustup toolchain list'            # List installed toolchains
    alias rtu='rustup toolchain uninstall'       # Uninstall toolchain
    alias rde='rustup default'                   # Set default toolchain

    # Target Management
    alias rtaa='rustup target add'               # Add compilation target
    alias rtal='rustup target list'              # List available targets
    alias rtar='rustup target remove'            # Remove compilation target

    # Environment Running
    alias rns='rustup run stable'                # Run command with stable
    alias rnn='rustup run nightly'               # Run command with nightly

    # Documentation and Help
    alias rdo='rustup doc --open'                # Open Rust documentation

    # Override Management
    alias rpr='rustup override set'              # Set directory toolchain
    alias rpl='rustup override list'             # List directory overrides
    alias rpn='rustup override none'             # Remove directory override

    # Toolchain Information
    alias rws='rustup which rustc'               # Show active rustc path
    alias rsh='rustup show'                      # Show toolchain info
fi
