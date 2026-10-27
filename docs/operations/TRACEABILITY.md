---
render_with_liquid: false
---

# Behavioral Traceability

This matrix ties core internal behaviors to implementation files, automated tests, and prose documentation.

It is enforced by `bash ./scripts/qa/traceability-coverage.sh`.

| Behavior ID | Behavior | Implementation | Test Evidence | Documentation |
|-------------|----------|----------------|---------------|---------------|
| BT-01 | AI status, launcher, and cache lifecycle | `plugins/ai/libexec/ai.sh` | `tests/unit/dot-cli/test_dot_commands_ai.sh` | `docs/AI.md`, `docs/reference/UTILS.md` |
| BT-02 | Agent profiles, checkpoints, and conformance | `plugins/agent/libexec/agent.sh` | `tests/unit/dot-cli/test_dot_commands_agent.sh`, `tests/unit/dot-cli/test_dot_agent_mode.sh`, `tests/unit/dot-cli/test_dot_a2a_conformance.sh` | `docs/operations/TRUSTED_AGENT_WORKSTATION.md`, `docs/interop/A2A.md`, `docs/reference/UTILS.md` |
| BT-03 | MCP policy validation and registry inspection | `scripts/dot/commands/meta.sh`, `scripts/diagnostics/mcp-doctor.sh` | `tests/unit/dot-cli/test_dot_commands_meta.sh`, `tests/unit/dot-cli/test_dot_cli.sh` | `docs/security/MCP_POLICY.md`, `docs/operations/TRUSTED_AGENT_WORKSTATION.md`, `docs/reference/UTILS.md` |
| BT-04 | Fleet status, drift, namespace, and events workflows | `plugins/fleet/libexec/fleet.sh` | `tests/unit/dot-cli/test_dot_commands_fleet.sh`, `tests/unit/dot-cli/test_dot_fleet_enforcement.sh` | `docs/operations/TRUSTED_AGENT_WORKSTATION.md`, `docs/operations/ATTESTATION.md`, `docs/reference/UTILS.md` |
| BT-05 | Secrets command surface and shell autoload buckets | `plugins/secret/libexec/secrets.sh`, `defaults/dot_config/shell/10-secrets.sh` | `tests/unit/dot-cli/test_dot_commands_secrets.sh`, `tests/unit/shell/test_shell_secrets_autoload.sh` | `docs/security/SECRETS.md`, `docs/reference/UTILS.md` |
| BT-06 | Theme synchronization and multi-tool theme application | `bin/dot-theme-sync` | `tests/unit/theme/test_dot_theme_sync.sh` | `docs/guides/THEMING.md`, `docs/reference/THEMES.md`, `docs/reference/SCRIPTS.md` |
| BT-07 | Reliability audit orchestration | `scripts/qa/reliability-audit.sh` | `tests/unit/misc/test_qa_reliability.sh`, `tests/unit/misc/test_qa_reliability_behaviour.sh` | `docs/operations/RELIABILITY.md`, `docs/operations/TESTING.md` |
| BT-08 | Repository coverage baseline audit | `scripts/qa/coverage-baseline.sh` | `tests/unit/misc/test_qa_coverage_baseline.sh` | `docs/operations/RELIABILITY.md`, `docs/operations/TESTING.md` |
| BT-09 | Documentation coverage contract for public surfaces | `scripts/qa/docs-coverage.sh` | `tests/unit/misc/test_qa_docs_coverage.sh`, `tests/unit/misc/test_qa_docs_repo_coverage.sh` | `docs/operations/RELIABILITY.md`, `docs/reference/UTILS.md`, `docs/reference/SCRIPTS.md` |
| BT-10 | Repository executable-surface coverage gate | `tests/framework/module_coverage.sh` | `tests/unit/tools/test_public_entrypoints.sh`, `tests/unit/misc/test_module_coverage_behaviour.sh` | `docs/operations/TESTING.md`, `docs/security/VERIFICATION_VALIDATION.md`, `docs/reference/SCRIPTS.md` |
| BT-11 | Core apply, diff, status, edit, and commit workflows | `plugins/config/libexec/config.sh` | `tests/unit/dot-cli/test_dot_commands_core.sh`, `tests/unit/dot-cli/test_dot_cli.sh` | `docs/reference/UTILS.md` |
| BT-12 | Alias discovery, search, and governance workflows | `plugins/shell/libexec/aliases.sh` | `tests/unit/dot-cli/test_dot_commands_aliases.sh` | `docs/reference/ALIASES.md`, `docs/reference/UTILS.md` |
| BT-13 | Appearance and theme command workflows | `plugins/system/libexec/system.sh` | `tests/unit/dot-cli/test_dot_commands_appearance.sh` | `docs/guides/THEMING.md`, `docs/reference/UTILS.md` |
| BT-14 | Diagnostics command workflows | `scripts/dot/commands/diagnostics.sh` | `tests/unit/dot-cli/test_dot_commands_diagnostics.sh` | `docs/operations/RELIABILITY.md`, `docs/reference/UTILS.md` |
| BT-15 | Lint command workflow | `plugins/config/libexec/lint.sh` | `tests/unit/dot-cli/test_dot_commands_lint.sh`, `tests/unit/dot-cli/test_lint.sh` | `docs/operations/TESTING.md`, `docs/reference/UTILS.md` |
| BT-16 | AI steering pattern workflows | `plugins/ai/libexec/patterns.sh` | `tests/unit/dot-cli/test_dot_commands_patterns.sh` | `docs/AI.md` |
| BT-17 | Restore and rollback workflows | `plugins/doctor/libexec/restore.sh` | `tests/unit/dot-cli/test_dot_commands_restore.sh` | `docs/reference/UTILS.md` |
| BT-18 | Security command workflows | `plugins/doctor/libexec/doctor.sh` | `tests/unit/dot-cli/test_dot_commands_security.sh` | `docs/reference/UTILS.md`, `docs/security/COMPLIANCE.md` |
| BT-19 | Tool catalog and sandbox workflows | `plugins/config/libexec/config.sh` | `tests/unit/dot-cli/test_dot_commands_tools.sh` | `docs/reference/TOOLS.md`, `docs/reference/UTILS.md` |
| BT-20 | Example validation contract | `scripts/qa/validate-examples.sh` | `tests/unit/misc/test_qa_reliability.sh` | `docs/operations/RELIABILITY.md` |
| BT-21 | WSL parity contract | `scripts/qa/wsl-contract.sh` | `tests/unit/misc/test_qa_reliability.sh` | `docs/operations/RELIABILITY.md`, `docs/reference/SUPPORT_MATRIX.md` |
| BT-22 | Internal behavior traceability contract | `scripts/qa/traceability-coverage.sh` | `tests/unit/misc/test_qa_traceability_coverage.sh` | `docs/operations/TRACEABILITY.md`, `docs/operations/RELIABILITY.md` |
| BT-23 | Multi-format Manual pipeline | `tools/docs/build-manual.sh`, `tools/docs/check-manual.sh`, `scripts/dot/commands/manual.sh` | `tests/unit/docs/test_build_manual.sh`, `tests/unit/docs/test_check_manual.sh`, `tests/unit/dot-cli/test_dot_commands_manual.sh` | `docs/manual/`, `docs/README.md`, `README.md` |
| BT-24 | Multi-harness AI agent context (AGENTS.md generator) | `plugins/agent/libexec/agents.sh` | `tests/unit/auto/test_auto_dot_driver.sh` | `AGENTS.md`, `CLAUDE.md`, `docs/operations/HARD_AUDIT_2026.md` |
| BT-25 | Bootstrap foreign dotfiles repo through chezmoi harness | `plugins/config/libexec/init.sh` | `tests/unit/auto/test_auto_dot_driver.sh` | `docs/operations/ROADMAP_2026.md`, `docs/manual/03-reference/01-dot-cli.md` |
| BT-26 | Module registry discovery and install scaffold | `plugins/cli/libexec/registry.sh` | `tests/unit/auto/test_auto_dot_driver.sh` | `docs/operations/REGISTRY.md`, `docs/registry.json` |
| BT-27 | Workstation environment manifest emitter (`dot env emit`) | `plugins/tool/libexec/env-emit.sh` | `tests/unit/dot-cli/test_cmd_env_emit.sh` | `docs/operations/MANIFEST.md`, `docs/schema/dot-env-v1.json` |
| BT-28 | Cross-file version-string consistency contract | `scripts/qa/check-version-consistency.sh` | `tests/unit/qa/test_check_version_consistency.sh` | `docs/operations/RELIABILITY.md` |
| BT-29 | OpenSSF Scorecard nightly snapshot artefact | `scripts/qa/scorecard-snapshot.sh` | `tests/unit/qa/test_scorecard_snapshot.sh` | `docs/security/SCORECARD.md` |
| BT-30 | Shell completion generator (`dot completion <shell>`) | `plugins/cli/libexec/completion.sh` | `tests/unit/dot-cli/test_dot_completion.sh` | `docs/reference/UTILS.md` |
| BT-31 | Examples coverage contract (feature/command → example) | `scripts/qa/examples-coverage.sh` | `tests/unit/misc/test_qa_examples_coverage.sh` | `docs/reference/UTILS.md` |
| BT-32 | Feature matrix drift gate (command → test, benchmark, example) | `scripts/qa/check-feature-matrix.sh` | `tests/unit/misc/test_qa_check_feature_matrix.sh` | `docs/reference/FEATURE-MATRIX.md`, `docs/operations/TESTING.md` |
| BT-33 | One update path and scheduled maintenance | `lib/dot/upgrade.sh`, `lib/dot/system.sh`, `plugins/system/libexec/system.sh` | `tests/unit/dot-cli/test_upgrade_globals.sh`, `tests/unit/dot-cli/test_system_schedule.sh`, `tests/integration/test_system_schedule_live.sh` | `docs/operations/MAINTENANCE.md` |
