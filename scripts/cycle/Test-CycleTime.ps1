<#
  Self-test for cycle-time.ps1.

  Small on purpose, but not optional: the ConvertFrom-Json timestamp-coercion trap
  this file exists to contain has the worst track record in the harness. It caused
  three defects while the harness was being built, the worst of which made
  cycle-lock read EVERY lock as stale — so the lock never locked, silently, with no
  error anywhere. A regression here removes mutual exclusion without failing a
  single other test.

      pwsh -NoProfile -File scripts/cycle/Test-CycleTime.ps1
#>
[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'cycle-time.ps1')

$pass = 0; $fail = 0
function Check { param([string]$Name, [scriptblock]$Body)
  try { & $Body; $script:pass++; if (-not $Quiet) { Write-Host "  PASS  $Name" -ForegroundColor DarkGreen } }
  catch { $script:fail++; Write-Host "  FAIL  $Name`n        $($_.Exception.Message)" -ForegroundColor Red } }
function Assert-Equal { param($Actual, $Expected, [string]$What = 'value')
  if ($Actual -ne $Expected) { throw "$What : expected '$Expected', got '$Actual'" } }

Write-Host 'cycle-time self-test' -ForegroundColor Cyan

Check 'Read-IsoUtc parses a plain Z timestamp as UTC' {
  $t = Read-IsoUtc -Text '2026-08-07T12:01:04Z'
  Assert-Equal $t.Kind 'Utc' 'Kind'
  Assert-Equal $t.ToString('yyyy-MM-ddTHH:mm:ss') '2026-08-07T12:01:04' 'round-trip'
}
Check 'Read-IsoUtc parses the .NET round-trip "o" form (fractional seconds)' {
  $t = Read-IsoUtc -Text '2026-08-08T00:11:28.6711160Z'
  Assert-Equal $t.ToString('yyyy-MM-ddTHH:mm:ss') '2026-08-08T00:11:28' 'round-trip'
}
Check 'Read-IsoUtc returns $null rather than guessing on junk' {
  foreach ($bad in @('', '   ', 'not-a-date', '08/07/2026 12:01:04')) {
    if ($null -ne (Read-IsoUtc -Text $bad)) { throw "accepted '$bad'" }
  }
}
Check 'THE TRAP: a local-format string (what ConvertFrom-Json produces) is rejected, not misparsed' {
  # ConvertFrom-Json turns "2026-08-07T12:01:04Z" into 08/07/2026 12:01:04.
  # Read-IsoUtc must refuse it so callers fail loudly instead of computing an age
  # in the wrong basis. Under a non-US culture [datetime]::Parse would also throw.
  Assert-Equal (Read-IsoUtc -Text '08/07/2026 12:01:04') $null 'coerced local form'
}
Check 'Get-IsoUtcField extracts from a raw JSON line without parsing the JSON' {
  $line = '{"ts":"2026-08-07T12:01:04Z","local_date":"2026-08-07","event":"cycle_start"}'
  $t = Get-IsoUtcField -Line $line -Field 'ts'
  Assert-Equal $t.ToString('yyyy-MM-ddTHH:mm:ss') '2026-08-07T12:01:04' 'extracted ts'
}
Check 'Get-IsoUtcField returns $null for a field that is absent' {
  Assert-Equal (Get-IsoUtcField -Line '{"a":"b"}' -Field 'ts') $null 'absent field'
}
Check 'Get-IsoUtcField is not fooled by a similarly-named field' {
  $line = '{"not_ts":"2026-01-01T00:00:00Z","ts":"2026-08-07T12:01:04Z"}'
  $t = Get-IsoUtcField -Line $line -Field 'ts'
  Assert-Equal $t.ToString('yyyy-MM-dd') '2026-08-07' 'exact field match'
}
Check 'a full round-trip through ConvertTo-Json survives Get-IsoUtcField' {
  # This is the real lock/metrics path: write with Get-UtcStamp, read back from raw text.
  $stamp = Get-UtcStamp ([datetime]::SpecifyKind([datetime]'2026-08-08T03:30:22', 'Utc'))
  Assert-Equal $stamp '2026-08-08T03:30:22Z' 'Get-UtcStamp format'
  $line = @{ acquired_utc = $stamp } | ConvertTo-Json -Compress
  $back = Get-IsoUtcField -Line $line -Field 'acquired_utc'
  Assert-Equal $back.ToString('yyyy-MM-ddTHH:mm:ss') '2026-08-08T03:30:22' 'survived round-trip'
}
Check 'Get-LocalDateLabel applies UTC+10 and can differ from the UTC date' {
  # 2026-08-07T23:51Z is already 2026-08-08 in Brisbane. Truncating the UTC
  # timestamp would label it 08-07 and write an artifact consumers cannot glob.
  Assert-Equal (Get-LocalDateLabel ([datetime]::SpecifyKind([datetime]'2026-08-07T23:51:26', 'Utc'))) '2026-08-08' 'boundary case'
  Assert-Equal (Get-LocalDateLabel ([datetime]::SpecifyKind([datetime]'2026-08-07T03:00:00', 'Utc'))) '2026-08-07' 'same-day case'
}
Check 'Get-LocalDateLabel has no DST discontinuity (Brisbane is UTC+10 year-round)' {
  # A DST-aware zone would shift these by an hour relative to each other.
  Assert-Equal (Get-LocalDateLabel ([datetime]::SpecifyKind([datetime]'2026-01-15T14:00:00', 'Utc'))) '2026-01-16' 'January'
  Assert-Equal (Get-LocalDateLabel ([datetime]::SpecifyKind([datetime]'2026-07-15T14:00:00', 'Utc'))) '2026-07-16' 'July'
}

