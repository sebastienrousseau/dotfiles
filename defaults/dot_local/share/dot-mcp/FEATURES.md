# dot-mcp feature matrix

Every user-visible feature of `dot-mcp`, the test(s) that pin it, and the
fuzz/benchmark harness that exercises it. `TestFeatureMatrixComplete`
parses this file and fails if any named test function does not exist;
`TestFeatureMatrixCoversEveryFuzzAndBenchmark` fails if a `Fuzz*` or
`Benchmark*` function is missing from the table. Keep the last column a
list of backticked function names.

## CLI surface

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| cli | Print version | `dot-mcp --version`, `-v`, `version` | `TestDispatch` `TestVersionIsSemver` |
| cli | Usage error on missing subcommand (exit 2) | `dot-mcp` | `TestDispatch` `TestMainExitsWithTheDispatchCode` |
| cli | Unknown subcommand rejected (exit 2) | `dot-mcp listen` | `TestDispatch` |
| cli | `serve` runs the stdio MCP server | `dot mcp serve` | `TestDispatch` `TestEndToEndProtocolExchange` |
| cli | `serve` reports a dead peer (exit 1) | stdout closed | `TestDispatchReportsFailures` |
| cli | `tools` prints the tool/resource manifest as JSON | `dot-mcp tools` | `TestDispatch` `TestWriteToolManifest` `ExampleServer_WriteToolManifest` |
| cli | `tools` reports a write failure (exit 1) | stdout closed | `TestDispatchReportsFailures` `TestWriteToolManifestPropagatesWriteErrors` |
| cli | Process exit code mirrors dispatch | `main()` via the `exit` seam | `TestMainExitsWithTheDispatchCode` |

## Transport — JSON-RPC 2.0 over newline-delimited stdio

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| transport | One JSON object per line, both directions | any exchange | `TestFrameReader` `TestFrameWriter` `BenchmarkReadFrames` `BenchmarkWriteFrame` |
| transport | Blank lines skipped, CRLF tolerated, trailing fragment delivered | ragged client output | `TestFrameReader` `TestTrimEOL` `FuzzReadFrames` |
| transport | Lines longer than the read buffer are reassembled | 200 KiB frame | `TestFrameReader` |
| transport | Frames past the size limit are refused, not buffered | 8 MiB+ line | `TestFrameReaderRejectsOversizeFrame` `TestOversizeFrameEndsTheSessionCleanly` |
| transport | A read failure is a transport error, not a clean EOF | broken pipe | `TestFrameReaderPropagatesReadError` `TestServeReturnsTransportErrors` |
| transport | Envelope validation: version, method, id type | malformed frames | `TestDecodeRequest` `TestValidIDRejectsGarbage` `FuzzDecodeRequest` `BenchmarkDecodeRequest` |
| transport | Request ids are echoed back verbatim (string, number, null) | mixed id types | `TestFrameWriter` `FuzzDecodeRequest` |
| transport | Notifications are never answered | `id`-less frames | `TestNotificationsAreNeverAnswered` `TestDecodeRequest` |
| transport | A write failure ends the session with an error | closed stdout | `TestFrameWriterErrors` `TestServeReturnsTransportErrors` |
| transport | stdout carries protocol frames only; logs go to stderr | any session | `TestServeLogsOnlyToStderr` `TestEndToEndKeepsStdoutClean` `FuzzServeSession` |
| transport | EOF on stdin is a clean shutdown (exit 0) | client closes the pipe | `TestEndToEndShutsDownOnEOF` `BenchmarkServeSession` |

## Lifecycle

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| lifecycle | `initialize` negotiates the protocol version | supported / unknown version | `TestInitializeNegotiatesTheProtocolVersion` `TestServerCardProtocolVersionsAreSupported` |
| lifecycle | `initialize` declares exactly the implemented capabilities | handshake | `TestInitializeDeclaresOnlyImplementedCapabilities` `ExampleServer_Serve` |
| lifecycle | `initialize` returns serverInfo and instructions | handshake | `TestInitializeDeclaresOnlyImplementedCapabilities` `TestEndToEndProtocolExchange` |
| lifecycle | Malformed `initialize` params are rejected | `"params":"x"` | `TestInitializeRejectsMalformedParams` |
| lifecycle | `notifications/initialized` completes the handshake | notification | `TestNotificationsAreNeverAnswered` |
| lifecycle | Unknown and cancellation notifications are ignored | notification | `TestNotificationsAreNeverAnswered` |
| lifecycle | Requests before `initialize` are refused; `ping` is exempt | early `tools/list` | `TestRequestsBeforeInitializeAreRejected` |
| lifecycle | `ping` answers with an empty result | keepalive | `TestRequestsBeforeInitializeAreRejected` `TestEndToEndShutsDownOnEOF` |

