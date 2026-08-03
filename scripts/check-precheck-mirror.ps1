# Read-only drift check: does every routine SKILL.md mirror match the canonical?
# Same block-location logic as scripts/sync-precheck-mirror.ps1, no writes, exit 1 on drift.
param([Parameter(Mandatory)][string]$Root)   # ...\routines

$ErrorActionPreference = 'Stop'
$canon = Join-Path $Root '_shared\PRODUCER_PRECHECK.md'
if (-not (Test-Path $canon)) { throw "canonical not found: $canon" }

$cl = @(Get-Content -LiteralPath $canon)
$s = -1
for ($j = 0; $j -lt $cl.Count; $j++) { if ($cl[$j] -match '^##\s+1\.\s') { $s = $j; break } }
if ($s -lt 0) { throw "could not locate canonical '## 1.' header in $canon" }
$canonBodyLines = foreach ($ln in $cl[$s..($cl.Count - 1)]) {
    if ($ln -match '^#{2,3}\s+(.*)$') { '**' + $Matches[1] + '**' } else { $ln }
}
while ($canonBodyLines.Count -gt 0 -and $canonBodyLines[-1].Trim() -eq '') {
    $canonBodyLines = $canonBodyLines[0..($canonBodyLines.Count - 2)]
}
$mirrorIntro = '**Full rules — verbatim in-context snapshot of `_shared/PRODUCER_PRECHECK.md` §1–§5 (the file is authoritative; if this snapshot and the file disagree, the file wins):**'
$desiredMirrorText = ((@('---', '', $mirrorIntro, '') + $canonBodyLines) -join "`n").TrimEnd()

$inSync = @(); $drifted = @(); $needsMigration = @()
foreach ($dir in Get-ChildItem -Path (Join-Path $Root 'prompts') -Directory) {
    $f = Join-Path $dir.FullName 'SKILL.md'
    if (-not (Test-Path $f)) { continue }
    $lines = @(Get-Content -LiteralPath $f)
    $i0 = -1
    for ($j = 0; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^##\s.*Producer Pre-check') { $i0 = $j; break } }
    if ($i0 -lt 0) { continue }
    $i1 = $lines.Count
    for ($j = $i0 + 1; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^##\s') { $i1 = $j; break } }
    $mi = -1
    for ($j = $i0 + 1; $j -lt $i1; $j++) { if ($lines[$j] -match 'Full rules — verbatim in-context snapshot') { $mi = $j; break } }
    if ($mi -lt 0) { $needsMigration += $dir.Name; continue }
    $dv = -1
    for ($j = $mi - 1; $j -gt $i0; $j--) { if ($lines[$j].Trim() -eq '---') { $dv = $j; break } }
    if ($dv -lt 0) { $needsMigration += $dir.Name; continue }
    if ((($lines[$dv..($i1 - 1)] -join "`n").TrimEnd()) -eq $desiredMirrorText) { $inSync += $dir.Name }
    else { $drifted += $dir.Name }
}

Write-Output "canonical: $($canonBodyLines.Count) body lines"
Write-Output "in-sync: $($inSync.Count)"
Write-Output "drifted: $($drifted.Count)$(if($drifted){' — ' + ($drifted -join ', ')})"
Write-Output "needs-migration: $($needsMigration.Count)$(if($needsMigration){' — ' + ($needsMigration -join ', ')})"
if ($drifted.Count -or $needsMigration.Count) {
    Write-Output "::error::mirror drift — edit routines/_shared/PRODUCER_PRECHECK.md then re-run sync-precheck-mirror.ps1 -Apply. Never hand-edit a mirror."
    exit 1
}
Write-Output "OK: all mirrors match the canonical."
