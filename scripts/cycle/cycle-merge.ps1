<#
.SYNOPSIS
  Merges ONE pull request, but only if cycle-gate.ps1 returns ALLOW. Dry-run by default.

.DESCRIPTION
  The only mutating step in the cycle. Everything dangerous is delegated to
  cycle-gate.ps1 so there is exactly one place where merge authority is decided.

  Safety properties:

  * DRY-RUN BY DEFAULT. Without -Execute this reports what it would do and
    changes nothing. There is no config file that can flip that default.
  * GATE IS RE-EVALUATED HERE. It never trusts a verdict computed earlier; a PR
    can go stale between selection and merge.
  * THE MERGE RACE IS CLOSED SERVER-SIDE. `gh pr merge --match-head-commit <sha>`
    makes GitHub itself reject the merge if a commit landed after the review. A
    local re-check would still leave a window; this does not.
  * NEVER --admin. Bypassing branch protection is precisely the boundary the
    operator asked to preserve, so the flag is not plumbed through at all.
  * EVIDENCE IS WRITTEN BEFORE AND AFTER. A crash mid-merge leaves an attempt
    record, so a resumed cycle can tell "never tried" from "tried, unknown".

.PARAMETER Execute
  Actually merge. Omit for dry-run.

.PARAMETER Strategy
  squash (default) | merge | rebase.

.PARAMETER DeleteBranch
  Delete the remote branch after a successful merge. Safe for the auto/* and
  dependabot/* branches this runner targets; off by default.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [Parameter(Mandatory = $true)][int]$Pr,
  [switch]$Execute,
  [ValidateSet('squash', 'merge', 'rebase')][string]$Strategy = 'squash',
  [switch]$DeleteBranch,
  [switch]$AllowNoCI,
  [string]$StateRoot = 'D:\state\cycles',
  [string]$ProtectionFile = 'D:\state\branch-protection.json',
  [string]$MetricsFile = 'D:\reports\evolution\cycle-metrics.jsonl'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:GH_PAGER = ''

$gate = Join-Path $PSScriptRoot 'cycle-gate.ps1'
$metrics = Join-Path $PSScriptRoot 'cycle-metrics.ps1'
if (-not (Test-Path $gate)) { throw "cycle-gate.ps1 not found at $gate" }

$evidenceDir = Join-Path $StateRoot 'evidence'
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null }

function Write-Evidence {
  param([psobject]$Obj, [string]$Phase)
  $slug = ($Repo -replace '/', '__')
  $p = Join-Path $evidenceDir "$slug`__$Pr`__$Phase.json"
  $Obj | ConvertTo-Json -Depth 10 | Set-Content -Path $p -Encoding utf8
  return $p
}

function Record {
  param([string]$Outcome, [string]$Detail, [psobject]$Verdict)
  if (Test-Path $metrics) {
    & $metrics -Append -Repo $Repo -Pr $Pr -Event 'merge_attempt' -Outcome $Outcome `
      -Detail $Detail -WorkClass ([string]$Verdict.change_class) -MetricsFile $MetricsFile | Out-Null
  }
}

# --- gate (authoritative) ---------------------------------------------------
$gateArgs = @{ Repo = $Repo; Pr = $Pr; StateRoot = $StateRoot; ProtectionFile = $ProtectionFile }
if ($AllowNoCI) { $gateArgs.AllowNoCI = $true }
$verdict = & $gate @gateArgs

if ($verdict.verdict -ne 'ALLOW') {
  $codes = ($verdict.reasons | ForEach-Object { $_.code }) -join ','
  Write-Evidence -Obj $verdict -Phase 'blocked' | Out-Null
  Record -Outcome 'blocked' -Detail $codes -Verdict $verdict
  Write-Host "BLOCK  $Repo #$Pr  $codes" -ForegroundColor Yellow
  foreach ($r in $verdict.reasons) { Write-Host "       - $($r.code): $($r.detail)" -ForegroundColor DarkYellow }
  return $verdict
}

$headSha = $verdict.head_sha
if (-not $headSha) {
  Write-Host "BLOCK  $Repo #$Pr  head SHA unknown; refusing to merge without a pin." -ForegroundColor Yellow
  Record -Outcome 'blocked' -Detail 'HEAD_SHA_UNKNOWN' -Verdict $verdict
  return $verdict
}

Write-Host "ALLOW  $Repo #$Pr  ($($verdict.change_class), $($verdict.files_changed) files, +$($verdict.additions))" -ForegroundColor Green
Write-Host "       head=$headSha  checks=$($verdict.checks.Count)"

if (-not $Execute) {
  Write-Host "       DRY-RUN — would: gh pr merge $Pr --repo $Repo --$Strategy --match-head-commit $headSha" -ForegroundColor Cyan
  Write-Evidence -Obj ([pscustomobject]@{ verdict = $verdict; dry_run = $true }) -Phase 'dryrun' | Out-Null
  Record -Outcome 'dryrun_allow' -Detail 'would merge' -Verdict $verdict
  return $verdict
}

# --- execute ---------------------------------------------------------------
$attempt = [pscustomobject]@{
  verdict = $verdict; strategy = $Strategy; head_sha = $headSha
  attempted_utc = (Get-Date).ToUniversalTime().ToString('o'); result = 'IN_FLIGHT'
}
Write-Evidence -Obj $attempt -Phase 'attempt' | Out-Null

$mergeArgs = @($Pr, '--repo', $Repo, "--$Strategy", '--match-head-commit', $headSha)
if ($DeleteBranch) { $mergeArgs += '--delete-branch' }

$out = & gh pr merge @mergeArgs 2>&1
$ok = ($LASTEXITCODE -eq 0)
$text = ($out | Out-String).Trim()

$final = [pscustomobject]@{
  verdict = $verdict; strategy = $Strategy; head_sha = $headSha
  merged = $ok; gh_output = $text
  completed_utc = (Get-Date).ToUniversalTime().ToString('o')
  result = if ($ok) { 'MERGED' } else { 'MERGE_FAILED' }
}
Write-Evidence -Obj $final -Phase $(if ($ok) { 'merged' } else { 'failed' }) | Out-Null
Record -Outcome $(if ($ok) { 'merged' } else { 'merge_failed' }) -Detail $text -Verdict $verdict

if ($ok) { Write-Host "MERGED $Repo #$Pr" -ForegroundColor Green }
else     { Write-Host "FAILED $Repo #$Pr : $text" -ForegroundColor Red }

return $final
