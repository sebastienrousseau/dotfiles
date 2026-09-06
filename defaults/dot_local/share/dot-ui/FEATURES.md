# dot-ui feature matrix

Every user-visible feature of `dot-ui`, the test(s) that pin it, and the
fuzz/benchmark harness that exercises it. `TestFeatureMatrixComplete`
parses this file and fails if any named test function does not exist;
`TestFeatureMatrixCoversEveryFuzzAndBenchmark` fails if a `Fuzz*` or
`Benchmark*` function is missing from the table. Keep the last column a
list of backticked function names.

## CLI surface

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| cli | Print version | `dot-ui --version`, `-v`, `version` | `TestDispatchVersion` `TestMain_ExitsWithDispatchCode` `BenchmarkDispatchVersion` |
| cli | Usage error on missing subcommand (exit 2) | `dot-ui` | `TestDispatchNoArgs` `TestMain_ExitsWithDispatchCode` |
| cli | Reserved/unknown subcommand falls back (exit 2) | `dot-ui dashboard`, `spin`, `bogus` | `TestDispatchUnknown` |
| cli | Process exit code mirrors dispatch | `main()` via the `exit` seam | `TestMain_ExitsWithDispatchCode` |
| cli | `run` subcommand renders the step view | `dot-ui run < events.ndjson` | `TestDispatchRunSnapshot` `BenchmarkDispatchRunSnapshot` |
| cli | `run` reports render failures (exit 1) | stdout closed | `TestDispatchRunRenderError` |
| cli | `table` subcommand renders a table | `dot-ui table < rows` | `TestDispatchTable` `BenchmarkDispatchTable` |
| cli | `table` reports render failures (exit 1) | stdout closed | `TestDispatchTableRenderError` `TestRunTableWriteError` |
| cli | `pick` subcommand routed through dispatch | `dot-ui pick --header H` | `TestDispatchPickSnapshot` |
| cli | `--header` / `--prompt` flag parsing | `dot-ui pick --header H --prompt P` | `TestParsePickArgs` `FuzzParsePickArgs` `BenchmarkParsePickArgs` |
| cli | Terminal detection seams (production bodies) | stdout/stderr device check, `/dev/tty` open | `TestSeamDefaults` `TestIsTTYOnPipe` `TestIsTTYStatError` `BenchmarkIsTTY` |

## Environment variables

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| env | `DOT_UI_SNAPSHOT=1` renders one static frame | `run` / `pick` | `TestSnapshotMode` `TestDispatchRunSnapshot` `TestCmdPickSnapshotFallsBack` `BenchmarkSnapshotMode` `BenchmarkCmdRunSnapshot` `BenchmarkCmdPickSnapshot` |
| env | `DOT_UI_ACCENT` colour override | valid `#rgb`/`#rrggbb` | `TestLoadPaletteFromEnv` `TestLoadPaletteAllFields` `BenchmarkLoadPalette` |
| env | `DOT_UI_SUCCESS`, `DOT_UI_WARNING`, `DOT_UI_ERROR`, `DOT_UI_INFO` overrides | valid hex | `TestLoadPaletteAllFields` |
| env | `DOT_UI_PANEL`, `DOT_UI_BORDER`, `DOT_UI_FG` overrides | valid hex | `TestLoadPaletteAllFields` |
| env | `DOT_UI_BG` override (empty = terminal default) | valid hex / invalid | `TestLoadPaletteAllFields` |
| env | Invalid or unset colour falls back per field | `DOT_UI_*` malformed | `TestEnvColor` `TestLoadPaletteFallback` `TestParseColor` `FuzzParseColor` `BenchmarkParseColor` `BenchmarkEnvColor` |
| env | Styles derive from the resolved palette | `NewStyles(LoadPalette())` | `TestNewStyles` `TestNewStylesUsesPalette` `BenchmarkNewStyles` |

## `run` — step view

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| run | NDJSON event parsing (blank/invalid lines skipped) | stdin lines | `TestParseEvent` `FuzzParseEvent` `BenchmarkParseEvent` |
| run | `header` event sets title + subtitle | `{"t":"header"}` | `TestApplyHeaderAndSteps` `TestViewRendersStates` |
| run | `step` event adds a step (default state `run`) | `{"t":"step","state":""}` | `TestApplyHeaderAndSteps` `BenchmarkStepApply` |
| run | `step` event updates an existing step in place (state, detail, label) | repeated `id` | `TestApplyHeaderAndSteps` `TestApplyRelabel` |
| run | `na` step never shown; `run→na` hides the step | `state:"na"` | `TestApplyNaDropped` `TestRunThenNaHidden` `TestSnapshotStep` |
| run | Label column width tracks the widest label | mixed label lengths | `TestApplyHeaderAndSteps` `TestApplyRelabel` |
| run | `progress` event drives the bar; clamps overflow | `{"t":"progress"}` | `TestApplyProgressWaitDone` `TestRenderBarClamp` `BenchmarkRenderBar` |
| run | `wait` event shows a transient spinner line; cleared by next step/done | `{"t":"wait"}` | `TestApplyProgressWaitDone` `TestViewWaitAndRunning` |
| run | `done` event finalizes with summary + elapsed | `{"t":"done"}` | `TestApplyProgressWaitDone` `TestViewRendersStates` `TestViewDoneWithoutSummary` |
| run | Unknown event types are ignored | `{"t":"bogus"}` | `TestApplyUnknownEvent` `FuzzStepApply` |
| run | Symbols per state: ✓ ok, · skip, ✗ fail, ⚠ warn, spinner run | View | `TestViewRendersStates` `TestViewWaitAndRunning` `BenchmarkRenderStep` `BenchmarkStepView` |
| run | Bubble Tea `Update`: events fold into the model, `done` quits | `eventMsg` | `TestUpdateEventAndQuit` `BenchmarkStepUpdate` |
| run | Bubble Tea `Update`: stdin EOF finalizes and quits | `streamDoneMsg` | `TestUpdateStreamDoneQuits` `TestRunStepInteractiveEOF` |
| run | Bubble Tea `Update`: spinner ticks | `spinner.TickMsg` | `TestUpdateSpinnerTick` `TestInit` `BenchmarkStepUpdateSpinnerTick` `BenchmarkStepInit` `BenchmarkNewStepModel` |
| run | Key binding `ctrl+c` quits the run view | keyboard | `TestUpdateKeyCtrlCQuits` `TestRunStepInteractiveCtrlC` |
| run | Snapshot frame freezes running steps as skipped | `DOT_UI_SNAPSHOT=1` / no TTY | `TestSnapshotStep` `TestSnapshotStepUnterminated` `TestSnapshotStepWriteError` `BenchmarkSnapshotStep` |
| run | Non-interactive stdout falls back to the snapshot renderer | piped stdout | `TestRunStepNonInteractiveFallsBackToSnapshot` `TestCmdRunNoTerminal` `BenchmarkRunStepNonInteractive` |
| run | Interactive session: keys from `/dev/tty`, events from stdin | terminal stdout | `TestRunStepInteractive` `TestCmdRunInteractive` |

