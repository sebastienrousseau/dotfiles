# Dot — native PowerShell module for the dotfiles framework.
#
# This module provides native PowerShell cmdlets for the daily `dot`
# workflow. Commands with Unix-specific orchestration remain available
# through the dispatcher's explicit bash bridge.
#
# Loaded by bin/dot.ps1 dispatcher; cmdlets are also callable
# directly:
#   Import-Module ./scripts/dot/powershell/Dot.psm1
#   Get-DotVersion
#   Invoke-DotHelp
#   Test-DotAgentsSync -Verbose
#
# Tested via tools/ci/windows-smoke-test.ps1.

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

function script:Assert-DotCommand {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found on PATH"
    }
}

function script:Invoke-DotNativeCommand {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    Assert-DotCommand -Name $Name
    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name exited with status $LASTEXITCODE"
    }
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
    Native PowerShell implementation of `dot help`. Presents the
    native command surface without shelling out to bash.

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
    Write-Host "  Docs       https://github.com/sebastienrousseau/dotfiles/blob/main/docs/manual/"
    Write-Host ''
    Write-Host 'Native PowerShell commands (no bash required):'
    Write-Host ''
    Write-Host '  Get-DotVersion              Print framework version'
    Write-Host '  Invoke-DotHelp              This screen'
    Write-Host '  Test-DotAgentsSync          Check AGENTS.md against CLAUDE.md'
    Write-Host '  Get-DotStatus               Show chezmoi drift'
    Write-Host '  Invoke-DotChezmoi           Run a core chezmoi operation'
    Write-Host '  Invoke-DotDoctor            Audit the native Windows setup'
    Write-Host '  Get-DotEnvironment          List mise-managed tools'
    Write-Host '  Get-DotAgents               List agent harness targets'
    Write-Host '  Get-DotFleetStatus          Show local fleet node status'
    Write-Host ''
    Write-Host 'Bash-bridged subcommands (require bash on PATH):'
    Write-Host ''
    Write-Host '  dot env emit                Emit v1 environment manifest'
    Write-Host '  dot agents render           Re-render every AGENTS.md harness'
    Write-Host '  dot registry ...            Verified module registry operations'
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
    $claudeBody = Get-Content -Raw $claude
    $agentsBody = Get-Content -Raw $agents
    foreach ($name in @('claudeBody', 'agentsBody')) {
        $value = Get-Variable -Name $name -ValueOnly
        $value = $value -replace '(?s)^\s*<!--.*?-->\s*', ''
        $value = $value -replace '(?m)^# (CLAUDE|AGENTS)\.md.*\r?\n', ''
        $value = $value -replace '(?s)\r?\n---\r?\n\r?\n\*\*Need richer context\?.*$', ''
        $value = ($value -replace "`r`n", "`n").Trim()
        Set-Variable -Name $name -Value $value
    }
    if ($claudeBody -cne $agentsBody) {
        Write-Verbose 'AGENTS.md content differs from the canonical CLAUDE.md body'
        return $false
    }
    Write-Verbose 'AGENTS.md content matches the canonical CLAUDE.md body'
    return $true
}

function Invoke-DotChezmoi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('apply', 'diff', 'update', 'add', 'remove', 'init')]
        [string]$Operation,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )
    Invoke-DotNativeCommand -Name 'chezmoi' -Arguments (@($Operation) + $Arguments)
}

function Get-DotStatus {
    [CmdletBinding()]
    param([switch]$AsObject)
    Assert-DotCommand -Name 'chezmoi'
    $output = @(& chezmoi status 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi status exited with status $LASTEXITCODE`: $($output -join [Environment]::NewLine)"
    }
    $state = if ($output.Count -eq 0) { 'clean' } else { 'drifted' }
    if ($AsObject) {
        return [pscustomobject]@{ State = $state; Changes = $output; Native = $true }
    }
    Write-DotBanner -Section 'Status'
    if ($state -eq 'clean') { Write-Host '[OK] Clean - no local drift detected' }
    else { $output | Write-Output }
}

function Get-DotSourcePath {
    [CmdletBinding()]
    param()
    Assert-DotCommand -Name 'chezmoi'
    $path = (& chezmoi source-path 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $path) { throw 'chezmoi source-path failed' }
    return $path
}

function Invoke-DotDoctor {
    [CmdletBinding()]
    param([switch]$AsObject)
    $checks = @(
        [pscustomobject]@{ Name = 'PowerShell 7.4+'; Ok = ($PSVersionTable.PSVersion -ge [version]'7.4') }
        [pscustomobject]@{ Name = 'chezmoi'; Ok = [bool](Get-Command chezmoi -ErrorAction SilentlyContinue) }
        [pscustomobject]@{ Name = 'git'; Ok = [bool](Get-Command git -ErrorAction SilentlyContinue) }
        [pscustomobject]@{ Name = 'repository data'; Ok = (Test-Path $script:DataFile) }
        [pscustomobject]@{ Name = 'PowerShell module'; Ok = (Test-Path (Join-Path $PSScriptRoot 'Dot.psm1')) }
    )
    if ($AsObject) { return $checks }
    Write-DotBanner -Section 'Doctor'
    foreach ($check in $checks) {
        $prefix = if ($check.Ok) { '[OK]' } else { '[FAIL]' }
        Write-Host "$prefix $($check.Name)"
    }
    return -not ($checks.Ok -contains $false)
}

function Get-DotEnvironment {
    [CmdletBinding()]
    param([switch]$AsJson)
    Assert-DotCommand -Name 'mise'
    $arguments = if ($AsJson) { @('ls', '--json') } else { @('ls') }
    Invoke-DotNativeCommand -Name 'mise' -Arguments $arguments
}

function Get-DotAgents {
    [CmdletBinding()]
    param()
    $targets = [ordered]@{
        'agents-md' = 'AGENTS.md'; 'cursor' = '.cursor/rules/dotfiles.mdc'
        'codex' = '.codex/config.toml'; 'windsurf' = '.windsurf/rules.md'
        'zed' = '.zed/agent-config.toml'; 'roo' = '.roo/rules.md'
        'cline' = '.clinerules'; 'aider' = '.aider.conf.yml'
        'continue' = '.continuerc.json'; 'jules' = '.jules/system.md'
        'agy' = '.agy/AGY.md'
    }
    foreach ($entry in $targets.GetEnumerator()) {
        $path = Join-Path $script:RepoRoot $entry.Value
        [pscustomobject]@{ Harness = $entry.Key; Path = $path; Rendered = (Test-Path $path) }
    }
}

function Get-DotFleetStatus {
    [CmdletBinding()]
    param([switch]$AsJson)
    $status = Get-DotStatus -AsObject
    $record = [pscustomobject]@{
        NodeId = [Environment]::MachineName
        Namespace = 'default'
        Version = Get-DotfilesVersionFromData
        OS = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        Drift = $status.State
    }
    if ($AsJson) { return $record | ConvertTo-Json -Compress }
    return $record
}

Export-ModuleMember -Function Get-DotVersion, Invoke-DotHelp, Test-DotAgentsSync, `
    Invoke-DotChezmoi, Get-DotStatus, Get-DotSourcePath, Invoke-DotDoctor, `
    Get-DotEnvironment, Get-DotAgents, Get-DotFleetStatus
