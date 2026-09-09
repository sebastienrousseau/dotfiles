# dot-ai-tui feature matrix

Every user-visible feature of the `dot ai` cockpit, the test(s) that pin
it, and the fuzz/benchmark harness that exercises it.
`TestFeatureMatrixComplete` parses this file and fails if any named test
function does not exist; `TestFeatureMatrixCoversEveryFuzzAndBenchmark`
fails if a `Fuzz*` or `Benchmark*` function is missing from the table.
Keep the last column a list of backticked function names.

## Process and environment

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| process | Full-screen cockpit starts (alt-screen) and returns on a headless terminal | `dot-ai-tui` | `TestRunNoTTY` |
| process | Run errors print `dot-ai-tui: <err>` and exit 1 | `main()` via the `exit` seam | `TestMainErrorExit` `BenchmarkMainSnapshot` |
| env | `DOT_AI_SNAPSHOT=1` prints one 94×26 frame with a sample transcript and open palette | CI / previews | `TestRunSnapshot` `TestCoverageGaps3` `BenchmarkRunSnapshot` `BenchmarkRenderSnapshot` |
| env | `DOT_AI_SPLASH=1` previews the empty-state splash instead | with `DOT_AI_SNAPSHOT` | `TestRenderSnapshotSplash` |
| env | `DOT_AI_HOST` / `DOT_AI_PORT` locate the gateway (default `127.0.0.1:3456`) | health check | `TestPureHelpers` `TestGatewayURL` `FuzzGatewayURL` `BenchmarkGatewayURL` `BenchmarkGatewayBase` `BenchmarkEnvOr` |
| env | `XDG_DATA_HOME` (else `~/.local/share`) locates `dotfiles-ai.db` | cost + recent runs | `TestPureHelpers` `BenchmarkDbPath` |
| env | `XDG_STATE_HOME` (else `~/.local/state`) locates the saved session | `/save`, `/resume` | `TestSessionPersistence` `TestSessionPathDefault` `BenchmarkSessionPath` |

## Data gathering

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| refresh | Installed tools detected on `PATH` | start, `c`/`r`, after shell-outs | `TestRefresh` `TestCoverageGaps` `BenchmarkRefresh` `BenchmarkExecDone` |
| refresh | Gateway health chip (`● host:port` / `○ gateway off`) | `GET /health` contains `healthy` | `TestRefresh` `TestRenderChrome` `TestRenderPaths` |
| refresh | Today's spend from sqlite (`$0.00` when absent) | `runs` table | `TestRefresh` `TestCoverageGaps` `TestSqlite` `BenchmarkSqliteMissingDB` |
| refresh | Last 8 runs listed for the splash | `runs` table | `TestRefresh` `TestSplash` |
| refresh | sqlite3 output scrubbed of `~/.sqliterc` meta lines | `.timer`, `Run Time:` | `TestCoverageGaps` `TestFilterSqliteOutput` `FuzzFilterSqliteOutput` `BenchmarkFilterSqliteOutput` |
| refresh | Missing DB or invalid SQL yields empty | error paths | `TestSqlite` `TestCoverageGaps2` |

## Fleet pane (focus `fleet`)

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| fleet | Key bindings `up`/`k` and `down`/`j` move the cursor (clamped) | keyboard | `TestCursorBounds` `TestUpdateFleet` `FuzzModelKeys` `BenchmarkUpdateFleet` `BenchmarkModelUpdateKeyFleet` |
| fleet | Key binding `enter` opens the tool's native session (`dot ai chat <tool>`) | keyboard | `TestUpdateFleet` `BenchmarkDotExec` |
| fleet | Key binding `tab` jumps to the chat input | keyboard | `TestUpdateMsgs` |
| fleet | Key binding `/` opens the input pre-filled with `/`; `p` opens it empty | keyboard | `TestUpdateFleet` |
| fleet | Key bindings `c`/`r` refresh (status `refreshing…`) | keyboard | `TestUpdateFleet` |
| fleet | Key binding `i` installs the selected tool (`dot ai install <tool>`) | keyboard | `TestUpdateFleet` |
| fleet | Key binding `m` cycles the model override (default → opus → sonnet → haiku) | keyboard | `TestModelPicker` `FuzzModelCycle` `BenchmarkNextModel` `BenchmarkModelLabel` |
| fleet | Key binding `s` starts the gateway, or stops it when it is up | keyboard | `TestUpdateFleet` |
| fleet | Key bindings `q`/`esc` quit | keyboard | `TestUpdateFleet` |
| fleet | Key binding `ctrl+c` quits from any pane | keyboard | `TestUpdateMsgs` |
| fleet | Fleet grouped by role with install dots, windowed to the panel height | View | `TestRenderChrome` `TestRenderPaths` `FuzzWindowRows` `BenchmarkWindowRows` |

