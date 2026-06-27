<#
.SYNOPSIS
  Propagate the canonical Orryx harness (CLAUDE.base.md pointer + shared
  slash commands) across the fleet. Idempotent, dry-run by default.

.DESCRIPTION
  For each target repo:
    - Ensures a CLAUDE.md exists:
        * missing  -> create a THIN POINTER from templates/CLAUDE.override.template.md
        * existing -> PREPEND a canonical-pointer header (once; sentinel-guarded),
                      never overwriting the repo's own content.
    - Copies the shared commands (loop, plan, verify, review) into
      <repo>/.claude/commands/, skipping any file that already exists
      (no-clobber; reported as 'conflict').
  Writes scripts/propagation-report.md classifying every repo.

  DRY-RUN IS THE DEFAULT. Pass -Apply to make changes. Nothing is committed or
  pushed; changes are left in the working tree for human-gated commit.

.PARAMETER Apply
  Actually write changes. Without it, the script runs read-only (-WhatIf style)
  and only produces the report.

.PARAMETER FleetRoot
  Root containing the repos. Default: D:\

.PARAMETER StandardsRepo
  Path to orryx-standards (the canonical source). Default: <FleetRoot>\orryx-standards
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$FleetRoot     = 'D:\',
    [string]$StandardsRepo = 'D:\orryx-standards',
    [string[]]$Only                                  # if set, only process these repo names
)

$ErrorActionPreference = 'Stop'

# --- Sentinel that marks a header we injected (guards against double-prepend) ---
$SENTINEL = '<!-- orryx-harness-pointer:v1 -->'

