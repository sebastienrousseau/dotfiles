<!-- SPDX-License-Identifier: {{LICENSE_SPDX}} -->

<p align="center">
  <img src="{{LOGO_URL}}" alt="{{PROJECT_NAME}} logo" width="128" />
</p>

<h1 align="center">{{PROJECT_NAME}}</h1>

<p align="center">
  {{ONE_SENTENCE_PITCH}}
</p>

<p align="center">
  <a href="{{REPO_URL}}/actions"><img src="{{REPO_URL}}/workflows/ci/badge.svg?style=for-the-badge&logo=github" alt="Build" /></a>
  <a href="{{REGISTRY_URL}}"><img src="{{REGISTRY_BADGE_IMAGE}}?style=for-the-badge&color=fc8d62&logo={{ECOSYSTEM_LOGO}}" alt="Registry" /></a>
  <a href="{{API_DOCS_URL}}"><img src="{{API_DOCS_BADGE_IMAGE}}?style=for-the-badge&labelColor=555555&logo={{DOCS_LOGO}}" alt="Docs" /></a>
  <a href="https://scorecard.dev/viewer/?uri={{REPO_DOMAIN_AND_PATH}}"><img src="https://img.shields.io/ossf-scorecard/{{REPO_DOMAIN_AND_PATH}}?style=for-the-badge&label=OpenSSF%20Scorecard&logo=openssf" alt="OpenSSF Scorecard" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-{{LICENSE_URL_ENCODED}}-blue.svg?style=for-the-badge" alt="License: {{LICENSE_SPDX}}" /></a>
  <a href="{{REPO_URL}}/blob/main/docs/POLICIES.md"><img src="https://img.shields.io/badge/{{MIN_TOOLCHAIN_BADGE_LABEL}}-93450a.svg?style=for-the-badge&logo={{ECOSYSTEM_LOGO}}" alt="{{MIN_TOOLCHAIN_TEXT}}" /></a>
</p>

<p align="center">
  <img src=".github/demo.gif" alt="{{DEMO_ALT_TEXT}}" width="100%" />
</p>

---

## Contents

**Getting started**

- [Install](#install) — {{INSTALL_METHODS_SUMMARY}}
- [Requirements](#requirements) — toolchain floor, platforms
- [Quick Start](#quick-start) — {{QUICK_START_SUMMARY_PITCH}}

**The {{PROJECT_NAME}} ecosystem**

- [The {{PROJECT_NAME}} ecosystem](#the-{{PROJECT_NAME_LOWER}}-ecosystem) — {{ECOSYSTEM_CRATES_OR_MODULES_LIST}}

**Library reference**

- [Capabilities at a glance](#capabilities-at-a-glance) — the current surface by theme
- [Ecosystem comparison](#ecosystem-comparison) — short matrix; full table at [`docs/COMPARISON.md`](docs/COMPARISON.md)
- [Benchmarks](#benchmarks) — headline numbers; full table at [`docs/BENCHMARKS.md`](docs/BENCHMARKS.md)
- [Features](#features) — module-level capability list
- [Configuration](#configuration) — core options
- [Examples](#examples) — runnable example index

**Operational**

- [When not to use {{PROJECT_NAME}}](#when-not-to-use-{{PROJECT_NAME_LOWER}}) — limitations
- [Development](#development) — make targets, fuzzing, CI
- [Security](#security) — guarantees and compliance
- [Documentation](#documentation) — all reference docs
- [Stability guarantees](#stability-guarantees) — SemVer axis, output stability, minimum toolchain discipline
- [License](#license)

---

## Install

### As a {{ECOSYSTEM_NAME}} library

```{{ECOSYSTEM_MANIFEST_LANG}}
{{INSTALL_LIBRARY_SNIPPET}}
```

{{ADDITIONAL_INSTALL_METHODS}}

---

## Requirements

{{REQUIREMENTS_CONTENT}}

---

## Quick Start

```{{QUICK_START_LANG}}
{{QUICK_START_SNIPPET}}
```

{{QUICK_START_EXPLANATION}}

---

## The {{PROJECT_NAME}} ecosystem

{{ECOSYSTEM_OVERVIEW}}

| Component | Purpose | Use case |
| :--- | :--- | :--- |
| {{COMPONENT_NAME}} | {{COMPONENT_PURPOSE}} | {{COMPONENT_USE_CASE}} |

---

## Capabilities at a glance

| Area | Capability | Status |
| :--- | :--- | :--- |
| {{CAPABILITY_AREA}} | {{CAPABILITY_DESCRIPTION}} | {{CAPABILITY_STATUS}} |

---

## Ecosystem comparison

{{ECOSYSTEM_COMPARISON_SUMMARY}}

| Project | {{COMPARISON_DIMENSION_ONE}} | {{COMPARISON_DIMENSION_TWO}} | {{COMPARISON_DIMENSION_THREE}} |
| :--- | :---: | :---: | :---: |
| **{{PROJECT_NAME}}** | {{PROJECT_COMPARISON_VALUE_ONE}} | {{PROJECT_COMPARISON_VALUE_TWO}} | {{PROJECT_COMPARISON_VALUE_THREE}} |

See [`docs/COMPARISON.md`](docs/COMPARISON.md) for the evidence and complete matrix.

---

## Benchmarks

{{BENCHMARK_SUMMARY}}

| Scenario | Result | Environment |
| :--- | ---: | :--- |
| {{BENCHMARK_SCENARIO}} | {{BENCHMARK_RESULT}} | {{BENCHMARK_ENVIRONMENT}} |

See [`docs/BENCHMARKS.md`](docs/BENCHMARKS.md) for methodology and full results.

---

## Features

{{FEATURES_CONTENT}}

---

## Configuration

{{CONFIGURATION_CONTENT}}

---

## Examples

{{EXAMPLES_CONTENT}}

---

## When not to use {{PROJECT_NAME}}

{{LIMITATIONS_CONTENT}}

---

## Development

```bash
{{DEVELOPMENT_COMMANDS}}
```

{{DEVELOPMENT_CONTENT}}

---

## Security

{{SECURITY_CONTENT}}

Report vulnerabilities according to [`SECURITY.md`](SECURITY.md).

---

## Documentation

{{DOCUMENTATION_INDEX}}

---

## Stability guarantees

{{STABILITY_CONTENT}}

---

## License

{{LICENSE_CONTENT}}
