---
title: "Fuzzing"
date: 2026-05-17
---

# Fuzzing

The project ships native-Go fuzz harnesses for every user-input
parsing surface in the framework. The harnesses run locally via
`go test -fuzz`, in CI on every PR via `.github/workflows/fuzz.yml`,
and (pending upstream submission) continuously on Google's OSS-Fuzz
infrastructure.

## Why Go fuzzing

The framework is bash. Bash has no first-class fuzzing framework
that OpenSSF Scorecard recognises (Scorecard scores `Fuzzing` 0
unless the project ships an integration with one of: OSS-Fuzz,
ClusterFuzzLite, native Go fuzz, libFuzzer, Atheris). The
pragmatic path is to **port each user-input parsing surface
into a small Go function**, run the fuzzer against the Go port,
and keep the Go port in lockstep with the shell original via
identical regex / control-flow.

Drift between the shell and Go port IS the bug class the
fuzzer is designed to surface — if the Go port accepts a string
the shell rejects (or vice-versa), one of them has a hole.

## Where the harnesses live

The framework ships two Go binaries as well as the shell, so
harnesses live in three modules:

| Module | Harnesses | Runs against |
|--------|-----------|--------------|
| `fuzz` | 11 | ports of the shell helpers **and** of the two binaries' parsers — this is the package OSS-Fuzz and ClusterFuzzLite compile |
| `defaults/dot_local/share/dot-ui` | 8 | the real dot-ui implementation, in-module |
| `defaults/dot_local/share/dot-ai-tui` | 11 | the real dot-ai-tui implementation, in-module |

`dot-ui` and `dot-ai-tui` are `package main` in their own modules,
which OSS-Fuzz's `compile_native_go_fuzzer` cannot import — it needs a
library package. Their parsers are therefore **ported** into
`fuzz` alongside the shell ports, and fuzzed
in-module as well. The in-module targets are the ones that catch real
bugs on every push; the ports are what runs continuously at scale.
The same lockstep rule applies: drift between a port and its original
is a bug in one of them.

## Harnesses today

### Ports (built by OSS-Fuzz / ClusterFuzzLite)

| Harness | Mirrors | What it proves |
|---------|---------|----------------|
| `FuzzValidateName` | `scripts/dot/lib/utils.sh:101` (`validate_name`) | Every accepted name contains only `[a-zA-Z0-9._-]`; no shell metacharacter slips through; empty input refused. |
| `FuzzInitURLResolver` | `scripts/dot/commands/init.sh` (URL construction in `dot init <user\|owner/repo\|url>`) | Accepted URLs use `https://` / `git@` / `ssh://` only; plain HTTP refused; no shell metacharacters in constructed URLs; one input shape per acceptable form. |
| `FuzzUIEventLine` | dot-ui `run.go` (`parseEvent`, `renderBar`) | A line either decodes to valid JSON or is refused; an accepted event round-trips; the derived progress width is always a legal repeat count. |
| `FuzzUIHexColor` | dot-ui `theme.go` (`parseColor`) | An accepted `DOT_UI_*` value is a literal `#rgb`/`#rrggbb` with no metacharacter or escape sequence — these are interpolated into terminal escapes. |
| `FuzzUIPickFilter` | dot-ui `pick.go` (`fuzzyMatch`, `readItems`) | No blank candidate survives; every candidate matches itself in any script; a query longer than the candidate never matches. |
| `FuzzUIPickArgs` | dot-ui `main.go` (`parsePickArgs`) | The parser never invents a value; every prefix of the argument list is safe. |
| `FuzzUITableRows` | dot-ui `table.go` (`runTable` input) | The `\x1f` split is reversible, so no cell can merge into or leak across a neighbouring column. |
| `FuzzAISessionFile` | dot-ai-tui `main.go` (`parseSession`) | A malformed session file decodes to nothing, never to a partial or mutated transcript; a valid one round-trips. |
| `FuzzAISqliteOutput` | dot-ai-tui `main.go` (`filterSqliteOutput`) | No `~/.sqliterc` meta line (`.timer`, `Run Time:`) survives into the cost/run data the cockpit renders. |
| `FuzzAIFenceTag` | dot-ai-tui `main.go` (`langRe`, `highlight`) | Every fence info string taken from model output is refused or a short identifier, so an unbounded chroma lexer lookup cannot stall rendering; prose segments survive segmentation. |
| `FuzzAIGatewayURL` | dot-ai-tui `main.go` (`gatewayURL`) | The health-check URL always keeps the `http` scheme and the configured host and port verbatim. |