# --- Canonical pointer header prepended to EXISTING full CLAUDE.md files ---
$POINTER_HEADER = @"
$SENTINEL
> **Canonical execution protocol:** [CLAUDE.base.md in orryx-standards](https://github.com/orryx/orryx-standards/blob/main/CLAUDE.base.md)
> Read that first. The content below is this repository's specific overrides and context.
> Shared slash commands (/loop, /plan, /verify, /review) live in .claude/commands/.

---

"@

# --- Explicit repo allow-list (the 21 real product repos). ---
# Worktrees and scratch dirs are excluded by construction (not listed) AND by
# the deny-pattern guard below, so a typo can never target a worktree.
$REPOS = @(
    'orryx-brain','orryx-flow','orryx-mcp-gateway','orryx-core',
    'orryx-control-plane','orryx-governance','orryx-knowledge','orryx-engineering',
    'orryx-mission-control','orryx-delivery-dashboard','orryx-website',
    'orryx-repair-intelligence','orryx-standards',
    'pillarworks-build-mvp','pillarworks-demo','Pillarworks-Enterprise-Website',
    'Clinical.Trials','brisbane-gynae-fertility','midnight-raid-analyser',
    'cavalier-rescue','property-maintenance-os'
)

# --- Deny-pattern: refuse anything that looks like a worktree/scratch dir ---
$DENY = '^_|-wt|^wt$|^worktrees$|^pw-worktrees$|^pillarworks-worktrees$'

$commandsSrc = Join-Path $StandardsRepo 'commands'
$templateSrc = Join-Path $StandardsRepo 'templates\CLAUDE.override.template.md'
$sharedCommands = @('loop.md','plan.md','verify.md','review.md')

if (-not (Test-Path $commandsSrc))  { throw "Commands source not found: $commandsSrc" }
if (-not (Test-Path $templateSrc))  { throw "Template not found: $templateSrc" }

$report = [System.Collections.Generic.List[object]]::new()
$mode = if ($Apply) { 'APPLY' } else { 'DRY-RUN' }
Write-Host "=== propagate-harness ($mode) ===" -ForegroundColor Cyan

$targets = if ($Only) { $REPOS | Where-Object { $Only -contains $_ } } else { $REPOS }

foreach ($name in $targets) {
    if ($name -match $DENY) {
        Write-Warning "SKIP (deny-pattern matched): $name"
        continue
    }

    $repoPath = Join-Path $FleetRoot $name
    if (-not (Test-Path $repoPath)) {
        $report.Add([pscustomobject]@{ repo=$name; claudemd='MISSING-REPO'; commands='-'; notes='repo path not found' })
        continue
    }

    # ---- 1. CLAUDE.md handling ----
    $claudeMd = Join-Path $repoPath 'CLAUDE.md'
    $claudeStatus = ''
    if (-not (Test-Path $claudeMd)) {
        # Create a thin pointer from the template
        $claudeStatus = 'created (thin pointer)'
        if ($Apply) {
            $content = (Get-Content $templateSrc -Raw) -replace '\{REPO_NAME\}', $name
            $content = "$SENTINEL`n" + $content
            Set-Content -Path $claudeMd -Value $content -Encoding UTF8 -NoNewline
        }
    }
    else {
        $head = Get-Content $claudeMd -TotalCount 5 -ErrorAction SilentlyContinue
        if ($head -match [regex]::Escape($SENTINEL)) {
            $claudeStatus = 'skipped (already pointed)'
        }
        else {
            $claudeStatus = 'updated (header prepended)'
            if ($Apply) {
                $existing = Get-Content $claudeMd -Raw
                Set-Content -Path $claudeMd -Value ($POINTER_HEADER + "`n" + $existing) -Encoding UTF8 -NoNewline
            }
        }
    }

    # ---- 2. Shared commands ----
    # The standards repo IS the source (commands/ lives there); do not copy the
    # shared commands into its own .claude/commands/ — that would be a redundant
    # duplicate that drifts. Other repos get the copy.
    if ($repoPath -eq $StandardsRepo -or (Resolve-Path $repoPath).Path -eq (Resolve-Path $StandardsRepo).Path) {
        $cmdSummary = 'source-repo (commands/ is canonical; no copy)'
    }
    else {
        $cmdDir = Join-Path $repoPath '.claude\commands'
        $added = @(); $conflict = @()
        if ($Apply -and -not (Test-Path $cmdDir)) { New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null }
        foreach ($cmd in $sharedCommands) {
            $dest = Join-Path $cmdDir $cmd
            if (Test-Path $dest) {
                $conflict += $cmd            # no-clobber: never overwrite a repo's own command
            } else {
                $added += $cmd
                if ($Apply) { Copy-Item (Join-Path $commandsSrc $cmd) $dest -Force }
            }
        }
        $cmdSummary = "add:[$($added -join ',')]"
        if ($conflict.Count) { $cmdSummary += " conflict:[$($conflict -join ',')]" }
    }

    $report.Add([pscustomobject]@{ repo=$name; claudemd=$claudeStatus; commands=$cmdSummary; notes='' })
    Write-Host ("  {0,-32} {1,-28} {2}" -f $name, $claudeStatus, $cmdSummary)
}

# ---- Write report ----
$reportPath = Join-Path $StandardsRepo 'scripts\propagation-report.md'
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Harness propagation report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Mode:** $mode  ")
[void]$sb.AppendLine("**Repos targeted:** $($targets.Count)  ")
[void]$sb.AppendLine("**Generated by:** scripts/propagate-harness.ps1")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Repo | CLAUDE.md | Commands | Notes |")
[void]$sb.AppendLine("|---|---|---|---|")
foreach ($r in $report) {
    [void]$sb.AppendLine("| $($r.repo) | $($r.claudemd) | $($r.commands) | $($r.notes) |")
}
[void]$sb.AppendLine("")
$created = ($report | Where-Object { $_.claudemd -like 'created*' }).Count
$updated = ($report | Where-Object { $_.claudemd -like 'updated*' }).Count
$skipped = ($report | Where-Object { $_.claudemd -like 'skipped*' }).Count
[void]$sb.AppendLine("**Summary:** created=$created  updated=$updated  skipped=$skipped  total=$($report.Count)")
if (-not $Apply) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("> DRY-RUN — no files were modified. Re-run with ``-Apply`` to write changes.")
}

# Always write the report (dry-run produces it for review; apply records what happened)
Set-Content -Path $reportPath -Value $sb.ToString() -Encoding UTF8

Write-Host ""
Write-Host "Report written: $reportPath" -ForegroundColor Green
Write-Host "Summary: created=$created updated=$updated skipped=$skipped total=$($report.Count)" -ForegroundColor Green
if (-not $Apply) { Write-Host "DRY-RUN — re-run with -Apply to write changes." -ForegroundColor Yellow }
