<#
.SYNOPSIS
  One deterministic snapshot of "what is the world right now", for the autonomous
  cycle runner. Read-only.

.DESCRIPTION
  Replaces the per-cycle re-derivation of context that currently costs the fleet a
  full agent run before any work starts. Every consumer reads this instead of
  re-globbing reports and re-querying git and gh.

  Emits, per repo: local branch/dirty/divergence state, stranded worktrees, and
  every open PR with mergeability, check rollup, and change size. Then ranks the
  open PRs into a work queue using the operator's stated priority order.

  Ranking rationale (highest first):
    1. security  — a dependency bump carrying a CVE fix closes a *verified*
                   security gap; the operator ranks that above new capability.
    2. deps      — mechanical, reversible, cheap to review, unblocks Dependabot
                   backlog that otherwise hides real CVEs behind noise.
    3. code      — feature/fix work; real value but needs the most review.
    4. docs      — cheapest, but moves no production-readiness gap on its own.
  Within a tier, older PRs first (age is queue debt, and stale PRs rot into
  conflicts — 3 of the fleet's 52 are already DIRTY).

  Anything not CLEAN/mergeable is reported with `blocked_on` so idle-despite-work
  is visible rather than silent.

.PARAMETER Repos
  owner/name list. Defaults to the repos declared in branch-protection.json,
  which is the fleet's own declared-state file.

.PARAMETER LocalRoot
  Where working copies live. Default D:\.

.PARAMETER SkipLocal
  Skip local git inspection (faster; PR data only).

.OUTPUTS
  A state object; -AsJson emits JSON. -OutFile also writes it.
#>
[CmdletBinding()]
param(
  [string[]]$Repos,
  [string]$LocalRoot = 'D:\',
  [string]$ProtectionFile = 'D:\state\branch-protection.json',
  [switch]$SkipLocal,
  [switch]$AsJson,
  [string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:GH_PAGER = ''

if (-not $Repos -or $Repos.Count -eq 0) {
  if (-not (Test-Path $ProtectionFile)) { throw "No -Repos given and $ProtectionFile not found." }
  $Repos = @((Get-Content $ProtectionFile -Raw | ConvertFrom-Json).repos.PSObject.Properties.Name)
}

# CVE / security signal in a PR title. Dependabot does not label these reliably,
# so title matching is the available signal; deliberately broad.
$securityRx = 'CVE-|security|vulnerab|GHSA-|npm-security|pip-security|advisory'

function Get-LocalState {
  param([string]$Path)
  if (-not (Test-Path (Join-Path $Path '.git'))) { return $null }
  $branch = (git -C $Path branch --show-current 2>$null)
  $dirty  = @(git -C $Path status --porcelain 2>$null).Count
  $ab = @{ ahead = $null; behind = $null }
  $up = git -C $Path rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
  if ($LASTEXITCODE -eq 0 -and $up) {
    $counts = (git -C $Path rev-list --left-right --count "HEAD...$up" 2>$null) -split '\s+'
    if ($counts.Count -ge 2) { $ab.ahead = [int]$counts[0]; $ab.behind = [int]$counts[1] }
  }
  $wt = @(git -C $Path worktree list --porcelain 2>$null | Where-Object { $_ -like 'worktree *' }).Count
  return [pscustomobject]@{
    path = $Path; branch = $branch; dirty_files = $dirty
    upstream = $up; ahead = $ab.ahead; behind = $ab.behind; worktrees = $wt
  }
}

$now      = (Get-Date).ToUniversalTime()
$repoRows = @()
$queue    = @()

foreach ($full in $Repos) {
  $name = $full.Split('/')[-1]
  $local = $null
  if (-not $SkipLocal) { $local = Get-LocalState -Path (Join-Path $LocalRoot $name) }

  $prs = @()
  $raw = & gh pr list --repo $full --state open --limit 100 `
           --json number,title,isDraft,mergeable,mergeStateStatus,createdAt,updatedAt,headRefName,additions,deletions,changedFiles,labels 2>&1
  if ($LASTEXITCODE -ne 0) {
    $repoRows += [pscustomobject]@{ repo = $full; local = $local; pr_error = ($raw | Out-String).Trim(); prs = @() }
    continue
  }
  foreach ($p in ($raw | ConvertFrom-Json)) {
    # createdAt is already [datetime] after ConvertFrom-Json. Do NOT re-Parse it:
    # ConvertFrom-Json drops the trailing Z and re-renders local, so
    # [datetime]::Parse() throws under a non-US culture and any age computed from
    # it is wrong. This bit a real measurement pass on 2026-08-07.
    $created = if ($p.createdAt -is [datetime]) { $p.createdAt.ToUniversalTime() } else { $now }
    $isSecurity = ($p.title -match $securityRx)
    $class = if ($isSecurity) { 'security' }
             elseif ($p.title -match '^chore\(deps') { 'deps' }
             elseif ($p.title -match '^docs') { 'docs' }
             else { 'code' }
    $blocked = @()
    if ($p.isDraft)                        { $blocked += 'draft' }
    if ($p.mergeable -ne 'MERGEABLE')      { $blocked += "mergeable=$($p.mergeable)" }
    if ($p.mergeStateStatus -ne 'CLEAN')   { $blocked += "state=$($p.mergeStateStatus)" }

    $prs += [pscustomobject]@{
      number = $p.number; title = $p.title; draft = $p.isDraft
      mergeable = $p.mergeable; state = $p.mergeStateStatus
      age_days = [int]($now - $created).TotalDays
      files = $p.changedFiles; additions = $p.additions; deletions = $p.deletions
      work_class = $class; blocked_on = $blocked
    }
  }
  $repoRows += [pscustomobject]@{ repo = $full; local = $local; pr_error = $null; prs = $prs }

  foreach ($pr in $prs) {
    if ($pr.blocked_on.Count -gt 0) { continue }   # not actionable this cycle
    $tier = switch ($pr.work_class) { 'security' { 1 } 'deps' { 2 } 'code' { 3 } 'docs' { 4 } default { 5 } }
    $queue += [pscustomobject]@{
      repo = $full; pr = $pr.number; title = $pr.title
      work_class = $pr.work_class; tier = $tier; age_days = $pr.age_days
      files = $pr.files; additions = $pr.additions
    }
  }
}

$queue = @($queue | Sort-Object tier, @{ Expression = 'age_days'; Descending = $true })

$allPrs      = @($repoRows | ForEach-Object { $_.prs } | Where-Object { $_ })
$actionable  = @($allPrs | Where-Object { $_.blocked_on.Count -eq 0 })
$blockedPrs  = @($allPrs | Where-Object { $_.blocked_on.Count -gt 0 })

$state = [pscustomobject]@{
  generated_utc   = $now.ToString('o')
  date_basis      = 'LOCAL (UTC+10) for date labels; this timestamp is UTC'
  repos           = $repoRows
  queue           = $queue
  summary         = [pscustomobject]@{
    repos_scanned     = $Repos.Count
    open_prs          = $allPrs.Count
    actionable_prs    = $actionable.Count
    blocked_prs       = $blockedPrs.Count
    oldest_actionable = if ($actionable.Count) { (@($actionable | Sort-Object age_days -Descending)[0]).age_days } else { 0 }
    by_class          = ($queue | Group-Object work_class | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '
    dirty_repos       = @($repoRows | Where-Object { $_.local -and $_.local.dirty_files -gt 0 }).Count
  }
}

if ($OutFile) {
  $dir = Split-Path -Parent $OutFile
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $state | ConvertTo-Json -Depth 10 | Set-Content -Path $OutFile -Encoding utf8
}
if ($AsJson) { $state | ConvertTo-Json -Depth 10 } else { $state }
