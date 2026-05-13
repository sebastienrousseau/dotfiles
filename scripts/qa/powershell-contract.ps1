# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# PowerShell parity contract — smoke test for the dotfiles PowerShell
# profile. Run by the windows-latest CI job (#860). Asserts that:
#
#   1. The profile parses + loads without throwing.
#   2. Core function shims (`dot`, `ll`, `la`, `cat`) are defined.
#   3. PSScriptAnalyzer reports no errors against the profile (warnings
#      surface but don't fail the gate; tighten later).
#
# Exit codes:
#   0  contract intact.
#   1  any check failed; details printed to host.

$ErrorActionPreference = 'Stop'
$Failures = New-Object System.Collections.Generic.List[string]

$RepoRoot = if ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { (Get-Location).Path }
$ProfileSrc = Join-Path $RepoRoot 'dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl'

if (-not (Test-Path $ProfileSrc)) {
    Write-Output "FAIL: profile source not found at $ProfileSrc"
    exit 1
}

# Step 1 — chezmoi-render the template into a real .ps1 we can dot-source.
# In CI, chezmoi is on PATH (installed by setup-chezmoi composite).
$Rendered = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1'
if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    & chezmoi execute-template --init --promptString version=0.2.501 `
        --in $ProfileSrc | Set-Content -Path $Rendered -NoNewline
} else {
    # Fallback: strip chezmoi template syntax with a simple regex so the
    # contract still runs locally without chezmoi installed.
    (Get-Content $ProfileSrc -Raw) -replace '\{\{[^}]+\}\}', '0.0.0-fallback' |
        Set-Content -Path $Rendered -NoNewline
}

if (-not (Test-Path $Rendered)) {
    $Failures.Add("profile template did not render to $Rendered")
}

# Step 2 — dot-source the rendered profile and verify it didn't throw.
$loadOk = $false
try {
    . $Rendered
    $loadOk = $true
    Write-Output "OK: profile dot-sourced"
} catch {
    Write-Output "FAIL: profile threw during load: $_"
    $Failures.Add("profile load: $_")
}

# Step 3 — verify required function shims are defined.
$RequiredFunctions = @('dot', 'd', 'll', 'la', 'cat')
foreach ($fn in $RequiredFunctions) {
    if (Get-Command $fn -CommandType Function -ErrorAction SilentlyContinue) {
        Write-Output "OK: function $fn defined"
    } else {
        Write-Output "FAIL: function $fn not defined"
        $Failures.Add("missing function: $fn")
    }
}

# Step 4 — PSScriptAnalyzer (static analysis). Pre-installed on the
# windows-latest GitHub-hosted runner; install on demand if missing.
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Output "Installing PSScriptAnalyzer..."
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
}

if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Import-Module PSScriptAnalyzer -Force
    $Findings = Invoke-ScriptAnalyzer -Path $Rendered -Severity 'Error' -ErrorAction SilentlyContinue
    if ($Findings) {
        foreach ($f in $Findings) {
            Write-Output "FAIL: PSScriptAnalyzer error: $($f.RuleName) at line $($f.Line): $($f.Message)"
            $Failures.Add("PSScriptAnalyzer error: $($f.RuleName)")
        }
    } else {
        Write-Output "OK: PSScriptAnalyzer clean (Error severity)"
    }
} else {
    Write-Output "WARN: PSScriptAnalyzer not available — static analysis skipped"
}

Write-Output ""
if ($Failures.Count -eq 0) {
    Write-Output "PowerShell contract: PASS"
    exit 0
} else {
    Write-Output "PowerShell contract: FAIL ($($Failures.Count) issue(s))"
    foreach ($f in $Failures) { Write-Output "  - $f" }
    exit 1
}
