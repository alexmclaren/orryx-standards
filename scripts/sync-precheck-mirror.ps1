<#
.SYNOPSIS
  Re-sync the verbatim in-context mirror of PRODUCER_PRECHECK.md §1-§5 into every
  routine SKILL.md. Single source of truth = _shared\PRODUCER_PRECHECK.md.

.DESCRIPTION
  Each routine SKILL.md carries a "## Producer Pre-check ..." section shaped as:
      <pointer blockquote>            <- stable, human-owned
      [routine-specific tailoring]    <- human-owned, per-routine (7 routines)
      ---                             <- divider
      **Full rules — verbatim ...:**  <- mirror intro
      <canonical §1-§5, headers demoted to bold>   <- MANAGED BY THIS SCRIPT

  This script ONLY rewrites the mirror (everything from the `---` divider down).
  It never touches the pointer or the tailoring above the divider (no-clobber),
  so a hand-edited routine gate is safe. Idempotent: when a mirror already matches
  the canonical it is left byte-for-byte unchanged.

  Dry-run by default (reports drift, writes nothing). Pass -Apply to rewrite
  drifted mirrors.

.NOTES
  Human-gated: to change the RULES, edit _shared\PRODUCER_PRECHECK.md, then run
  this with -Apply. To change the pointer/tailoring shape, edit the SKILL.md
  directly — this script preserves it.
#>
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$tasks = Split-Path -Parent $PSCommandPath      # ...\_shared
$tasks = Split-Path -Parent $tasks              # ...\scheduled-tasks
$canon = Join-Path $tasks '_shared\PRODUCER_PRECHECK.md'
$report = Join-Path $tasks '_shared\precheck-mirror-report.md'

if (-not (Test-Path $canon)) { throw "canonical not found: $canon" }

# --- Build desired mirror body: canonical §1-§5, `## N.` headers demoted to bold ---
$cl = @(Get-Content -LiteralPath $canon)
$s = -1
for ($j = 0; $j -lt $cl.Count; $j++) { if ($cl[$j] -match '^##\s+1\.\s') { $s = $j; break } }
if ($s -lt 0) { throw "could not locate canonical '## 1.' header in $canon" }
$canonBodyLines = foreach ($ln in $cl[$s..($cl.Count - 1)]) {
    if ($ln -match '^#{2,3}\s+(.*)$') { '**' + $Matches[1] + '**' } else { $ln }
}
# trim trailing blank lines
while ($canonBodyLines.Count -gt 0 -and $canonBodyLines[-1].Trim() -eq '') {
    $canonBodyLines = $canonBodyLines[0..($canonBodyLines.Count - 2)]
}
$mirrorIntro = '**Full rules — verbatim in-context snapshot of `_shared/PRODUCER_PRECHECK.md` §1–§5 (the file is authoritative; if this snapshot and the file disagree, the file wins):**'
$desiredMirrorLines = @('---', '', $mirrorIntro, '') + $canonBodyLines
$desiredMirrorText = ($desiredMirrorLines -join "`n").TrimEnd()

$inSync = @(); $drifted = @(); $needsMigration = @()

foreach ($dir in Get-ChildItem -Path $tasks -Directory | Where-Object { $_.Name -ne '_shared' }) {
    $f = Join-Path $dir.FullName 'SKILL.md'
    if (-not (Test-Path $f)) { continue }
    $lines = @(Get-Content -LiteralPath $f)

    $i0 = -1
    for ($j = 0; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^##\s.*Producer Pre-check') { $i0 = $j; break } }
    if ($i0 -lt 0) { continue }   # routine has no pre-check section at all — not our concern
    $i1 = $lines.Count
    for ($j = $i0 + 1; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^##\s') { $i1 = $j; break } }

    # locate the mirror intro, then the `---` divider immediately above it
    $mi = -1
    for ($j = $i0 + 1; $j -lt $i1; $j++) { if ($lines[$j] -match 'Full rules — verbatim in-context snapshot') { $mi = $j; break } }
    if ($mi -lt 0) { $needsMigration += $dir.Name; continue }
    $dv = -1
    for ($j = $mi - 1; $j -gt $i0; $j--) { if ($lines[$j].Trim() -eq '---') { $dv = $j; break } }
    if ($dv -lt 0) { $needsMigration += $dir.Name; continue }

    $currentMirrorText = ($lines[$dv..($i1 - 1)] -join "`n").TrimEnd()
    if ($currentMirrorText -eq $desiredMirrorText) { $inSync += $dir.Name; continue }

    $drifted += $dir.Name
    if ($Apply) {
        $pre  = if ($i0 -gt 0) { $lines[0..($i0 - 1)] } else { @() }
        $head = $lines[$i0..($dv - 1)]                       # pointer + tailoring (preserved)
        $post = if ($i1 -lt $lines.Count) { $lines[$i1..($lines.Count - 1)] } else { @() }
        $content = @($pre) + @($head) + @($desiredMirrorLines) + @('') + @($post)
        Set-Content -LiteralPath $f -Encoding UTF8 -Value $content
    }
}

$mode = if ($Apply) { 'APPLY' } else { 'DRY-RUN' }
$driftLabel = if ($Apply) { 'rewritten' } else { 'drifted (run -Apply to fix)' }
$lines2 = @()
$lines2 += "# Pre-check mirror sync report ($mode)"
$lines2 += ""
$lines2 += "Canonical: `_shared/PRODUCER_PRECHECK.md` (§1-§5, $($canonBodyLines.Count) body lines)"
$lines2 += ""
$lines2 += "- in-sync: $($inSync.Count)"
$lines2 += "- $($driftLabel): $($drifted.Count)$(if($drifted){' — ' + ($drifted -join ', ')})"
$lines2 += "- NEEDS-MIGRATION (no mirror/divider found): $($needsMigration.Count)$(if($needsMigration){' — ' + ($needsMigration -join ', ')})"
Set-Content -LiteralPath $report -Encoding UTF8 -Value $lines2
$lines2 | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "report: $report"
