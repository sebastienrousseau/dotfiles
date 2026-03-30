# Behavioral Traceability

This matrix ties core internal behaviors to implementation files, automated tests, and prose documentation.

It is enforced by `bash ./scripts/qa/traceability-coverage.sh`.

| Behavior ID | Behavior | Implementation | Test Evidence | Documentation |
|-------------|----------|----------------|---------------|---------------|
| BT-01 | AI status, launcher, and cache lifecycle | `scripts/dot/commands/ai.sh` | `tests/unit/dot-cli/test_dot_commands_ai.sh` | `docs/AI.md`, `docs/reference/UTILS.md` |
| BT-02 | Agent profiles, checkpoints, and conformance | `scripts/dot/commands/agent.sh` | `tests/unit/dot-cli/test_dot_commands_agent.sh`, `tests/unit/dot-cli/test_dot_agent_mode.sh`, `tests/unit/dot-cli/test_dot_a2a_conformance.sh` | `docs/operations/TRUSTED_AGENT_WORKSTATION.md`, `docs/interop/A2A.md`, `docs/reference/UTILS.md` |
| BT-03 | MCP policy validation and registry inspection | `scripts/dot/commands/meta.sh`, `scripts/diagnostics/mcp-doctor.sh` | `tests/unit/dot-cli/test_dot_commands_meta.sh`, `tests/unit/dot-cli/test_dot_cli.sh` | `docs/security/MCP_POLICY.md`, `docs/operations/TRUSTED_AGENT_WORKSTATION.md`, `docs/reference/UTILS.md` |
| BT-04 | Fleet status, drift, namespace, and events workflows | `scripts/dot/commands/fleet.sh` | `tests/unit/dot-cli/test_dot_commands_fleet.sh`, `tests/unit/dot-cli/test_dot_fleet_enforcement.sh` | `docs/operations/TRUSTED_AGENT_WORKSTATION.md`, `docs/operations/ATTESTATION.md`, `docs/reference/UTILS.md` |
| BT-05 | Secrets command surface and shell autoload buckets | `scripts/dot/commands/secrets.sh`, `dot_config/shell/10-secrets.sh` | `tests/unit/dot-cli/test_dot_commands_secrets.sh`, `tests/unit/shell/test_shell_secrets_autoload.sh` | `docs/security/SECRETS.md`, `docs/reference/UTILS.md` |
| BT-06 | Theme synchronization and multi-tool theme application | `dot_local/bin/executable_dot-theme-sync` | `tests/unit/theme/test_dot_theme_sync.sh` | `docs/guides/THEMING.md`, `docs/reference/THEMES.md`, `docs/reference/SCRIPTS.md` |
| BT-07 | Reliability audit orchestration | `scripts/qa/reliability-audit.sh` | `tests/unit/misc/test_qa_reliability.sh`, `tests/unit/misc/test_qa_reliability_behaviour.sh` | `docs/operations/RELIABILITY.md`, `docs/operations/TESTING.md` |
| BT-08 | Repository coverage baseline audit | `scripts/qa/coverage-baseline.sh` | `tests/unit/misc/test_qa_coverage_baseline.sh` | `docs/operations/RELIABILITY.md`, `docs/operations/TESTING.md` |
| BT-09 | Documentation coverage contract for public surfaces | `scripts/qa/docs-coverage.sh` | `tests/unit/misc/test_qa_docs_coverage.sh`, `tests/unit/misc/test_qa_docs_repo_coverage.sh` | `docs/operations/RELIABILITY.md`, `docs/reference/UTILS.md`, `docs/reference/SCRIPTS.md` |
| BT-10 | Repository executable-surface coverage gate | `tests/framework/module_coverage.sh` | `tests/unit/tools/test_public_entrypoints.sh`, `tests/unit/misc/test_module_coverage_behaviour.sh` | `docs/operations/TESTING.md`, `docs/security/VERIFICATION_VALIDATION.md`, `docs/reference/SCRIPTS.md` |
