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

## Harnesses today

| Harness | Mirrors | What it proves |
|---------|---------|----------------|
| `FuzzValidateName` | `scripts/dot/lib/utils.sh:101` (`validate_name`) | Every accepted name contains only `[a-zA-Z0-9._-]`; no shell metacharacter slips through; empty input refused. |
| `FuzzInitURLResolver` | `scripts/dot/commands/init.sh` (URL construction in `dot init <user\|owner/repo\|url>`) | Accepted URLs use `https://` / `git@` / `ssh://` only; plain HTTP refused; no shell metacharacters in constructed URLs; one input shape per acceptable form. |

Add a harness when:

- a new `dot <subcommand>` accepts user input via `$1` / `--flag`,
- a new regex appears in `scripts/dot/lib/utils.sh`,
- a new "construct a URL / path / shell-eval string" code path lands.

## Running locally

```sh
cd oss-fuzz-integration/fuzz

# 30-second smoke (find regressions quickly)
go test -run TestNothing -fuzz=FuzzValidateName    -fuzztime=30s ./...
go test -run TestNothing -fuzz=FuzzInitURLResolver -fuzztime=30s ./...

# Longer run when investigating a flake
go test -run TestNothing -fuzz=FuzzValidateName    -fuzztime=10m ./...
```

Failures land in `testdata/fuzz/Fuzz<Name>/` as auto-saved
reproducers. Commit them — they become permanent regression
guards via `go test ./...`.

## OSS-Fuzz integration (pending)

The `oss-fuzz-integration/` directory contains everything OSS-Fuzz
needs to onboard this project:

```
oss-fuzz-integration/
├── project.yaml      # OSS-Fuzz project metadata
├── Dockerfile        # build environment
├── build.sh          # compiles every harness in fuzz/
└── fuzz/             # the harnesses themselves
    ├── go.mod
    ├── validate_name_test.go
    └── init_url_resolver_test.go
```

To onboard:

1. Fork `github.com/google/oss-fuzz`.
2. Copy `oss-fuzz-integration/` contents to `projects/dotfiles/` in the fork.
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

`.github/workflows/fuzz.yml` (planned) runs each harness for
60 seconds on every PR touching:

- `scripts/dot/lib/utils.sh`
- `scripts/dot/commands/init.sh`
- `oss-fuzz-integration/**`

This is the local equivalent of CIFuzz and catches the
"shell-regex-change without Go-port update" drift class before
PR merge.

## See also

- `docs/security/SCORECARD.md` — `Fuzzing` check tracking.
- [Go native fuzzing tutorial](https://go.dev/doc/tutorial/fuzz).
- [OSS-Fuzz new project guide](https://google.github.io/oss-fuzz/getting-started/new-project-guide/).
- [CIFuzz GitHub Action](https://google.github.io/oss-fuzz/getting-started/continuous-integration/).