## Tools

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| tools | `tools/list` returns every registered tool with a JSON Schema | `tools/list` | `TestToolsListMatchesTheRegistry` `BenchmarkToolsList` |
| tools | Every tool is annotated read-only, non-destructive, closed-world | manifest | `TestDefaultToolsAreReadOnly` |
| tools | `mcp-doctor` runs `dot mcp doctor --json [--strict]` | `tools/call` | `TestToolArgv` `TestToolsCallRunsTheTool` `TestEndToEndProtocolExchange` |
| tools | `agent-mode` runs `dot mode current\|list\|show <profile>` | `tools/call` | `TestToolArgv` `TestConditionalRequirements` |
| tools | `workstation-attestation` runs `dot attest --json` | `tools/call` | `TestToolArgv` `TestToolsCallWithoutArguments` |
| tools | `fleet-status` runs `dot fleet status --json` | `tools/call` | `TestToolArgv` `TestLoggingSetLevel` |
| tools | Arguments are validated against the published schema | bad arguments | `TestValidateArgs` `TestToolsCallRejections` `FuzzValidateArgs` `BenchmarkValidateArgs` |
| tools | Unknown arguments rejected deterministically (closed schema) | extra keys | `TestValidateArgsReportsUnknownKeysDeterministically` |
| tools | Declared `pattern` is the regexp actually enforced | `profile` argument | `TestEveryPatternIsCompiled` `TestValidateArgs` |
| tools | Defaults are injected; an unsupported schema type is refused | omitted arguments | `TestValidateArgs` `TestCoerceRejectsUnsupportedSchemaType` |
| tools | Cross-field rule: `show` requires `profile` | `action:"show"` | `TestConditionalRequirements` `TestToolsCallRejections` |
| tools | Unknown tool name is an invalid-params error | `tools/call` | `TestToolsCallRejections` `TestLookupToolMiss` |
| tools | A command that cannot be started is an internal error | missing `dot` | `TestToolsCallReportsExecutionFailure` |
| tools | A JSON report becomes structuredContent with its exit code | `dot ... --json` | `TestBuildCallResult` `TestBuildCallResultExitCodeIsAnInt` `ExampleServer_Serve_toolsCall` `BenchmarkBuildCallResult` |
| tools | A non-zero exit with a report is data, not a tool error | policy warnings | `TestBuildCallResult` `TestToolsCallRunsTheTool` |
| tools | A failing command folds stderr into an `isError` result | exit 4 | `TestBuildCallResult` `TestEndToEndKeepsStdoutClean` `FuzzBuildCallResult` |
| tools | Every result carries exactly one non-empty text block | any outcome | `FuzzBuildCallResult` `TestBuildCallResult` |
| tools | JSON classification of command output | text vs object vs array | `TestDecodeJSONObject` |
| tools | Commands run without a shell, with no stdin, under a timeout | `tools/call` | `TestExecRunner` `TestExecRunnerHonoursTheContextDeadline` `BenchmarkToolsCall` |
| tools | The child gets `NO_COLOR` and the resolved repo root | `tools/call` | `TestChildEnvIsPlainAndRooted` |

## Resources

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| resources | `resources/list` returns the fixed URI table | `resources/list` | `TestResourcesListAndRead` `TestEndToEndProtocolExchange` |
| resources | Each URI resolves to one known configuration file | resolver table | `TestResourceResolvers` `TestConfigPath` |
| resources | The bash commands' env overrides are honoured | `MCP_POLICY_CONFIG` etc. | `TestResourceEnvOverridesAreHonoured` |
| resources | `resources/read` returns the document as text | `resources/read` | `TestResourcesListAndRead` `TestReadResource` |
| resources | Unknown URI, missing file, unresolvable tree and oversize file are refused | bad reads | `TestResourcesReadFailures` `TestReadResource` `TestOSReadFileSeam` |
| resources | Malformed `resources/read` params are an invalid-params error | `"params":[]` | `TestResourcesReadMalformedParams` |
| resources | `resources/templates/list` is empty — no templated URIs | `resources/templates/list` | `TestResourcesListAndRead` |