### In-module (against the real implementation)

| Module | Harnesses |
|--------|-----------|
| dot-ui | `FuzzParseEvent`, `FuzzStepApply`, `FuzzParseColor`, `FuzzFuzzyMatch`, `FuzzPickKeys`, `FuzzRunTable`, `FuzzReadItems`, `FuzzParsePickArgs` |
| dot-ai-tui | `FuzzHighlight`, `FuzzBuildPrompt`, `FuzzHandleSlash`, `FuzzPalette`, `FuzzWindowRows`, `FuzzRenderTranscript`, `FuzzParseSession`, `FuzzFilterSqliteOutput`, `FuzzGatewayURL`, `FuzzModelKeys`, `FuzzModelCycle` |

Each module's `FEATURES.md` maps every harness to the feature it
covers, and a matrix test fails if a harness is missing from it.

### Findings so far

| Harness | Bug | Fix |
|---------|-----|-----|
| `FuzzStepApply` | `{"t":"progress","cur":-1,"total":1}` produced a negative `strings.Repeat` count and panicked the run view mid-apply. | Clamp the bar width to `[0, w]`. |
| `FuzzFuzzyMatch` | The picker compared a query **byte** against a candidate **rune**, so no non-ASCII query could match — not even the identical string. | Compare both sides as runes. |
| `FuzzHighlight` | A 5 000-character fenced-block language tag stalled every render for 13s (chroma's unknown-lexer lookup is linear in the tag length). | Validate fence tags against a short-identifier pattern and memoise the lookup. |
| `FuzzRenderTranscript` | An empty transcript on a 12-row terminal with the palette open asked the splash for a negative height and panicked on a slice bound. | Drop the "recent runs" block when it does not fit; clamp the splash height. |

### Harness files must be self-contained

`compile_native_go_fuzzer` rewrites **one** `*_test.go` file into a
regular `.go` file and builds it **without** the package's other test
files. A harness that references a symbol declared in a sibling
`_test.go` therefore passes `go test` everywhere and fails only inside
the OSS-Fuzz / ClusterFuzzLite container:

```
./dot_ui_parsers_test.go_fuzz.go:117:21: undefined: dangerousChars
2026/09/07 01:14:42 failed to build packages:exit status 1
```

So a shared constant is deliberately **duplicated** per harness file
rather than factored out. If sharing is genuinely warranted, put the
symbol in a non-test `.go` file in the package — those the builder keeps.

`tools/ci/check-fuzz-harness-self-contained.sh` enforces this by
type-checking each harness alone in a scratch module; it runs in the
`Fuzz / Harness self-containment` job on every relevant PR.

Add a harness when:

- a new `dot <subcommand>` accepts user input via `$1` / `--flag`,
- a new regex appears in `scripts/dot/lib/utils.sh`,
- a new "construct a URL / path / shell-eval string" code path lands,
- a new function in `dot-ui` or `dot-ai-tui` parses or transforms
  stdin, an environment variable, a key stream or model output —
  add it in-module *and* port it to `fuzz`.

## Running locally

```sh
# Ports (also what OSS-Fuzz builds)
cd fuzz
go test -run '^$' -fuzz=FuzzValidateName -fuzztime=30s ./...
go test -run '^$' -fuzz=FuzzUIEventLine  -fuzztime=30s ./...

# In-module, against the real implementation
cd defaults/dot_local/share/dot-ui
go test -run '^$' -fuzz=FuzzStepApply -fuzztime=30s ./...

cd defaults/dot_local/share/dot-ai-tui
go test -run '^$' -fuzz=FuzzHighlight -fuzztime=30s ./...

# Replay every committed corpus in a module (no fuzzing, no flakes)
go test -run '^Fuzz' -v ./...
```

Each module's README lists every harness with a copy-pasteable
command.

Failures land in `testdata/fuzz/Fuzz<Name>/` as auto-saved
reproducers. Commit them — they become permanent regression
guards, replayed by `go test ./...` and by the `replay` job in
`.github/workflows/fuzz.yml`.

## OSS-Fuzz integration (pending)

The `fuzz/oss-fuzz/` directory contains everything OSS-Fuzz
needs to onboard this project:

```
fuzz/oss-fuzz/
├── project.yaml      # OSS-Fuzz project metadata
├── Dockerfile        # build environment
├── build.sh          # compiles every harness in fuzz/
└── fuzz/             # the harnesses themselves
    ├── go.mod
    ├── validate_name_test.go
    ├── init_url_resolver_test.go
    ├── dot_ui_parsers_test.go       # ports of the dot-ui parsers
    └── dot_ai_tui_parsers_test.go   # ports of the dot-ai-tui parsers
```

To onboard:

1. Fork `github.com/google/oss-fuzz`.
2. Copy `fuzz/oss-fuzz/` contents to `projects/dotfiles/` in the fork.
3. Verify locally per <https://google.github.io/oss-fuzz/getting-started/new-project-guide/#testing-locally>:

   ```sh
   python infra/helper.py build_image dotfiles
   python infra/helper.py build_fuzzers --sanitizer address dotfiles
   python infra/helper.py check_build dotfiles
   python infra/helper.py run_fuzzer dotfiles fuzz_validate_name
   ```

4. Open a PR to `google/oss-fuzz` per <https://google.github.io/oss-fuzz/getting-started/accepting-new-projects/>.
5. Once merged, OSS-Fuzz schedules continuous runs on GCP; findings land as private issues in the OSS-Fuzz tracker and are mirrored to the maintainer email in `project.yaml`.
6. Update `docs/security/SCORECARD.md` — Scorecard's `Fuzzing` check recognises OSS-Fuzz projects automatically (0 → 10).

The upstream PR opens the door to the **CIFuzz** GitHub Action,
which runs OSS-Fuzz-style fuzzing on every PR in this repo
(separate from the local-go-fuzz CI job).

## CI workflow

`.github/workflows/fuzz.yml` has two gates:

- **replay** — on every push and PR, every committed corpus (seed
  entries plus the minimized crashers of previously-fixed findings) is
  replayed in all three modules with `go test -run '^Fuzz'`. No
  fuzzing, so no flakes: a fixed crash cannot silently come back.
- **fuzz** — a 60-second window per harness (configurable via
  `workflow_dispatch`) on PRs touching an input-parsing surface:
  `scripts/dot/lib/utils.sh`, `scripts/dot/commands/init.sh`,
  `fuzz/**`, `.clusterfuzzlite/**` or either Go
  module.

This is the local equivalent of CIFuzz and catches the
"shell-regex-change without Go-port update" drift class before
PR merge. The per-module test workflows (`dot-ui-test.yml`,
`cockpit-test.yml`) replay their own corpus too, so the guard holds
even when only one module changes.

## See also

- `docs/security/SCORECARD.md` — `Fuzzing` check tracking.
- [Go native fuzzing tutorial](https://go.dev/doc/tutorial/fuzz).
- [OSS-Fuzz new project guide](https://google.github.io/oss-fuzz/getting-started/new-project-guide/).
- [CIFuzz GitHub Action](https://google.github.io/oss-fuzz/getting-started/continuous-integration/).
