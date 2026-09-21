# ADR-013: Single mutation authority

Status: Accepted for the modular architecture; legacy migration remains incomplete.

## Context

The shell-era adapters combine calculation, application and reloads. ADR-004 and
ADR-005 remain the compatibility contract, not authority for plugins to apply files.

## Decision

Only core owns production writes, backups, recovery, registration, package installs
and process signals. Plugins calculate proposals and write only staged artifacts.
No plugin remains running during core commit. Effects are typed requests, never
shell strings. Unimplemented effects fail closed. A plugin's validation is advisory.

The first implementation is an opt-in hello profile in a newly created private
directory, separate from `dot theme` and all existing workstation commands. Its
two non-secret text outputs demonstrate the boundary without migrating user files.

## Consequences and acceptance

The default command surface is unchanged. The prototype is not production-ready
or an OS sandbox. Tests must show plugin failure cannot reach commit, and recovery
works with the plugin deleted. Migration requires full ownership inventories,
production containment, equivalence tests and separately reviewed platform drivers.
