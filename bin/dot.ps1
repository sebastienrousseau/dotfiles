#!/usr/bin/env pwsh
# dot.ps1 — Windows-native PowerShell dispatcher for the dotfiles CLI.
#
# Routes subcommands to the native PowerShell module
# (scripts/dot/powershell/Dot.psm1) where one exists, falls back to
# the bash dispatcher (bin/dot) for everything
# else.
#
# Goals: zero-bash UX for the supported subcommands; transparent
# bash fallback for the rest (mirrors the existing
# windows-smoke-test.ps1 behaviour).
#
# Subcommand routing
#   version | -v | --version  →  Get-DotVersion        (native)
#   help    | -h | --help     →  Invoke-DotHelp        (native)
#   agents check              →  Test-DotAgentsSync    (native)
#   <anything else>           →  bash executable_dot   (fallback)
#
# Exit codes
#   0   command succeeded
#   1   bash fallback failed / bad usage
#   2   bash not on PATH AND command isn't natively supported

#requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Locate this script's repo root so module-import + bash-fallback
# both use the same anchor. Post-Phase 2 (v0.2.503) the dispatcher
# lives at bin/dot.ps1 — repo root is one level up. Legacy install
# location is dot_local/bin/executable_dot.ps1 — two levels up.
# Probe both so chezmoi-deployed and source-tree invocations work.
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path $ScriptPath
$RepoRoot   = $null
foreach ($candidate in @('..', '..\..')) {
    $probe = (Resolve-Path (Join-Path $ScriptDir $candidate)).Path
    if (Test-Path (Join-Path $probe 'scripts/dot/powershell/Dot.psm1')) {
        $RepoRoot = $probe
        break
    }
}
if (-not $RepoRoot) {
    throw "dot.ps1: could not locate repo root from $ScriptDir"
}
$env:DOT_REPO_ROOT = $RepoRoot

Import-Module (Join-Path $RepoRoot 'scripts/dot/powershell/Dot.psm1') -Force

function Invoke-BashFallback {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)] $RemainingArgs)
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bash) {
        Write-Error @"
This subcommand is not yet ported to native PowerShell.
The bash fallback requires 'bash' on PATH (Git for Windows or WSL).

Native PowerShell commands currently supported:
  dot version
  dot help
  dot agents check

For everything else, install:
  scoop install gh git
"@
        exit 2
    }
    $dispatcher = Join-Path $RepoRoot 'bin/dot'
    & bash $dispatcher @RemainingArgs
    exit $LASTEXITCODE
}

# Dispatch -------------------------------------------------------------------

if ($args.Count -eq 0) {
    Invoke-DotHelp
    exit 0
}

$cmd = $args[0]
$rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($cmd) {
    { $_ -in 'version', '-v', '--version' } {
        Get-DotVersion
        exit 0
    }
    { $_ -in 'help', '-h', '--help' } {
        if ($rest.Count -eq 0) {
            Invoke-DotHelp
            exit 0
        }
        # `dot help all` and `dot help <cmd>` still need bash for now.
        Invoke-BashFallback help @rest
    }
    'agents' {
        if ($rest.Count -ge 1 -and $rest[0] -eq 'check') {
            $ok = Test-DotAgentsSync -Verbose:$VerbosePreference
            if ($ok) {
                Write-Host '[OK] AGENTS.md in sync with CLAUDE.md'
                exit 0
            }
            else {
                Write-Error 'AGENTS.md is stale. Run: bash bin/dot agents render'
                exit 1
            }
        }
        Invoke-BashFallback agents @rest
    }
    default {
        Invoke-BashFallback $cmd @rest
    }
}
