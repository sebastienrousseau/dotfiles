# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# GNUmakefile — the Unix install contract for the `dot` CLI.
#
#   make                       build products: man page + completions into build/
#   make test                  (from Makefile) run the test suite
#   make install               install under $(PREFIX), default /usr/local
#   make uninstall             remove exactly what install placed
#   make DESTDIR=/tmp/stage install
#                              stage into a packaging root (deb/rpm/AUR/brew)
#
# GNU make reads this file in preference to Makefile; the developer
# tasks (test, lint, docs, sbom, ...) are included from Makefile so
# both sets of targets are available from `make`.
#
# Layout installed (FHS, relocatable via the variables below):
#   $(BINDIR)/dot                       -> $(LIBEXECDIR)/bin/dot (symlink)
#   $(LIBEXECDIR)/                      bin/ lib/ scripts/ share/ defaults/ ...
#   $(MANDIR)/man1/dot.1
#   $(BASHCOMPDIR)/dot
#   $(ZSHCOMPDIR)/_dot
#   $(FISHCOMPDIR)/dot.fish
#   $(DOCDIR)/{LICENSE-APACHE,LICENSE-MIT,README.md,CHANGELOG.md}

PREFIX ?= /usr/local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
MANDIR ?= $(DATADIR)/man
DOCDIR ?= $(DATADIR)/doc/dotfiles
LIBEXECDIR ?= $(PREFIX)/lib/dotfiles
BASHCOMPDIR ?= $(DATADIR)/bash-completion/completions
ZSHCOMPDIR ?= $(DATADIR)/zsh/site-functions
FISHCOMPDIR ?= $(DATADIR)/fish/vendor_completions.d
BUILDDIR ?= build
INSTALL ?= install
INSTALL_DATA ?= $(INSTALL) -m 0644
# Relative symlink target from $(BINDIR) to $(LIBEXECDIR)/bin/dot. Relative
# so a DESTDIR-staged tree is executable in place (packagers and the
# release smoke test rely on that). Override when BINDIR/LIBEXECDIR are
# not siblings under $(PREFIX); install fails loudly if it does not resolve.
DOT_LINK ?= ../lib/dotfiles/bin/dot

.PHONY: all build-man build-completions install uninstall installcheck

all: build-man build-completions ## Build man page + completions into $(BUILDDIR)

include Makefile

build-man: $(BUILDDIR)/man/man1/dot.1
build-completions: $(BUILDDIR)/completions/_dot

$(BUILDDIR)/man/man1/dot.1: bin/dot tools/docs/man/dot.1.in tools/docs/generate-manpage.sh defaults/.chezmoidata.toml CHANGELOG.md
	bash ./tools/docs/generate-manpage.sh --output "$@"

$(BUILDDIR)/completions/_dot: bin/dot scripts/dot/commands/completion.sh tools/docs/generate-completions.sh
	bash ./tools/docs/generate-completions.sh --outdir "$(BUILDDIR)/completions"

install: all ## Install into $(DESTDIR)$(PREFIX) (FHS layout)
	bash ./tools/release/stage-dot.sh "$(DESTDIR)$(LIBEXECDIR)"
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(MANDIR)/man1" "$(DESTDIR)$(DOCDIR)" \
	  "$(DESTDIR)$(BASHCOMPDIR)" "$(DESTDIR)$(ZSHCOMPDIR)" "$(DESTDIR)$(FISHCOMPDIR)"
	ln -sfn "$(DOT_LINK)" "$(DESTDIR)$(BINDIR)/dot"
	@test -x "$(DESTDIR)$(BINDIR)/dot" || { echo "error: $(DESTDIR)$(BINDIR)/dot -> $(DOT_LINK) does not resolve; set DOT_LINK" >&2; exit 1; }
	$(INSTALL_DATA) "$(BUILDDIR)/man/man1/dot.1" "$(DESTDIR)$(MANDIR)/man1/dot.1"
	$(INSTALL_DATA) "$(BUILDDIR)/completions/dot" "$(DESTDIR)$(BASHCOMPDIR)/dot"
	$(INSTALL_DATA) "$(BUILDDIR)/completions/_dot" "$(DESTDIR)$(ZSHCOMPDIR)/_dot"
	$(INSTALL_DATA) "$(BUILDDIR)/completions/dot.fish" "$(DESTDIR)$(FISHCOMPDIR)/dot.fish"
	$(INSTALL_DATA) LICENSE-APACHE LICENSE-MIT README.md CHANGELOG.md "$(DESTDIR)$(DOCDIR)/"

uninstall: ## Remove everything `make install` placed
	rm -f "$(DESTDIR)$(BINDIR)/dot"
	rm -f "$(DESTDIR)$(MANDIR)/man1/dot.1"
	rm -f "$(DESTDIR)$(BASHCOMPDIR)/dot" "$(DESTDIR)$(ZSHCOMPDIR)/_dot" "$(DESTDIR)$(FISHCOMPDIR)/dot.fish"
	rm -rf "$(DESTDIR)$(DOCDIR)" "$(DESTDIR)$(LIBEXECDIR)"

installcheck: ## Prove the installed tree works with no source checkout
	@set -e; \
	sandbox="$$(mktemp -d)"; \
	trap 'rm -rf "$$sandbox"' EXIT; \
	test -L "$(DESTDIR)$(BINDIR)/dot"; \
	test -f "$(DESTDIR)$(MANDIR)/man1/dot.1"; \
	test -f "$(DESTDIR)$(BASHCOMPDIR)/dot"; \
	test -f "$(DESTDIR)$(ZSHCOMPDIR)/_dot"; \
	test -f "$(DESTDIR)$(FISHCOMPDIR)/dot.fish"; \
	test -f "$(DESTDIR)$(DOCDIR)/LICENSE-MIT"; \
	HOME="$$sandbox" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
	  "$(DESTDIR)$(LIBEXECDIR)/bin/dot" version | grep -F "$$(grep -E '^dotfiles_version' defaults/.chezmoidata.toml | cut -d'"' -f2)"; \
	HOME="$$sandbox" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
	  "$(DESTDIR)$(LIBEXECDIR)/bin/dot" help >/dev/null; \
	echo "installcheck: OK ($(DESTDIR)$(PREFIX))"
