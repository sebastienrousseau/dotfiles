<#
.SYNOPSIS
  Windows smoke test for the dotfiles framework.

.DESCRIPTION
  Ships under PowerShell 7.5+; verifies that the `dot` dispatcher
  starts, that key read-only commands work, and that chezmoi can be
  invoked from PowerShell. Designed to run inside `windows-latest`
  GitHub Actions runners (B1 of ROADMAP_2026).

  Closes the audit gap "PowerShell 7.5+ claim unverified."

.NOTES
  Exit codes:
    0   all checks passed
    1   one or more checks failed
    2   environment misconfigured (chezmoi/dot missing)
#>

[CmdletBinding()]
param(
  [string] $RepoRoot = (Get-Location).Path,
  [switch] $Strict
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Failures = @()

function Assert-Step {
  param(
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [scriptblock] $Test
  )
  Write-Host "→ $Name " -NoNewline
  try {
    & $Test | Out-Null
    Write-Host 'ok' -ForegroundColor Green
  }
  catch {
    Write-Host 'FAIL' -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
    $script:Failures += $Name
  }
}

# ─── PowerShell version contract ─────────────────────────────────────────────
# 7.4 is current LTS (EOL 2026-11-10); 7.5 is current stable. README claims
# "PowerShell 7.5+" forward-looking; the 7.4 LTS window keeps this gate
# at 7.4+ until the bundled runner version rolls forward.
Assert-Step 'PowerShell >= 7.4 (LTS or current)' {
  if ($PSVersionTable.PSVersion.Major -lt 7 -or
      ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 4)) {
    throw "PowerShell $($PSVersionTable.PSVersion) — need 7.4+ (LTS) or 7.5+ (current)"
  }
}

# ─── Repo layout sanity ──────────────────────────────────────────────────────
Assert-Step 'dot dispatcher present' {
  $dot = Join-Path $RepoRoot 'dot_local/bin/executable_dot'
  if (-not (Test-Path $dot)) { throw "missing $dot" }
}

Assert-Step '.chezmoidata.toml present' {
  $data = Join-Path $RepoRoot '.chezmoidata.toml'
  if (-not (Test-Path $data)) { throw "missing $data" }
}

# ─── chezmoi callable from pwsh ──────────────────────────────────────────────
Assert-Step 'chezmoi on PATH' {
  $cmd = Get-Command chezmoi -ErrorAction SilentlyContinue
  if (-not $cmd) { throw 'chezmoi not on PATH (install via scoop install chezmoi or winget)' }
}

Assert-Step 'chezmoi --version succeeds' {
  $out = & chezmoi --version 2>&1
  if ($LASTEXITCODE -ne 0) { throw "rc=$LASTEXITCODE :: $out" }
}

# ─── Native PowerShell module — no bash needed ───────────────────────────────
# Tests the cmdlets in scripts/dot/powershell/Dot.psm1.
Assert-Step 'Dot.psm1 imports cleanly' {
  Import-Module (Join-Path $RepoRoot 'scripts/dot/powershell/Dot.psm1') -Force
}

Assert-Step 'Get-DotVersion (native)' {
  $env:DOT_REPO_ROOT = $RepoRoot
  Import-Module (Join-Path $RepoRoot 'scripts/dot/powershell/Dot.psm1') -Force
  $v = Get-DotVersion
  if ($v -notmatch '^\d+\.\d+\.\d+$') { throw "unexpected version: $v" }
}

Assert-Step 'Test-DotAgentsSync (native — AGENTS.md ↔ CLAUDE.md)' {
  $env:DOT_REPO_ROOT = $RepoRoot
  Import-Module (Join-Path $RepoRoot 'scripts/dot/powershell/Dot.psm1') -Force
  if (-not (Test-DotAgentsSync)) {
    throw 'AGENTS.md not in sync with CLAUDE.md'
  }
}