## Chat input (focus `input`)

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| input | Typing edits the prompt (2000-char limit) | keyboard | `TestUpdateInput` `BenchmarkUpdateInput` `BenchmarkModelUpdateKeyInput` |
| input | Key binding `enter` sends the prompt to `dot ai <tool> [--style s]` and streams the reply | keyboard | `TestUpdateInput` `TestStartStreamAndExec` `BenchmarkStartStream` `BenchmarkWaitForChunk` |
| input | Empty prompt is a no-op; sending while a reply is running is ignored | keyboard | `TestUpdateInput` |
| input | Key binding `esc` returns to the fleet (closes the palette first) | keyboard | `TestUpdateInput` |
| input | Key binding `tab` returns to the fleet, or completes the open palette | keyboard | `TestUpdateMsgs` `TestUpdateInput` |
| input | Streaming: chunks append live, `done` trims and persists the turn | `streamMsg` | `TestUpdateMsgs` `BenchmarkModelUpdateStream` |
| input | Streaming: empty reply shows an install/auth hint | `streamMsg` | `TestUpdateMsgs` |
| input | Streaming: a failed turn is surfaced as an `error:` line in the error colour, not highlighted as a reply | `streamMsg` err | `TestUpdateMsgs` `TestErrorLineStyled` |
| input | Streaming: pipe/start failures surface as errors | `startStream` | `TestStartStreamAndExec` `TestStartStreamPipeError` |
| input | Spinner ticks only while a reply is running | `spinner.TickMsg` | `TestUpdateMsgs` `BenchmarkModelUpdateSpinner` |
| input | Desktop notification after a reply that took ≥ 8 s (osascript / notify-send) | `streamMsg` done | `TestNotifyAndDoneHook` `TestNotifyCmdPlatforms` `BenchmarkNotify` `BenchmarkNotifyCmd` |
| input | Multi-turn context flattened into each one-shot prompt | send | `TestBuildPrompt` `FuzzBuildPrompt` `BenchmarkBuildPrompt` |
| input | Model override exported as `ANTHROPIC_MODEL`; `DOT_AI_RAW=1` suppresses banners | send | `TestStartStreamAndExec` |

## `/` command palette

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| palette | Opens when the input starts with `/`; lists cockpit + tool-specific commands | typing | `TestPalette` `FuzzPalette` `BenchmarkPalette` |
| palette | Prefix filtering; cockpit labels shadow duplicate tool labels | typing | `TestPalette` `TestCoverageGaps` |
| palette | Key bindings `up`/`ctrl+p` and `down`/`ctrl+n` move the selection | keyboard | `TestUpdateInput` |
| palette | Key binding `tab` completes the selected command | keyboard | `TestUpdateInput` |
| palette | Key binding `enter` runs a cockpit command or opens the tool session for a native one | keyboard | `TestUpdateInput` |
| palette | Rendered rows (≤ 8) with `→ <tool> session` hints | View | `TestRenderPaths` `TestCoverageGaps` `BenchmarkRenderPalette` `BenchmarkModelViewPalette` |

