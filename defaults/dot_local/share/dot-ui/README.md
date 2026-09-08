# dot-ui

The shared [Bubble Tea](https://github.com/charmbracelet/bubbletea) renderer
behind the `dot` CLI. The bash command layer (`lib/dot/ui.sh`) does the real
work and streams structured events; `dot-ui` draws them with a consistent,
wallpaper-themed interface and never fails an apply — when Go or the binary
is absent, `ui.sh` falls back to plain output.

| Subcommand | Input | Output |
| :--- | :--- | :--- |
| `dot-ui run` | NDJSON events on stdin (`header`, `step`, `progress`, `wait`, `done`) | live checklist with spinner, progress bar and summary; keys from `/dev/tty` |
| `dot-ui pick [--header H] [--prompt P]` | one candidate per line on stdin | fuzzy picker on `/dev/tty`; selection printed to stdout (exit 0), cancel (1), no terminal (2) |
| `dot-ui table` | `\x1f`-separated rows on stdin, first line is the header | rounded, themed table on stdout |
| `dot-ui --version` | — | `dot-ui <version>` |

Colours come from `DOT_UI_ACCENT`, `DOT_UI_SUCCESS`, `DOT_UI_WARNING`,
`DOT_UI_ERROR`, `DOT_UI_INFO`, `DOT_UI_PANEL`, `DOT_UI_BORDER`, `DOT_UI_FG`
and `DOT_UI_BG` (`#rgb` / `#rrggbb`; anything else falls back per field).
`DOT_UI_SNAPSHOT=1` renders a single static frame — used by golden tests
and by CI, where there is no terminal.

See [FEATURES.md](FEATURES.md) for the full feature → test matrix.

## Development

Go MSRV: **1.26** (`go.mod`). Everything below runs from this directory.

```bash
go build -o ~/.local/bin/dot-ui .      # build the binary chezmoi deploys
go test ./...                          # unit, regression, example + fuzz-corpus replay
go test -race -count=3 ./...           # the interactive (socketpair) paths under the race detector
go test -coverprofile=cov.out ./... && go tool cover -func=cov.out | tail -1   # gate: >= 98%
go test -bench . -benchtime=1x -run '^$' ./...   # every benchmark once (CI smoke)
go test -bench . -run '^$' ./...                 # real numbers
go vet ./... && staticcheck ./... && golangci-lint run ./...
```

Try it without the bash layer:

```bash
printf '%s\n' \
  '{"t":"header","title":"dot theme","subtitle":"pulse"}' \
  '{"t":"step","id":"g","label":"Ghostty","state":"ok","detail":"reloaded"}' \
  '{"t":"done","elapsed_ms":42,"summary":"reloaded ghostty"}' | DOT_UI_SNAPSHOT=1 go run . run

printf 'Alias\x1fExpands\nll\x1fls -alFh\n' | go run . table
printf 'altai-dark\nberlin-dark\n' | go run . pick --header 'Pick a theme'
```

### Fuzzing

Eight native Go fuzz targets cover every input-parsing surface — the
NDJSON event decoder and reducer, the hex-colour validator, the picker's
matcher and key handling, the table row splitter, the stdin item reader
and the `pick` flag parser. Every `go test` run replays the seed corpus
plus the committed crashers under `testdata/fuzz/<Target>/`, so a fixed
bug cannot silently return. The ClusterFuzzLite / OSS-Fuzz build in
`fuzz/oss-fuzz/` compiles the same targets with libFuzzer.

```bash
go test -run '^$' -fuzz=FuzzParseEvent    -fuzztime=30s ./...   # NDJSON line decoder
go test -run '^$' -fuzz=FuzzStepApply     -fuzztime=30s ./...   # event stream → model → View
go test -run '^$' -fuzz=FuzzParseColor    -fuzztime=30s ./...   # DOT_UI_* hex validation
go test -run '^$' -fuzz=FuzzFuzzyMatch    -fuzztime=30s ./...   # picker matcher (any script)
go test -run '^$' -fuzz=FuzzPickKeys      -fuzztime=30s ./...   # picker key script + resize
go test -run '^$' -fuzz=FuzzRunTable      -fuzztime=30s ./...   # \x1f row splitter
go test -run '^$' -fuzz=FuzzReadItems     -fuzztime=30s ./...   # stdin candidate reader
go test -run '^$' -fuzz=FuzzParsePickArgs -fuzztime=30s ./...   # --header/--prompt parser
go test -run '^Fuzz' -v ./...                                    # replay every corpus, no fuzzing
```

Crashers found so far and fixed (kept as regression corpus):
`FuzzStepApply` — a negative `progress.cur` panicked `strings.Repeat` in the
progress bar; `FuzzFuzzyMatch` — a byte-vs-rune comparison made every
non-ASCII query unmatchable.

### Testing model

- Bubble Tea models are driven directly with `tea.Msg` values and asserted
  on `Update` / `View` output.
- The interactive paths (`/dev/tty`, Bubble Tea's input reader and
  renderer) run for real over a Unix socketpair in `tty_test.go`; the three
  one-line process seams (`exit`, terminal detection, `/dev/tty` open) are
  the only code not exercised through a fake, and `TestSeamDefaults` still
  calls their production bodies.
- `FEATURES.md` is machine-checked: `TestFeatureMatrixComplete` fails when a
  listed test does not exist, and `TestFeatureMatrixCoversEveryFuzzAndBenchmark`
  fails when a harness is missing from the matrix.

### CI

`.github/workflows/dot-ui-test.yml` runs on every change to this
directory: gofmt, `go vet`, staticcheck, golangci-lint, the test suite with
a 98% coverage gate (MSRV and stable Go), a one-iteration benchmark smoke
and a fuzz-corpus replay.
