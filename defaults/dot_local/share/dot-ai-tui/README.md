# dot-ai-tui

The `dot ai` cockpit — a chat-centric
[Bubble Tea](https://github.com/charmbracelet/bubbletea) TUI for the AI
fleet. Pick a tool on the left, chat with it on the right (prompts run
through `dot ai <tool>` and stream back live), and watch the gateway and
today's spend in the header. Every action shells out to a `dot ai` verb
so behaviour has a single source of truth. Deployed to
`~/.local/bin/dot-ai-tui`.

| Pane | Keys |
| :--- | :--- |
| fleet | `↑`/`k` `↓`/`j` move · `⏎` open the tool's native session · `tab` / `p` quick chat · `/` command palette · `m` cycle model · `s` serve / stop · `i` install · `c`/`r` refresh · `q`/`esc` quit |
| chat | type and `⏎` to send · `/` opens the palette (`↑`/`↓`, `tab` completes, `⏎` runs) · `esc` back to the fleet |
| slash | `/help` `/model [name\|default]` `/style [name\|off]` `/tool <name>` `/save` `/resume` `/clear` `/serve` `/cost` `/exit` |

Configuration is by environment: `DOT_AI_HOST` / `DOT_AI_PORT` (gateway,
default `127.0.0.1:3456`), `XDG_DATA_HOME` (`dotfiles-ai.db` for cost and
recent runs), `XDG_STATE_HOME` (saved session). `DOT_AI_SNAPSHOT=1`
prints one static 94×26 frame (add `DOT_AI_SPLASH=1` for the empty state)
— used by previews and by CI, where there is no terminal.

See [FEATURES.md](FEATURES.md) for the full feature → test matrix.

## Development

Go MSRV: **1.26** (`go.mod`). Everything below runs from this directory.
`sqlite3` on `PATH` makes the cost/recent-runs tests deterministic (they
skip the DB paths without it).

```bash
go build -o ~/.local/bin/dot-ai-tui . # build the binary chezmoi deploys
go test ./...                         # unit, regression, example + fuzz-corpus replay
go test -race -count=3 ./...
go test -coverprofile=cov.out ./... && go tool cover -func=cov.out | tail -1   # gate: >= 98%
go test -bench . -benchtime=1x -run '^$' ./...   # every benchmark once (CI smoke)
go test -bench . -run '^$' ./...                 # real numbers
go vet ./... && staticcheck ./... && golangci-lint run ./...
DOT_AI_SNAPSHOT=1 go run .            # render one frame without a terminal
```

### Fuzzing

Eleven native Go fuzz targets cover every input-transforming surface —
chroma highlighting of model output, prompt flattening, slash-command
parsing, the `/` palette, list windowing, transcript layout, session
JSON, sqlite3 output scrubbing, gateway configuration, the whole key
handler at arbitrary terminal sizes, and the model cycle. Every `go test`
run replays the seed corpus plus the committed crashers under
`testdata/fuzz/<Target>/`. The ClusterFuzzLite / OSS-Fuzz build in
`fuzz/oss-fuzz/` compiles the same targets with libFuzzer.

```bash
go test -run '^$' -fuzz=FuzzHighlight          -fuzztime=30s ./...   # fenced-code highlighter
go test -run '^$' -fuzz=FuzzBuildPrompt        -fuzztime=30s ./...   # multi-turn prompt flattening
go test -run '^$' -fuzz=FuzzHandleSlash        -fuzztime=30s ./...   # slash commands
go test -run '^$' -fuzz=FuzzPalette            -fuzztime=30s ./...   # `/` palette filtering
go test -run '^$' -fuzz=FuzzWindowRows         -fuzztime=30s ./...   # fleet list windowing
go test -run '^$' -fuzz=FuzzRenderTranscript   -fuzztime=30s ./...   # transcript / splash layout
go test -run '^$' -fuzz=FuzzParseSession       -fuzztime=30s ./...   # session.json decoder
go test -run '^$' -fuzz=FuzzFilterSqliteOutput -fuzztime=30s ./...   # sqlite3 output scrubber
go test -run '^$' -fuzz=FuzzGatewayURL         -fuzztime=30s ./...   # DOT_AI_HOST/PORT → URL
go test -run '^$' -fuzz=FuzzModelKeys          -fuzztime=30s ./...   # full key handler + resize
go test -run '^$' -fuzz=FuzzModelCycle         -fuzztime=30s ./...   # `m` model cycle
go test -run '^Fuzz' -v ./...                                         # replay every corpus, no fuzzing
```

Crashers found so far and fixed (kept as regression corpus):
`FuzzHighlight` — a 5 000-character fence language tag stalled every render
for 13 s (chroma's registry scan is linear in the tag length; tags are now
validated and memoised); `FuzzRenderTranscript` / `FuzzModelKeys` — a
12-row terminal with the palette open and recent runs present asked the
splash for a negative height and panicked.

### Testing model

- The model is driven directly with `tea.Msg` values (`tea.KeyMsg`,
  `tea.WindowSizeMsg`, `refreshMsg`, `streamMsg`) and asserted on
  `Update` / `View` output; shell-outs go through the `execCommand` seam
  and are stubbed, the gateway is an `httptest` server, sqlite is a
  temp file.
- `main` is covered through the `exit` / `runProgram` seams; the alt-screen
  program start is exercised headless in `TestRunNoTTY`.
- `FEATURES.md` is machine-checked: `TestFeatureMatrixComplete` fails when a
  listed test does not exist, and `TestFeatureMatrixCoversEveryFuzzAndBenchmark`
  fails when a harness is missing from the matrix.

### CI

`.github/workflows/cockpit-test.yml` runs on every change to this
directory: gofmt, `go vet`, staticcheck, golangci-lint, the test suite with
a 98% coverage gate (MSRV and stable Go), a one-iteration benchmark smoke
and a fuzz-corpus replay.
