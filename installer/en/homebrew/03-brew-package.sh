#!/bin/sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - Package installer.

# Check for Homebrew presence
if test "$(which brew)"; then

  # Homebrew updates and upgrades
  brew update  # Update Homebrew recipes
  brew upgrade # Upgrade any already-installed formulae.
  brew analytics off # Disable Homebrew analytics

  # Install packages
  brew install archey4                      # Archey for macOS
  brew install autoconf                     # Automatically configure source code on many Un*x platforms
  brew install automake                     # Tool for generating GNU Standards-compliant Makefiles
  brew install awk                          # Pattern scanning and processing language
  brew install bash                         # GNU Bourne-Again SHell
  brew install bdw-gc                       # Garbage collector for C and C++
  brew install berkeley-db                  # Berkeley Database
  brew install brotli                       # Generic-purpose lossless compression algorithm
  brew install btop                         # A cross-platform, highly customizable, resource monitor
  brew install c-ares                       # Asynchronous DNS library
  brew install ca-certificates              # Common CA certificates
  brew install cmatrix                      # Matrix code in your terminal
  brew install commitizen                   # CLI tool to make committing easier
  brew install coreutils                    # GNU File, Shell, and Text utilities
  brew install curl                         # Get a file from an HTTP, HTTPS or FTP server
  brew install docker                       # Pack, ship and run any application as a lightweight container
  brew install duf                          # Disk Usage/Free Utility - a better 'df' alternative
  brew install figlet                       # Program for making large letters out of ordinary text
  brew install findutils                    # Collection of GNU find, xargs, and locate
  brew install gcc                          # GNU compiler collection
  brew install gdbm                         # GNU database manager
  brew install gettext                      # GNU locale utilities
  brew install gh                           # GitHub on the command line
  brew install giflib                       # Library and utilities for working with GIF images
  brew install git                          # Distributed revision control system
  brew install git-crypt                    # Transparent file encryption in git
  brew install glib                         # Core application library for C
  brew install gmp                          # Free library for arbitrary precision arithmetic
  brew install gnu-getopt                   # Command-line option parsing utility
  brew install gnu-tar                      # GNU version of the tar archiving utility
  brew install gnupg                        # GNU privacy guard - a free PGP replacement
  brew install gnutls                       # GNU Transport Layer Security (TLS) Library
  brew install gti                          # Git CLI with autocomplete and shortcuts
  brew install guile                        # GNU Ubiquitous Intelligent Language for Extensions
  brew install htop                         # Improved top (interactive process viewer)
  brew install icu4c                        # C/C++ and Java libraries for Unicode and globalization
  brew install isl                          # Integer Set Library for the polyhedral model
  brew install jpeg                         # Library for manipulating JPEG image data
  brew install jpeg-turbo                   # SIMD-accelerated JPEG codec
  brew install jpegoptim                    # Utility to optimize JPEG files
  brew install libassuan                    # IPC library for the GnuPG components
  brew install libevent                     # Asynchronous event library
  brew install libffi                       # Foreign function interface library
  brew install libgcrypt                    # General purpose cryptographic library based on the code from GnuPG
  brew install libgpg-error                 # Common error values for all GnuPG components
  brew install libice                       # Inter-Client Exchange library
  brew install libidn2                      # Internationalized Domain Names (IDNA2008/TR46) implementation
  brew install libksba                      # X.509 and CMS support library
  brew install libmpc                       # Library for the arithmetic of high precision complex numbers
  brew install libnghttp2                   # HTTP/2 C Library
  brew install libpng                       # Library for manipulating PNG images
  brew install libpthread-stubs             # Pthread stub library
  brew install libslirp                     # User-mode networking for QEMU
  brew install libsm                        # Session Management library
  brew install libssh                       # Library implementing the SSH protocol
  brew install libssh2                      # Library implementing the SSH2 protocol
  brew install libtasn1                     # ASN.1 structure parser library
  brew install libtermkey                   # Library for processing keyboard entry for terminal-based programs
  brew install libtiff                      # Tools and library routines for working with TIFF images
  brew install libtool                      # Generic library support script
  brew install libunistring                 # Unicode string library for C
  brew install libusb                       # Library for USB device access
  brew install libuv                        # Multi-platform support library with a focus on asynchronous I/O
  brew install libx11                       # X11 client-side library
  brew install libxau                       # X11 authorisation library
  brew install libxcb                       # X C Binding
  brew install libxdmcp                     # X11 Display Manager Control Protocol library
  brew install libxext                      # X11 miscellaneous extension library
  brew install libxmu                       # X11 miscellaneous utility library
  brew install libxrender                   # X Rendering Extension client library
  brew install libxt                        # X11 toolkit intrinsics library
  brew install libyaml                      # YAML Parser
  brew install little-cms2                  # Color management engine supporting ICC profiles
  brew install lua                          # Powerful, lightweight programming language
  brew install luajit                       # Just-In-Time Compiler for Lua
  brew install luajit-openresty             # Just-In-Time Compiler for Lua
  brew install luv                          # Lua bindings to libuv
  brew install lynis                        # Security auditing tool for UNIX-based systems
  brew install lz4                          # Extremely Fast Compression algorithm
  brew install lzo                          # Data compression library
  brew install m4                           # GNU implementation of the traditional Unix macro processor
  brew install markdownlint-cli             # Markdown linting and style checking
  brew install mas                          # Mac App Store command line interface
  brew install mpdecimal                    # Library for decimal floating point arithmetic
  brew install mpfr                         # Library for multiple-precision floating-point computations
  brew install msgpack                      # MessagePack implementation for C and C++
  brew install ncurses                      # Text-based windowing system
  brew install neovim                       # Vim-fork focused on extensibility and agility
  brew install nettle                       # Low-level cryptographic library
  brew install newman                       # Command-line collection runner for Postman
  brew install node                         # Platform built on V8 to build network applications
  brew install npth                         # New GNU Portable Threads Library
  brew install openjdk                      # Development kit for the Java programming language
  brew install openjpeg                     # JPEG 2000 image compression library
  brew install openldap                     # Open source implementation of the LDAP protocol
  brew install openssl@1.1                  # TLS/SSL and crypto library
  brew install openssl@3                    # TLS/SSL and crypto library
  brew install p11-kit                      # Library for loading and coordinating access to PKCS#11 modules
  brew install p7zip                        # 7z and 7za file archiver with high compression ratio
  brew install pcre                         # Perl Compatible Regular Expressions library
  brew install pcre2                        # Perl Compatible Regular Expressions library
  brew install perl                         # Larry Wall's Practical Extraction and Report Language
  brew install pinentry                     # Passphrase entry dialog for GnuPG
  brew install pinentry-mac                 # Pinentry for GnuPG on macOS
  brew install pixman                       # Low-level software library for pixel manipulation
  brew install pkg-config                   # Manage compile and link flags for libraries
  brew install png2ico                      # Convert PNG images to Windows icon files
  brew install pnpm                         # Fast, disk space efficient package manager
  brew install podman                       # Tool for managing OCI containers and pods
  brew install potrace                      # Transform bitmaps into vector graphics
  brew install python@3.10                  # Interpreted, interactive, object-oriented programming language
  brew install python@3.9                   # Interpreted, interactive, object-oriented programming language
  brew install pyyaml                       # YAML parser and emitter for Python
  brew install qemu                         # CPU emulator using dynamic translation
  brew install rbenv                        # Ruby version manager
  brew install readline                     # Library for command-line editing
  brew install rename                       # Perl-powered file rename script with many helpful built-install
  brew install rtmpdump                     # RTMP downloader
  brew install ruby                         # Powerful, clean, object-oriented scripting language
  brew install ruby-build                   # Install various Ruby versions and implementations
  brew install rustup-init                  # Rust toolchain installer
  brew install shellcheck                   # Shell script analysis tool
  brew install snappy                       # Fast compressor/decompressor
  brew install sqlite                       # SQL database engine in a C library
  brew install svgo                         # Nodejs-based tool for optimizing SVG vector graphics files
  brew install tmux                         # Terminal multiplexer
  brew install trash                        # CLI tool that moves files or folders to the trash
  brew install tree                         # Display directories as trees (with optional color/HTML output)
  brew install tree-sitter                  # Parser generator tool and incremental parsing library
  brew install unar                         # Extractor for many archive formats
  brew install unbound                      # Validating, recursive, and caching DNS resolver
  brew install unibilium                    # Terminfo parsing and handling library
  brew install utf8proc                     # Clean C library for processing UTF-8 Unicode data
  brew install vde                          # Virtual Distributed Ethernet
  brew install vim                          # Vi 'workalike' with many additional features
  brew install webp                         # Tools and library for the WebP image format
  brew install wget                         # Internet file retriever
  brew install xorgproto                    # X.Org Protocol Headers
  brew install xz                           # General-purpose data compression with high compression ratio
  brew install yank                         # Copy to system clipboard
  brew install yarn                         # JavaScript package manager
  brew install zsh                          # UNIX shell (command interpreter)
  brew install zsh-autosuggestions          # Fish-like autosuggestions for zsh
  brew install zsh-completions              # Additional completion definitions for Zsh
  brew install zsh-fast-syntax-highlighting # Fish shell like fast syntax highlighting for Zsh
  brew install zstd                         # Fast real-time compression algorithm

  # Remove outdated versions
  brew cleanup

fi

exit 0