Assert-Step 'dot.ps1 dispatcher: version subcommand' {
  $ps1 = Join-Path $RepoRoot 'dot_local/bin/dot.ps1'
  $out = & pwsh -NoProfile -File $ps1 'version' 2>&1
  if ($LASTEXITCODE -ne 0) { throw "rc=$LASTEXITCODE :: $out" }
  if ($out -notmatch '^\d+\.\d+\.\d+$') { throw "unexpected: $out" }
}

Assert-Step 'dot.ps1 dispatcher: agents check subcommand' {
  $ps1 = Join-Path $RepoRoot 'dot_local/bin/dot.ps1'
  $out = & pwsh -NoProfile -File $ps1 'agents' 'check' 2>&1
  if ($LASTEXITCODE -ne 0) { throw "rc=$LASTEXITCODE :: $out" }
}

# Native Windows: validate every chezmoi template renders without needing
# bash. This catches Go-template syntax errors that wouldn't surface until
# a real user ran `chezmoi apply` on Windows. Uses a throwaway destDir +
# `--no-tty` to avoid the interactive prompts that real apply triggers.
Assert-Step 'chezmoi apply --dry-run renders every template' {
  $destDir = Join-Path $env:RUNNER_TEMP "chezmoi-smoke-$([System.IO.Path]::GetRandomFileName())"
  try {
    New-Item -ItemType Directory -Path $destDir | Out-Null
    $out = & chezmoi apply `
      --source $RepoRoot `
      --destination $destDir `
      --dry-run `
      --no-tty `
      --keep-going 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "rc=$LASTEXITCODE :: $($out | Select-Object -First 30 | Out-String)"
    }
  }
  finally {
    if (Test-Path $destDir) {
      Remove-Item -Recurse -Force $destDir -ErrorAction SilentlyContinue
    }
  }
}

# ─── dot CLI cold-start (only when bash is on PATH) ──────────────────────────
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) {
  Assert-Step 'dot version' {
    $dot = Join-Path $RepoRoot 'dot_local/bin/executable_dot'
    $out = & bash $dot 'version' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "rc=$LASTEXITCODE :: $out" }
  }
  Assert-Step 'dot help' {
    $dot = Join-Path $RepoRoot 'dot_local/bin/executable_dot'
    $out = & bash $dot 'help' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "rc=$LASTEXITCODE :: $out" }
  }
  Assert-Step 'dot agents check (AGENTS.md ↔ CLAUDE.md sync)' {
    # `Push-Location` so the bash subprocess's $PWD points at the
    # repo root — the bash dispatcher uses `git rev-parse` against
    # $PWD when no usable chezmoi source-path is on disk.
    Push-Location $RepoRoot
    try {
      $dot = Join-Path $RepoRoot 'dot_local/bin/executable_dot'
      $out = & bash $dot 'agents' 'check' 2>&1
      if ($LASTEXITCODE -ne 0) { throw "rc=$LASTEXITCODE :: $out" }
    }
    finally {
      Pop-Location
    }
  }
}
else {
  Write-Host '→ skipping bash-dependent checks (no bash on PATH)' -ForegroundColor DarkYellow
}

# ─── PSScriptAnalyzer over the smoke-test itself ────────────────────────────
Assert-Step 'PSScriptAnalyzer over scripts/ci/*.ps1' {
  if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Install-Module PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction Stop
  }
  # `@(...)` so a single-result return value is still an array, otherwise
  # `.Count` on a $null / scalar trips the strict-mode property check.
  $issues = @(Invoke-ScriptAnalyzer -Path (Join-Path $RepoRoot 'scripts/ci') -Severity Error -ErrorAction Stop)
  if ($issues.Count -gt 0) {
    $msg = ($issues | ForEach-Object { "$($_.RuleName) at $($_.ScriptPath):$($_.Line)" }) -join '; '
    throw "PSScriptAnalyzer found $($issues.Count) error(s): $msg"
  }
}

# ─── Summary ─────────────────────────────────────────────────────────────────
if ($script:Failures.Count -gt 0) {
  Write-Host ''
  Write-Host "FAILED: $($script:Failures -join ', ')" -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host 'All Windows smoke checks passed.' -ForegroundColor Green
exit 0
