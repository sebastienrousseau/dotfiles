# PowerShell Parity

This page documents how PowerShell 7.5+ support is exercised in CI
and what specifically is verified. Closes the docs slice of
[#860](https://github.com/sebastienrousseau/dotfiles/issues/860).

## What ships

| File | Role |
|---|---|
| [`dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl`](../../dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl) | The dotfiles PowerShell profile. Deployed to `$PROFILE` (resolves to `~/.config/powershell/Microsoft.PowerShell_profile.ps1` on Linux/macOS; `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` on Windows). |
| [`scripts/qa/powershell-contract.ps1`](../../scripts/qa/powershell-contract.ps1) | The runtime contract. Renders the template, dot-sources it, asserts required function shims exist, runs PSScriptAnalyzer. |
| [`tests/unit/install/test_powershell_profile_syntax.sh`](../../tests/unit/install/test_powershell_profile_syntax.sh) | Static-syntax test runnable on Linux/macOS via `pwsh` when present; falls back to brace-balance + textual invariants when not. |

## What's verified

### On every Linux/macOS PR (`tests/unit/install/...`)

- Profile file exists at the expected path.
- Defines the `dot` function shim so PowerShell users invoke the
  same CLI as Unix shells.
- Sets `XDG_CONFIG_HOME` (matches Unix XDG conventions for
  `~/.config/powershell` discoverability).
- Brace count balances (`{` vs `}`).
- If `pwsh` is installed locally, parses the rendered template via
  `System.Management.Automation.Language.Parser` and fails on any
  parse error.

### On `windows-latest` runner via reliability-gate.yml

The `powershell-contract` job runs `scripts/qa/powershell-contract.ps1`
which does:

1. **Renders the template** via `chezmoi execute-template` so any
   chezmoi data references (e.g. `{{ .dotfiles_version }}`) resolve
   to real values before parsing.
2. **Dot-sources** the rendered profile and asserts no exception is
   thrown during load.
3. **Asserts the required function shims** are defined after load:
   `dot`, `d`, `ll`, `la`, `cat`.
4. **Runs PSScriptAnalyzer** at `Error` severity. Warnings surface
   but don't fail the gate (tightenable later).

Exit non-zero on any failure. The job is in the `reliability-summary`
required-checks list so a broken PowerShell profile blocks merge.

## Running locally

### On Linux/macOS

```bash
# Static test — runs in any context.
bash tests/unit/install/test_powershell_profile_syntax.sh

# Full contract — needs pwsh + chezmoi installed.
brew install --cask powershell   # or apt / package manager equivalent
pwsh ./scripts/qa/powershell-contract.ps1
```

### On Windows

```powershell
.\scripts\qa\powershell-contract.ps1
```

## Known limitations

- The contract doesn't currently exercise PowerShell-specific runtime
  semantics (e.g. PSDrive providers, custom completion). Those are a
  follow-up.
- Function shims are smoke-tested by name only — we check that
  `Get-Command dot` resolves to a function, not that it actually
  invokes the right binary. A richer integration test that creates a
  fake `dot` binary and confirms the shim invokes it correctly is a
  future hardening step.
- macOS is not in the matrix because `pwsh` isn't pre-installed on
  GitHub macOS runners. The Linux/macOS static test runs on every PR
  via the existing test suite; full pwsh validation is Windows-only
  to keep the matrix small.

## When to update this page

- The PowerShell profile gains a new function → add it to the
  `RequiredFunctions` array in `powershell-contract.ps1` AND to the
  list above.
- A static-test invariant is added → document it in the "What's
  verified on every PR" list.
- The PSScriptAnalyzer severity is tightened from `Error` to
  `Warning` → update the relevant bullet here.

## References

- [PowerShell 7 docs](https://learn.microsoft.com/en-us/powershell/scripting/overview)
- [PSScriptAnalyzer rule reference](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/docs/Rules/README.md)
- `.github/workflows/reliability-gate.yml` — Windows job definition.
- Issue [#860](https://github.com/sebastienrousseau/dotfiles/issues/860).