## Slash commands

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| slash | `/help`, `/?` list the commands | chat | `TestHandleSlashAll` `FuzzHandleSlash` `BenchmarkHandleSlash` |
| slash | `/model` shows the choices; `/model <name>` sets; `/model default` or `off` clears | chat | `TestModelPicker` |
| slash | `/style <name>` sets the steering style; `/style` or `/style off` clears | chat | `TestSlashCommands` `TestHandleSlashAll` |
| slash | `/tool <name>` selects a fleet tool; unknown names are reported | chat | `TestSlashCommands` `TestHandleSlashAll` |
| slash | `/save` persists the transcript; `/resume` restores it (or reports none) | chat | `TestSessionPersistence` `BenchmarkSaveSession` `BenchmarkLoadSession` |
| slash | `/clear` empties the transcript | chat | `TestSlashCommands` `TestHandleSlashAll` |
| slash | `/serve` starts the gateway; `/cost` opens the spend report | chat | `TestHandleSlashAll` |
| slash | `/exit`, `/quit`, `/q` quit | chat | `TestHandleSlashAll` |
| slash | Unknown commands get a `/help` hint | chat | `TestHandleSlashAll` |

## Rendering

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| view | `loading dot ai…` placeholder before sizing, below 40×12, or with no fleet | View | `TestViewNeverPanics` `TestRenderPaths` `BenchmarkModelView` `BenchmarkModelUpdateResize` `BenchmarkModelUpdateRefresh` `BenchmarkNewModel` `BenchmarkModelInit` |
| view | Header: logo, tagline, model/style chips, gateway + cost chips (gap clamps on narrow terminals) | View | `TestRenderChrome` `TestModelPicker` `TestCoverageGaps2` |
| view | Left pane width 18..26, right pane fills the rest | resize | `TestPureHelpers` `BenchmarkLeftWidth` `BenchmarkRightWidth` |
| view | Focused pane gets the violet border | focus | `TestRenderPaths` |
| view | Splash (wordmark, pitch, quick keys) with up to 3 recent runs when the chat is empty | View | `TestSplash` `BenchmarkSplash` `BenchmarkRenderTranscriptSplash` |
| view | Splash survives a panel too short for the recent block | tiny terminal + palette | `TestRenderTranscriptTinyHeightWithRecent` `FuzzRenderTranscript` |
| view | Splash clamps a zero or negative height | tiny terminal | `TestSplashClampsNegativeHeight` |
| view | Transcript returns exactly `max(h,1)` physical rows whatever the author or body contains | any transcript | `TestRenderTranscriptRowContract` `FuzzRenderTranscript` |
| view | A resumed session cannot overflow the terminal it was sized for | `/resume` of an arbitrary session.json | `TestResumedSessionCannotOverflow` |
| view | Transcript pinned to the bottom, exactly `h` lines, wrapped prose | View | `TestCoverageGaps2` `TestCoverageGaps4` `TestCoverageGaps5` `TestCoverageGaps6` `BenchmarkRenderTranscript` |
| view | Fenced code syntax-highlighted with chroma; prose untouched | View | `TestHighlightCode` `TestHighlightFallback` `FuzzHighlight` `BenchmarkHighlight` `BenchmarkHighlightProse` |
| view | Fence language tags validated and memoised (no render stall on hostile tags) | View | `TestResolveLang` `TestHighlightHugeLangTag` `BenchmarkResolveLang` |
| view | Footer keybar switches with focus; status message prefixes it | View | `TestRenderPaths` |
| view | `thinking…` spinner replaces the input while a reply streams | View | `TestRenderPaths` |

## Persistence and helpers

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| session | Session JSON round-trips; corrupt files load as empty | `/save`, `/resume` | `TestSessionPersistence` `TestParseSessionMalformed` `FuzzParseSession` `BenchmarkParseSession` |
| session | Unwritable state dir is a silent no-op | `/save` | `TestSaveSessionUnwritable` |
| session | A failed encode leaves the saved session untouched | `/save` | `TestSaveSessionMarshalFailure` |
| helpers | `clampi`, `windowRows`, `nowUnix`, `execDone` | internal | `TestPureHelpers` `TestCoverageGaps3` `TestCoverageGaps4` `BenchmarkClampi` `BenchmarkNowUnix` |

## Documentation examples

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| docs | Runnable examples for the helper surface | `go test` | `Example_buildPrompt` `Example_highlight` `Example_resolveLang` `Example_windowRows` `Example_nextModel` `Example_filterSqliteOutput` `Example_parseSession` `Example_gatewayURL` `Example_clampi` |
