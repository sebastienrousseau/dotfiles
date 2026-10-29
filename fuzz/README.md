# `fuzz/` — fuzz targets, corpus, and OSS-Fuzz scaffolding

Canonical home for fuzzing scaffolding. Go fuzz harnesses live in four
places: here (`fuzz/`, ports of the shell CLI's parsers), and next to the
Go tools they test, `defaults/dot_local/share/{dot-ui,dot-ai-tui,dot-mcp}/fuzz_test.go`.
Layout of this directory:

| Path | What | Run by |
|------|------|--------|
| `*_test.go`, `go.mod` | Native Go fuzz harnesses. Each `Fuzz<Name>` ports one user-input parsing surface of the shell CLI (see the header of each file for the shell function it mirrors). | `.github/workflows/fuzz.yml` (per push to `main`, per PR touching the parsed surfaces), `.github/workflows/cflite_pr.yml` (ClusterFuzzLite build, per PR) |
| `testdata/fuzz/<Harness>/` | **Committed regression corpus** — every crasher found and fixed, in Go's native corpus format. Replayed on every `go test` run, with or without `-fuzz`. | `fuzz.yml` jobs `Fuzz / Replay corpus (<name>)`, one per harness location |
| `install/fuzz_install.sh` | Shell harness that runs `install.sh` against adversarial arguments and environments and asserts fail-fast. | `.github/workflows/install-fuzz.yml` (weekly + PRs touching `install.sh`) |
| `tools/ci/check-fuzz-harness-self-contained.sh` | Proves each OSS-Fuzz harness file compiles without its sibling test files, as `compile_native_go_fuzzer` builds it. | `fuzz.yml` job `Fuzz / Harness self-containment` |
| `oss-fuzz/` | `Dockerfile`, `build.sh`, `project.yaml` for upstream submission to `google/oss-fuzz`. Pending submission; `.clusterfuzzlite/` reuses the same harnesses today. | OSS-Fuzz (once accepted) |

## Run locally

```sh
make fuzz                        # seed + regression corpus replay of fuzz/ (fast)
make fuzz FUZZTIME=30s           # plus 30 s of mutation for FuzzValidateName and FuzzInitURLResolver
bash fuzz/install/fuzz_install.sh
```

## Add a harness

1. Create `fuzz/<name>_test.go` with `func Fuzz<Cap>(f *testing.F)` and
   seed it with `f.Add(...)`.
2. Append a `compile_native_go_fuzzer` call to **both**
   `fuzz/oss-fuzz/build.sh` and `.clusterfuzzlite/build.sh`.
3. Add the harness name to the matrix in `.github/workflows/fuzz.yml`, and
   run `bash tools/ci/check-fuzz-harness-self-contained.sh` (the file must
   not use symbols from its sibling test files).
4. When the fuzzer finds a crash, fix the bug and commit the file Go
   writes under `testdata/fuzz/<Harness>/` — that is the regression
   corpus.

Full rationale (why Go ports of shell logic, what the invariants are)
lives in [`docs/security/FUZZING.md`](../docs/security/FUZZING.md).
