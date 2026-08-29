<#
  Self-test for cycle-metrics.ps1 -Summary row selection.

  Why this exists: -Summary picks the rows for a local day with a regex against the
  raw line, deliberately, so ConvertFrom-Json never gets to coerce a timestamp. That
  is correct. What it got wrong was assuming the line is always compact.

  The writer emits compact JSON, but the runner ALSO has to record a halt when the
  harness itself is off disk — and a row appended by hand at that point is
  pretty-printed. Measured 2026-08-30: three real halt rows (local 08-22, 08-23,
  08-29) were valid JSON, semantically correct, and matched by nothing. The summary
  did not error; it returned a smaller number. A ledger under-count with no error is
  the one failure you cannot find by reading the ledger, only by matching the parser.

      pwsh -NoProfile -File scripts/cycle/Test-CycleMetrics.ps1
#>
[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Metrics = Join-Path $PSScriptRoot 'cycle-metrics.ps1'

$pass = 0; $fail = 0
function Check { param([string]$Name, [scriptblock]$Body)
  try { & $Body; $script:pass++; if (-not $Quiet) { Write-Host "  PASS  $Name" -ForegroundColor DarkGreen } }
  catch { $script:fail++; Write-Host "  FAIL  $Name`n        $($_.Exception.Message)" -ForegroundColor Red } }
function Assert-Equal { param($Actual, $Expected, [string]$What = 'value')
  if ($Actual -ne $Expected) { throw "$What : expected '$Expected', got '$Actual'" } }

function New-Fixture {
  <# Writes a ledger mixing both encodings and returns its path. #>
  param([string[]]$Lines)
  $p = Join-Path ([System.IO.Path]::GetTempPath()) ("cycle-metrics-test-{0}.jsonl" -f [guid]::NewGuid())
  Set-Content -Path $p -Value $Lines -Encoding utf8
  return $p
}

# Compact — exactly what the -Append path writes.
$compactHalt = '{"ts":"2026-08-29T21:45:13Z","local_date":"2026-08-30","cycle_id":"","event":"halt","repo":"","pr":0,"work_class":"","outcome":"harness_not_installed","detail":"compact"}'
# Spaced — what a hand-appended row looks like when the harness is off disk.
$spacedHalt  = '{"ts": "2026-08-29T21:43:12Z", "local_date": "2026-08-30", "cycle_id": "", "event": "halt", "repo": "", "pr": 0, "work_class": "", "outcome": "harness_not_installed", "detail": "spaced"}'
# A different halt cause, spaced, so cause aggregation is exercised too.
$spacedOther = '{"ts": "2026-08-29T22:00:00Z", "local_date": "2026-08-30", "cycle_id": "", "event": "halt", "repo": "", "pr": 0, "work_class": "", "outcome": "safety_red", "detail": "spaced"}'
# Same shape, a DIFFERENT day — must never leak into the requested day.
$otherDay    = '{"ts": "2026-08-28T21:43:12Z", "local_date": "2026-08-29", "cycle_id": "", "event": "halt", "repo": "", "pr": 0, "work_class": "", "outcome": "harness_not_installed", "detail": "wrong day"}'
$merge       = '{"ts":"2026-08-29T21:50:00Z","local_date":"2026-08-30","cycle_id":"c1","event":"merge_attempt","repo":"alexmclaren/x","pr":7,"work_class":"deps","outcome":"merged","detail":""}'

Write-Host 'cycle-metrics self-test' -ForegroundColor Cyan

Check 'THE REGRESSION: a spaced row is counted, not silently dropped' {
  $f = New-Fixture @($compactHalt, $spacedHalt)
  try {
    $s = & $script:Metrics -Summary -Date '2026-08-30' -MetricsFile $f
    # Pre-fix this returns 1: the compact row matched, the spaced row did not, and
    # nothing anywhere reported that a line had been skipped.
    Assert-Equal $s.halts 2 'halts'
  } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Check 'both encodings aggregate into halt_causes' {
  $f = New-Fixture @($compactHalt, $spacedHalt, $spacedOther)
  try {
    $s = & $script:Metrics -Summary -Date '2026-08-30' -MetricsFile $f
    Assert-Equal $s.halts 3 'halts'
    $causes = @($s.halt_causes)
    if ($causes -notcontains 'harness_not_installed=2') { throw "missing 'harness_not_installed=2', got: $($causes -join ', ')" }
    if ($causes -notcontains 'safety_red=1')            { throw "missing 'safety_red=1', got: $($causes -join ', ')" }
  } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Check 'day bucketing still excludes another day written in the SAME spaced form' {
  # Guards the obvious over-correction: loosening the regex must not loosen the
  # date match itself.
  $f = New-Fixture @($compactHalt, $spacedHalt, $otherDay)
  try {
    $s = & $script:Metrics -Summary -Date '2026-08-30' -MetricsFile $f
    Assert-Equal $s.halts 2 'halts on the requested day'
    $s2 = & $script:Metrics -Summary -Date '2026-08-29' -MetricsFile $f
    Assert-Equal $s2.halts 1 'halts on the neighbouring day'
  } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Check 'non-halt events survive the same path' {
  $f = New-Fixture @($compactHalt, $spacedHalt, $merge)
  try {
    $s = & $script:Metrics -Summary -Date '2026-08-30' -MetricsFile $f
    Assert-Equal $s.merges_succeeded 1 'merges_succeeded'
    Assert-Equal $s.halts 2 'halts'
  } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Check 'a day with no rows reports nothing rather than throwing' {
  $f = New-Fixture @($otherDay)
  try {
    $s = & $script:Metrics -Summary -Date '2026-08-30' -MetricsFile $f
    # The script writes a message and returns nothing for an empty day.
    if ($null -ne $s -and $s -isnot [string]) { Assert-Equal $s.halts 0 'halts' }
  } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Check 'blank lines and malformed rows are skipped, not fatal' {
  $f = New-Fixture @($compactHalt, '', '   ', 'not json at all', $spacedHalt)
  try {
    $s = & $script:Metrics -Summary -Date '2026-08-30' -MetricsFile $f
    Assert-Equal $s.halts 2 'halts'
  } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host ("cycle-metrics self-test: {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor Cyan
if ($fail) { exit 1 }
