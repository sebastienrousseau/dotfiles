# `fuzz/` — fuzz targets, corpus, and OSS-Fuzz scaffolding

Canonical home for everything fuzzing-related. Layout:

| Path | What | Run by |
|------|------|--------|
| `*_test.go`, `go.mod` | Native Go fuzz harnesses. Each `Fuzz<Name>` ports one user-input parsing surface of the shell CLI (see the header of each file for the shell function it mirrors). | `.github/workflows/fuzz.yml` (per push to `main`, per PR touching the parsed surfaces), `.github/workflows/cflite_pr.yml` (ClusterFuzzLite, per PR) |
| `testdata/fuzz/<Harness>/` | **Committed regression corpus** — every crasher found and fixed, in Go's native corpus format. Replayed on every `go test` run, with or without `-fuzz`. | `fuzz.yml` job `Fuzz / corpus replay` |
| `install/fuzz_install.sh` | Shell harness that runs `install.sh` against adversarial arguments and environments and asserts fail-fast. | `.github/workflows/install-fuzz.yml` (weekly + PRs touching `install.sh`) |
| `oss-fuzz/` | `Dockerfile`, `build.sh`, `project.yaml` for upstream submission to `google/oss-fuzz`. Pending submission; `.clusterfuzzlite/` reuses the same harnesses today. | OSS-Fuzz (once accepted) |

## Run locally

```sh
make fuzz                        # seed + regression corpus replay (fast)
make fuzz FUZZTIME=30s           # plus 30 s of mutation per harness
bash fuzz/install/fuzz_install.sh
```

## Add a harness

1. Create `fuzz/<name>_test.go` with `func Fuzz<Cap>(f *testing.F)` and
   seed it with `f.Add(...)`.
2. Append a `compile_native_go_fuzzer` call to **both**
   `fuzz/oss-fuzz/build.sh` and `.clusterfuzzlite/build.sh`.
3. Add the harness name to the matrix in `.github/workflows/fuzz.yml`.
4. When the fuzzer finds a crash, fix the bug and commit the file Go
   writes under `testdata/fuzz/<Harness>/` — that is the regression
   corpus.

Full rationale (why Go ports of shell logic, what the invariants are)
lives in [`docs/security/FUZZING.md`](../docs/security/FUZZING.md).