## `pick` — fuzzy picker

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| pick | Candidate rows read from stdin (blank lines dropped) | stdin | `TestReadItems` `FuzzReadItems` `BenchmarkReadItems` |
| pick | Case-insensitive subsequence matching (any script) | typed query | `TestFuzzyMatch` `TestFuzzyMatchNonASCII` `FuzzFuzzyMatch` `BenchmarkFuzzyMatch` |
| pick | Typing narrows the list; cursor resets | rune keys | `TestPickRefilter` `TestPickFilterThenSelect` `BenchmarkPickRefilter` |
| pick | Key binding `backspace` widens the query | keyboard | `TestPickFilterThenSelect` `TestPickUpAndCtrlKeys` |
| pick | Key bindings `up` / `ctrl+p` move the cursor up (clamped) | keyboard | `TestPickUpAndCtrlKeys` `FuzzPickKeys` |
| pick | Key bindings `down` / `ctrl+n` move the cursor down (clamped) | keyboard | `TestPickNavigateAndSelect` `TestPickUpAndCtrlKeys` `BenchmarkPickUpdate` |
| pick | Key binding `enter` selects the highlighted row | keyboard | `TestPickNavigateAndSelect` `TestRunPickInteractiveSelect` `TestRunPickInteractiveFilterSelect` |
| pick | `enter` with no matches cancels | keyboard | `TestPickEnterEmptyCancels` |
| pick | Key bindings `esc` / `ctrl+c` cancel | keyboard | `TestPickCancel` `TestRunPickInteractiveCancel` |
| pick | Multi-rune key events (paste) are ignored | keyboard | `TestPickUpAndCtrlKeys` |
| pick | Window resize sets the visible row budget (3..20) | `tea.WindowSizeMsg` | `TestPickView` `TestPickVisibleRows` `BenchmarkPickVisibleRows` |
| pick | List scrolls to keep the cursor visible | long lists | `TestPickScrollWindow` `BenchmarkPickClampScroll` |
| pick | View: header, prompt (default `›`), cursor marker, counter, hints | View | `TestPickView` `TestPickViewDefaults` `BenchmarkPickView` |
| pick | View: `no matches` placeholder | empty filter | `TestPickViewDefaults` |
| pick | `Init` issues no command | Bubble Tea | `TestPickInit` `BenchmarkPickInit` `BenchmarkNewPickModel` |
| pick | Selected row printed to stdout, exit 0 | interactive Enter | `TestCmdPickInteractive` |
| pick | Cancel prints nothing, exit 1 | interactive Ctrl-C | `TestCmdPickInteractive` |
| pick | No terminal / snapshot → exit 2 so bash falls back to fzf/gum | piped stderr, `DOT_UI_SNAPSHOT=1` | `TestRunPickNonInteractive` `TestCmdPickSnapshotFallsBack` `TestCmdPickNoTerminal` `BenchmarkRunPickNonInteractive` |
| pick | `/dev/tty` unavailable → exit 2 | open failure | `TestCmdPickTTYOpenFails` |
| pick | Bubble Tea start-up failure → exit 2 | closed terminal handle | `TestRunPickProgramError` |

## `table` — static table

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| table | `\x1f`-delimited header + rows render with a rounded border | stdin | `TestRunTable` `FuzzRunTable` `BenchmarkRunTable` |
| table | Empty input renders nothing | empty stdin | `TestRunTableEmpty` |
| table | Header-only input still renders | one line | `TestRunTableHeaderOnly` |
| table | Ragged rows (fewer/more cells) render | uneven rows | `TestRunTableRaggedRows` |
| table | Two-space indent matches `ui.sh` layout | View | `TestRunTable` `Example_runTable` |

## Documentation examples

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| docs | Runnable examples for the public surface | `go test` | `ExampleLoadPalette` `ExampleNewStyles` `Example_parseEvent` `Example_fuzzyMatch` `Example_parsePickArgs` `Example_snapshotStep` `Example_runTable` |