## Logging

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| logging | Tool calls emit `notifications/message` | `tools/call` | `TestToolsCallRunsTheTool` |
| logging | `logging/setLevel` raises the threshold and suppresses lower levels | `logging/setLevel` | `TestLoggingSetLevel` `TestLevelIndex` |
| logging | An unknown level or malformed params is rejected | bad level | `TestLoggingSetLevelRejections` |
| logging | A log notification that cannot be written is dropped, not fatal | closed stdout | `TestNotifyLogSurvivesAWriteFailure` |

## Errors

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| errors | Unparsable frame answered with `-32700` and a null id | `{` | `TestMalformedFrameIsAnsweredWithANullID` |
| errors | Invalid envelope answered with `-32600` | wrong `jsonrpc` | `TestDecodeRequest` |
| errors | Unknown method answered with `-32601` | `prompts/list` | `TestUnknownMethod` `TestEndToEndProtocolExchange` |
| errors | Bad arguments answered with `-32602` | `tools/call` | `TestToolsCallRejections` |
| errors | Unserved resource answered with `-32002` | `resources/read` | `TestResourcesReadFailures` |
| errors | The error object carries a message and a diagnostic payload | any rejection | `TestRPCErrorImplementsError` `TestFrameWriter` |
| errors | Absent or null `params` are tolerated | optional arguments | `TestDecodeParamsToleratesAbsentParams` `TestToolsCallWithoutArguments` |
| errors | A malformed frame does not end the session | `{`, then a handshake | `TestMalformedFrameIsAnsweredWithANullID` `FuzzServeSession` `BenchmarkServeSession` |

## Filesystem resolution

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| paths | `DOT_MCP_REPO_ROOT`, then a marker walk, then the chezmoi source dir | server start | `TestRepoRoot` `TestRepoRootStopsWalkingAtTheFilesystemRoot` |
| paths | Broken `getwd`/`home` seams degrade to "unresolved" | daemon environment | `TestRepoRootSurvivesBrokenSeams` `TestEnvironmentGetAndExists` |
| paths | Checkout, chezmoi-source and deployed layouts all probed | `configPath` | `TestConfigPath` `TestWellKnownPath` |
| paths | `DOT_MCP_DOT_BIN` selects the CLI, else `dot` from PATH | `tools/call` | `TestDotBinary` `TestToolsCallRunsTheTool` |
| paths | Production seams (env, cwd, home, stat, ReadFile) exercised | real process | `TestOSEnvironmentSeams` `TestOSReadFileSeam` |

## Card truth

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| card | Declared tools and served tools are the same set | `server-card.json` | `TestServerCardMatchesRegistry` |
| card | Declared resources and served resources are the same set | `server-card.json` | `TestServerCardMatchesResources` |
| card | Every declared capability is implemented; `prompts` stays false | `server-card.json` | `TestServerCardCapabilitiesAreImplemented` |
| card | `transport.stdio` is the command that starts this server | `server-card.json` | `TestServerCardTransportLaunchesTheServer` |
| card | Card version and `serverInfo.version` never drift | release sync | `TestVersionMatchesServerCard` |
| card | The card names the module that implements it | `server-card.json` | `TestServerCardPointsAtThisModule` |
| card | The A2A card's `mcp` entrypoint is the same command | `agent-card.json` | `TestAgentCardEntrypointMatchesTheTransport` |

## Harness

| Area | Feature | Trigger | Tests |
| :--- | :--- | :--- | :--- |
| harness | The real binary speaks the protocol over real pipes | `go test` | `TestEndToEndProtocolExchange` `TestEndToEndShutsDownOnEOF` `TestEndToEndKeepsStdoutClean` |
| harness | A whole session survives arbitrary input without panicking | fuzzing | `FuzzServeSession` `FuzzReadFrames` `FuzzDecodeRequest` `FuzzValidateArgs` `FuzzBuildCallResult` |
| harness | Per-frame hot path is benchmarked | `go test -bench` | `BenchmarkReadFrames` `BenchmarkDecodeRequest` `BenchmarkValidateArgs` `BenchmarkToolsList` `BenchmarkToolsCall` `BenchmarkBuildCallResult` `BenchmarkServeSession` `BenchmarkWriteFrame` |
| harness | This matrix is checked against the test files in both directions | `go test` | `TestFeatureMatrixComplete` `TestFeatureMatrixCoversEveryFuzzAndBenchmark` |
| harness | Small helpers are covered directly | `go test` | `TestContainsString` `TestOrUnknown` `TestFrameWriterErrors` |
