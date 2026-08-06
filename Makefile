PREFIX ?= /usr/local
DESTDIR ?=
LIBEXECDIR ?= $(PREFIX)/lib/dotfiles

.PHONY: test test-unit test-integration test-quick examples install uninstall

test:
	bash ./scripts/qa/reliability-audit.sh

test-unit:
	bash ./scripts/qa/reliability-audit.sh --unit-only

test-integration:
	bash ./scripts/qa/reliability-audit.sh --with-integration

test-quick:
	bash ./scripts/qa/reliability-audit.sh --quick

examples:
	bash ./scripts/qa/validate-examples.sh

install:
	bash ./tools/release/stage-dot.sh "$(DESTDIR)$(LIBEXECDIR)"
	install -d "$(DESTDIR)$(PREFIX)/bin"
	ln -sfn "../lib/dotfiles/bin/dot" "$(DESTDIR)$(PREFIX)/bin/dot"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/dot"
	rm -rf "$(DESTDIR)$(LIBEXECDIR)"
