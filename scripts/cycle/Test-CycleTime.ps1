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

Write-Host ""
Write-Host "  $pass passed, $fail failed" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 } else { exit 0 }
