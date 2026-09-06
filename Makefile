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
        lint lint-shell lint-shell-all lint-docs lint-pins lint-copyright \
        lint-workflows lint-links lint-reuse lint-spdx \
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
lint: lint-shell lint-docs lint-pins lint-copyright lint-workflows \
      lint-links lint-reuse lint-spdx ## All linters

# shellcheck covers every tracked shell file, matching ci.yml.
# shfmt is scoped to the same targets as reusable-shell-lint.yml
# (`shfmt_targets`), so `make lint-shell` reproduces CI exactly rather
# than being stricter than it. Use `make lint-shell-all` for the
# repo-wide formatting check — 21 files predate that scope and are
# left alone here deliberately: reformatting them belongs in its own
# change, not bundled into unrelated work.
SHFMT_TARGETS ?= scripts install.sh defaults/.chezmoitemplates

# `*.sh` only, matching reusable-shell-lint.yml's `rg --files -g "*.sh"`.
# Extensionless scripts (bin/dot, bin/dot-*) are covered by the
# preamble and copyright gates; some of them are Python, which
# shellcheck refuses outright.
lint-shell: ## shellcheck + shfmt, exactly as CI runs them
	git ls-files '*.sh' \
	  | xargs shellcheck -x --severity=error -e SC1091 -e SC2030 -e SC2031
	shfmt -d -i 2 -ci $(SHFMT_TARGETS)

lint-shell-all: ## shfmt over every tracked shell file (superset of CI)
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

lint-links: ## lychee offline link check (what docs-link-check.yml gates on)
	lychee --config config/lychee.toml --offline --no-progress '**/*.md'

lint-reuse: ## REUSE compliance over the whole tree
	reuse lint

lint-spdx: ## Every SPDX header declares the project's licence grant
	bash ./tools/ci/normalize-spdx-headers.sh --check

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
