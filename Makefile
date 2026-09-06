# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Makefile — developer tasks. Discoverable by convention; every target
# here is something CI also runs, so `make check` locally ≈ CI green.
#
# The Unix install contract (`make install` / `make uninstall`, PREFIX,
# DESTDIR, FHS paths) lives in GNUmakefile, which GNU make prefers over
# this file automatically and which includes it. Run `make help`.

SHELL := bash
BUILDDIR ?= build
FUZZTIME ?=

.DEFAULT_GOAL := help

.PHONY: help test test-unit test-integration test-quick examples \
        lint lint-shell lint-docs lint-pins lint-copyright lint-workflows \
        docs docs-serve man completions generate check-drift verify-versions \
        sbom bench fuzz coverage clean check

help: ## Show this help
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## /{printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ── Tests ──────────────────────────────────────────────────────────────
test: ## Full reliability audit (unit + regression + integration gates)
	bash ./scripts/qa/reliability-audit.sh

test-unit: ## Unit tests only
	bash ./scripts/qa/reliability-audit.sh --unit-only

test-integration: ## Unit + integration tests
	bash ./scripts/qa/reliability-audit.sh --with-integration

test-quick: ## Fast subset for pre-commit loops
	bash ./scripts/qa/reliability-audit.sh --quick

examples: ## Execute every example under examples/ (docs that run)
	bash ./scripts/qa/validate-examples.sh

coverage: ## kcov/xtrace coverage report (MIN_COVERAGE_PCT gate, see coverage.yml)
	bash ./tools/ci/run-coverage.sh

# ── Lint ───────────────────────────────────────────────────────────────
lint: lint-shell lint-docs lint-pins lint-copyright lint-workflows ## All linters

lint-shell: ## shellcheck + shfmt on every tracked shell file (CI flags)
	git ls-files '*.sh' 'bin/dot' 'bin/dot-*' 'scripts/verify-release-versions' \
	  | xargs shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031
	git ls-files '*.sh' | xargs shfmt -d -i 2 -ci

lint-docs: ## markdownlint-cli2 + codespell over docs and *.md
	npx --yes markdownlint-cli2 '**/*.md'
	codespell --config config/codespellrc

lint-pins: ## Reusable workflows must be pinned by 40-hex SHA
	bash ./tools/ci/lint-reusable-pins.sh

lint-copyright: ## Copyright/SPDX header present in every source file
	bash ./tools/ci/check-copyright-headers.sh

lint-workflows: ## actionlint over .github/workflows
	actionlint

# ── Generated artefacts ────────────────────────────────────────────────
man: ## Generate share/man/man1/dot.1 from the command registry
	bash ./tools/docs/generate-manpage.sh

completions: ## Regenerate committed zsh/bash completions from the registry
	bash ./tools/docs/generate-completions.sh

generate: man completions ## Regenerate every registry-derived artefact
	bash ./tools/docs/generate-command-index.sh

check-drift: ## Fail if any generated artefact is stale (what doc-drift.yml runs)
	bash ./tools/docs/generate-command-index.sh --check
	bash ./tools/docs/generate-manpage.sh --check
	bash ./tools/docs/generate-completions.sh --check
	bash ./scripts/verify-release-versions

verify-versions: ## Assert every version surface matches the manifest
	bash ./scripts/verify-release-versions

# ── Docs ───────────────────────────────────────────────────────────────
docs: ## Build the MkDocs manual with warnings denied
	mkdocs build --strict

docs-serve: ## Serve the manual locally
	mkdocs serve

# ── Supply chain / perf / fuzz ─────────────────────────────────────────
sbom: ## CycloneDX SBOM of the source tree (syft) into build/
	mkdir -p $(BUILDDIR)
	syft scan dir:. -o cyclonedx-json=$(BUILDDIR)/sbom.cyclonedx.json

bench: ## Smoke-run the benchmarks (kept runnable, not asserted)
	bash ./benches/benchmark_runner.sh

fuzz: ## Replay seed + regression corpus; set FUZZTIME=30s to also mutate
	cd fuzz && go vet ./... && go test -count=1 ./...
	@if [ -n "$(FUZZTIME)" ]; then \
	  cd fuzz && for h in FuzzValidateName FuzzInitURLResolver; do \
	    go test -run TestNothing -fuzz="^$$h\$$" -fuzztime=$(FUZZTIME) ./... || exit 1; \
	  done; \
	fi

# ── Housekeeping ───────────────────────────────────────────────────────
clean: ## Remove build products
	rm -rf $(BUILDDIR) site _build coverage dist nightly-reports

check: lint check-drift test examples ## Everything CI gates on, locally
