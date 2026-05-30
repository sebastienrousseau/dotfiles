# Dot — native PowerShell module for the dotfiles framework.
#
# This module provides native PowerShell cmdlets for the subset of
# `dot` subcommands that don't require bash. Closes Stub rows in
# docs/reference/POWERSHELL_PARITY.md.
#
# Loaded by bin/dot.ps1 dispatcher; cmdlets are also callable
# directly:
#   Import-Module ./scripts/dot/powershell/Dot.psm1
#   Get-DotVersion
#   Invoke-DotHelp
#   Test-DotAgentsSync -Verbose
#
# Tested via scripts/ci/windows-smoke-test.ps1.

#requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module-level constants -------------------------------------------------------

$script:RepoRoot = if ($env:DOT_REPO_ROOT) {
    $env:DOT_REPO_ROOT
}
else {
    # When called from bin/dot.ps1 the dispatcher sets DOT_REPO_ROOT.
    # When imported directly, infer it from this file's path:
    #   scripts/dot/powershell/Dot.psm1  →  ../../..
    (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

# Post-Phase-4b (v0.2.503) .chezmoidata.toml ships under defaults/.
# Probe defaults/ first; fall back to legacy root location for older
# deployments that pre-date the .chezmoiroot activation.
$script:DataFile = Join-Path $script:RepoRoot 'defaults/.chezmoidata.toml'
if (-not (Test-Path $script:DataFile)) {
    $script:DataFile = Join-Path $script:RepoRoot '.chezmoidata.toml'
}

# Helpers ---------------------------------------------------------------------

function script:Get-DotfilesVersionFromData {
    if (-not (Test-Path $script:DataFile)) {
        throw "Cannot read $script:DataFile (set DOT_REPO_ROOT to override)"
    }
    $line = Get-Content $script:DataFile |
        Where-Object { $_ -match '^dotfiles_version\s*=\s*"([^"]+)"' } |
        Select-Object -First 1
    if (-not $line) {
        throw "dotfiles_version not found in $script:DataFile"
    }
    if ($line -notmatch '"([^"]+)"') {
        throw "Could not parse dotfiles_version from line: $line"
    }
    return $Matches[1]
}

function script:Write-DotBanner {
    param([string]$Section)
    if ($env:NO_COLOR) {
        Write-Host "Dot · $Section"
        return
    }
    $esc = [char]27
    Write-Host "$esc[1;38;5;212mDot · $Section$esc[0m"
}

# Public cmdlets --------------------------------------------------------------

<#
.SYNOPSIS
    Print the dotfiles framework version.

.DESCRIPTION
    Native PowerShell implementation of `dot version`. Reads the
    canonical version from .chezmoidata.toml (the single source of
    truth) — does NOT shell out to bash.

.EXAMPLE
    Get-DotVersion
    0.2.503

.EXAMPLE
    Get-DotVersion -AsObject | ConvertTo-Json
    {
      "Version": "0.2.503",
      "Source": "...\\.chezmoidata.toml",
      "Native": true
    }
#>
function Get-DotVersion {
    [CmdletBinding()]
    param(
        [switch]$AsObject
    )
    $version = Get-DotfilesVersionFromData
    if ($AsObject) {
        return [pscustomobject]@{
            Version = $version
            Source  = $script:DataFile
            Native  = $true
        }
    }
    return $version
}

<#
.SYNOPSIS
    Print the dot CLI help overview.

.DESCRIPTION
    Native PowerShell implementation of `dot help`. Reads command
    metadata from CLAUDE.md / the dispatcher's help table; does
    NOT shell out to bash.

    The full Linux-style help (every subcommand grouped by category)
    requires the bash dispatcher; this cmdlet shows the Windows-
    native subset.
#>
function Invoke-DotHelp {
    [CmdletBinding()]
    param()
    $version = Get-DotfilesVersionFromData
    Write-DotBanner -Section 'Help'
    Write-Host ''
    Write-Host "  Version    v$version"
    Write-Host "  Repo       https://github.com/sebastienrousseau/dotfiles"
    Write-Host "  Docs       https://github.com/sebastienrousseau/dotfiles/blob/master/docs/manual/"
    Write-Host ''
    Write-Host 'Native PowerShell commands (no bash required):'
    Write-Host ''
    Write-Host '  Get-DotVersion              Print framework version'
    Write-Host '  Invoke-DotHelp              This screen'
    Write-Host '  Test-DotAgentsSync          Check AGENTS.md ↔ CLAUDE.md sync'
    Write-Host ''
    Write-Host 'Bash-bridged subcommands (require bash on PATH):'
    Write-Host ''
    Write-Host '  dot doctor                  Deep environment audit'
    Write-Host '  dot env list                List installed mise tools'
    Write-Host '  dot env emit                Emit v1 environment manifest'
    Write-Host '  dot agents render           Re-render every AGENTS.md harness'
    Write-Host '  dot fleet status            Single-node fleet status (Full on PowerShell)'
    Write-Host ''
    Write-Host 'See: dot help all (via bash) — full command index'
}

<#
.SYNOPSIS
    Verify that AGENTS.md is in sync with CLAUDE.md.

.DESCRIPTION
    Native PowerShell implementation of `dot agents check`. Both
    files share a "Project Overview" paragraph that is the canonical
    sync surface. If they diverge, AGENTS.md needs re-rendering
    (run `dot agents render` via bash; native PowerShell render is
    a separate ticket).

.OUTPUTS
    [bool] — $true when in sync, $false otherwise.

.EXAMPLE
    if (-not (Test-DotAgentsSync)) {
      Write-Warning 'AGENTS.md is stale; run: bash dot_local/bin/executable_dot agents render'
    }
#>
function Test-DotAgentsSync {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $claude = Join-Path $script:RepoRoot 'CLAUDE.md'
    $agents = Join-Path $script:RepoRoot 'AGENTS.md'
    foreach ($f in @($claude, $agents)) {
        if (-not (Test-Path $f)) {
            Write-Error "missing: $f"
            return $false
        }
    }
    # Both files declare: "Chezmoi-managed dotfiles for macOS, Linux,
    # WSL, and PowerShell 7.5+. Version `0.2.503`."
    # That single line is the canonical sync surface — its content
    # is generated from the same template by `dot agents render`.
    $claudeLine = (Select-String -Path $claude -Pattern '^Chezmoi-managed dotfiles' -SimpleMatch:$false |
        Select-Object -First 1).Line
    $agentsLine = (Select-String -Path $agents -Pattern '^Chezmoi-managed dotfiles' -SimpleMatch:$false |
        Select-Object -First 1).Line
    if (-not $claudeLine -or -not $agentsLine) {
        Write-Verbose "sync surface line not found — claude:[$claudeLine] agents:[$agentsLine]"
        return $false
    }
    if ($claudeLine -ne $agentsLine) {
        Write-Verbose "drift detected:`n  CLAUDE.md: $claudeLine`n  AGENTS.md: $agentsLine"
        return $false
    }
    Write-Verbose 'AGENTS.md sync surface matches CLAUDE.md'
    return $true
}

Export-ModuleMember -Function Get-DotVersion, Invoke-DotHelp, Test-DotAgentsSync
