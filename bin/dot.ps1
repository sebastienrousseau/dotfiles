#!/usr/bin/env pwsh
# dot.ps1 — Windows-native PowerShell dispatcher for the dotfiles CLI.
#
# Routes daily commands to the native PowerShell module and uses an
# explicit bash bridge for Unix-specific orchestration.
#
# Goals: zero-bash UX for the supported subcommands; transparent
# bash fallback for the rest (mirrors the existing
# windows-smoke-test.ps1 behaviour).
#
# Subcommand routing
#   version | -V | --version  →  Get-DotVersion        (native)
#   help    | -h | --help     →  Invoke-DotHelp        (native)
#   status/diff/apply/sync    →  native chezmoi calls
#   doctor, tool list, fleet  →  native PowerShell views
#   agent context check/show  →  native PowerShell checks
#   <anything else>           →  bash executable_dot   (fallback)
#
# Only ADR-020 spellings are native. Old names (agents, env, add, init,
# -v, …) and `dot update` (dot system update) go to the bash dispatcher,
# so they warn, expire and behave exactly as they do on macOS and Linux.
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
  dot status | diff | apply | sync | cd
  dot doctor
  dot tool list
  dot agent context check | show
  dot fleet status

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
# Force-wrap with @() so single-element slices stay arrays under
# Set-StrictMode -Latest (otherwise `$rest.Count` and `$rest[0]` fail
# when `$args.Count -eq 2` because PowerShell auto-unwraps single-element arrays).
$rest = @(if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() })

switch ($cmd) {
    { $_ -in 'version', '-V', '--version' } {
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
    'agent' {
        if ($rest.Count -lt 1 -or $rest[0] -ne 'context') {
            Invoke-BashFallback agent @rest
        }
        if ($rest.Count -ge 2 -and $rest[1] -eq 'check') {
            $ok = Test-DotAgentsSync -Verbose:$VerbosePreference
            if ($ok) {
                Write-Host '[OK] AGENTS.md in sync with CLAUDE.md'
                exit 0
            }
            else {
                Write-Error 'AGENTS.md is stale. Run: bash bin/dot agent context apply'
                exit 1
            }
        }
        if ($rest.Count -eq 1 -or $rest[1] -eq 'show') {
            Get-DotAgents | Format-Table -AutoSize
            exit 0
        }
        Invoke-BashFallback agent @rest
    }
    'status' {
        Get-DotStatus
        exit 0
    }
    'diff' {
        Invoke-DotChezmoi -Operation diff -Arguments $rest
        exit 0
    }
    { $_ -in 'apply', 'sync' } {
        Invoke-DotChezmoi -Operation apply -Arguments $rest
        exit 0
    }
    'cd' {
        Get-DotSourcePath
        exit 0
    }
    'doctor' {
        if (Invoke-DotDoctor) { exit 0 }
        exit 1
    }
    'tool' {
        if ($rest.Count -eq 0 -or $rest[0] -eq 'list') {
            $json = $rest -contains '--json'
            Get-DotEnvironment -AsJson:$json
            exit 0
        }
        Invoke-BashFallback tool @rest
    }
    'fleet' {
        if ($rest.Count -eq 0 -or $rest[0] -eq 'status') {
            $json = $rest -contains '--json'
            if ($json) { Get-DotFleetStatus -AsJson }
            else { Get-DotFleetStatus | Format-List }
            exit 0
        }
        Invoke-BashFallback fleet @rest
    }
    default {
        Invoke-BashFallback $cmd @rest
    }
}