# ---- HP-33: runs that outlive the day they started in ----------------------
Check 'HP-33: the real 2026-08-07 case (16h28m) is labelled to the START day' {
  # Run launched 2026-08-07T06:29:17Z (16:29 local 08-07); finished 2026-08-07T23:51Z
  # (09:51 local 08-08). The artifact must be 2026-08-07, not 2026-08-08.
  $start = [datetime]::SpecifyKind([datetime]'2026-08-07T06:29:17', 'Utc')
  $end   = [datetime]::SpecifyKind([datetime]'2026-08-07T23:51:26', 'Utc')
  Assert-Equal (Get-RunDateLabel -RunStartUtc $start) '2026-08-07' 'label from run start'
  $r = Test-RunCrossedDateBoundary -RunStartUtc $start -NowUtc $end
  Assert-Equal $r.crossed $true 'crossed'
  Assert-Equal $r.now_label '2026-08-08' 'naive clock-read label'
  Assert-Equal $r.correct_label '2026-08-07' 'correct label'
  if ($r.elapsed_hours -lt 17.3 -or $r.elapsed_hours -gt 17.4) { throw "elapsed_hours=$($r.elapsed_hours), expected ~17.37" }
}
Check 'HP-33: the 2026-08-06 case (10h41m) also labels to the start day' {
  $start = [datetime]::SpecifyKind([datetime]'2026-08-06T09:56:41', 'Utc')
  $end   = [datetime]::SpecifyKind([datetime]'2026-08-06T22:03:55', 'Utc')
  $r = Test-RunCrossedDateBoundary -RunStartUtc $start -NowUtc $end
  # 19:56 local 08-06 -> 08:03 local 08-07: crossed.
  Assert-Equal $r.crossed $true 'crossed'
  Assert-Equal $r.correct_label '2026-08-06' 'correct label'
}
Check 'HP-33: an ordinary same-day run reports crossed=false' {
  $start = [datetime]::SpecifyKind([datetime]'2026-08-08T02:21:37', 'Utc')   # 12:21 local
  $end   = [datetime]::SpecifyKind([datetime]'2026-08-08T03:30:00', 'Utc')   # 13:30 local
  $r = Test-RunCrossedDateBoundary -RunStartUtc $start -NowUtc $end
  Assert-Equal $r.crossed $false 'not crossed'
  Assert-Equal $r.start_label $r.now_label 'labels agree'
}
Check 'HP-33: a long run that does NOT cross the local boundary is not flagged' {
  # 8 hours entirely inside one Brisbane day: 00:30 -> 08:30 local.
  $start = [datetime]::SpecifyKind([datetime]'2026-08-07T14:30:00', 'Utc')
  $end   = [datetime]::SpecifyKind([datetime]'2026-08-07T22:30:00', 'Utc')
  $r = Test-RunCrossedDateBoundary -RunStartUtc $start -NowUtc $end
  Assert-Equal $r.crossed $false 'duration alone must not trigger it'
  Assert-Equal $r.elapsed_hours 8 'elapsed'
}

Write-Host ""
Write-Host "  $pass passed, $fail failed" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 } else { exit 0 }
