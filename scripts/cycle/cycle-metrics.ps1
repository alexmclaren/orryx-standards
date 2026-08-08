<#
.SYNOPSIS
  Append or summarise autonomous-cycle metrics.

.DESCRIPTION
  The fleet already has fleet-exit-log.jsonl (did a routine run?) but nothing that
  answers "how much useful engineering actually completed, and where did the time
  go?". This is that ledger.

  Append one row per event:
      cycle_start, task_selected, review_done, merge_attempt, cycle_end, halt, idle

  Then -Summary renders the operator-requested metrics for a local day:
    cycles, completions, selection->merge latency, CI first-pass rate, retries,
    halts by cause, % needing a human, duplicate work, uninterrupted runtime,
    review rejection rate, queue depth/age, idle-despite-available-work.

  Timestamps are UTC with Z. Day bucketing is by LOCAL date (Australia/Brisbane,
  UTC+10, no DST) per the fleet's DOC-36 rule: date LABELS are local, timestamps
  are UTC. Bucketing on UTC would split a working evening across two days.

  Rows are read with a regex, never ConvertFrom-Json, for timestamp fields —
  ConvertFrom-Json silently coerces an ISO-8601 string to [datetime] and re-renders
  it in local format without the Z, which loses the basis and breaks
  [datetime]::Parse under a non-US culture.
#>
[CmdletBinding(DefaultParameterSetName = 'Append')]
param(
  [Parameter(ParameterSetName = 'Append')][switch]$Append,
  [Parameter(ParameterSetName = 'Append')][string]$Repo = '',
  [Parameter(ParameterSetName = 'Append')][int]$Pr = 0,
  [Parameter(ParameterSetName = 'Append')][ValidateSet('cycle_start','task_selected','review_done','merge_attempt','cycle_end','halt','idle')][string]$Event = 'cycle_start',
  [Parameter(ParameterSetName = 'Append')][string]$Outcome = '',
  [Parameter(ParameterSetName = 'Append')][string]$Detail = '',
  [Parameter(ParameterSetName = 'Append')][string]$WorkClass = '',
  [Parameter(ParameterSetName = 'Append')][string]$CycleId = '',

  [Parameter(ParameterSetName = 'Summary', Mandatory = $true)][switch]$Summary,
  [Parameter(ParameterSetName = 'Summary')][string]$Date,

  [string]$MetricsFile = 'D:\reports\evolution\cycle-metrics.jsonl'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get-LocalDateLabel / Read-IsoUtc / Get-IsoUtcField / Get-UtcStamp all live here,
# so the ConvertFrom-Json timestamp-coercion trap is handled in exactly one place.
. (Join-Path $PSScriptRoot 'cycle-time.ps1')

if ($PSCmdlet.ParameterSetName -eq 'Append') {
  $dir = Split-Path -Parent $MetricsFile
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utc = (Get-Date).ToUniversalTime()
  $row = [ordered]@{
    ts         = $utc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    local_date = Get-LocalDateLabel -Utc $utc
    cycle_id   = $CycleId
    event      = $Event
    repo       = $Repo
    pr         = $Pr
    work_class = $WorkClass
    outcome    = $Outcome
    detail     = $Detail
  }
  # Compact single line; Add-Content is atomic enough for one writer per cycle and
  # the runner holds a lock, so interleaving is not a concern here.
  Add-Content -Path $MetricsFile -Value ($row | ConvertTo-Json -Compress -Depth 4) -Encoding utf8
  return [pscustomobject]$row
}

# --- summary ---------------------------------------------------------------
if (-not (Test-Path $MetricsFile)) {
  Write-Host "No metrics yet at $MetricsFile"
  return
}
if (-not $Date) { $Date = Get-LocalDateLabel -Utc (Get-Date).ToUniversalTime() }

$rows = @()
foreach ($line in (Get-Content $MetricsFile)) {
  if (-not $line.Trim()) { continue }
  # Pull timestamp fields out as raw strings BEFORE any JSON parse.
  $ld = if ($line -match '"local_date":"([^"]+)"') { $Matches[1] } else { $null }
  if ($ld -ne $Date) { continue }
  try { $o = $line | ConvertFrom-Json } catch { continue }
  $ts = Get-IsoUtcField -Line $line -Field 'ts'
  $rows += [pscustomobject]@{
    ts = $ts; event = [string]$o.event; repo = [string]$o.repo; pr = [int]$o.pr
    work_class = [string]$o.work_class; outcome = [string]$o.outcome
    detail = [string]$o.detail; cycle_id = [string]$o.cycle_id
  }
}

if ($rows.Count -eq 0) { Write-Host "No cycle activity recorded for $Date"; return }

$starts   = @($rows | Where-Object { $_.event -eq 'cycle_start' })
$ends     = @($rows | Where-Object { $_.event -eq 'cycle_end' })
$selected = @($rows | Where-Object { $_.event -eq 'task_selected' })
$merges   = @($rows | Where-Object { $_.event -eq 'merge_attempt' })
$merged   = @($merges | Where-Object { $_.outcome -eq 'merged' })
$blocked  = @($merges | Where-Object { $_.outcome -eq 'blocked' })
$failed   = @($merges | Where-Object { $_.outcome -eq 'merge_failed' })
$reviews  = @($rows | Where-Object { $_.event -eq 'review_done' })
$rejected = @($reviews | Where-Object { $_.outcome -ne 'APPROVE' })
$halts    = @($rows | Where-Object { $_.event -eq 'halt' })
$idles    = @($rows | Where-Object { $_.event -eq 'idle' })

# selection -> merge latency, matched per repo+pr
$latencies = @()
foreach ($m in $merged) {
  $sel = @($selected | Where-Object { $_.repo -eq $m.repo -and $_.pr -eq $m.pr -and $_.ts -le $m.ts } | Sort-Object ts | Select-Object -Last 1)
  if ($sel.Count -eq 1 -and $sel[0].ts -and $m.ts) { $latencies += [int]($m.ts - $sel[0].ts).TotalMinutes }
}

# uninterrupted runtime per cycle_id
$runtimes = @()
foreach ($g in ($rows | Where-Object { $_.cycle_id } | Group-Object cycle_id)) {
  $t = @($g.Group | Where-Object { $_.ts } | Sort-Object ts)
  if ($t.Count -ge 2) { $runtimes += [int]($t[-1].ts - $t[0].ts).TotalMinutes }
}

# duplicate work: the same repo+pr selected in more than one distinct cycle
$dupes = @($selected | Group-Object { "$($_.repo)#$($_.pr)" } |
           Where-Object { (@($_.Group | Select-Object -ExpandProperty cycle_id -Unique)).Count -gt 1 })

$ciFirstPass = if ($merges.Count) {
  $ciBlocks = @($blocked | Where-Object { $_.detail -match 'CI_NOT_GREEN|CI_INCOMPLETE|REQUIRED_CONTEXT_NOT_GREEN' }).Count
  [math]::Round(100.0 * ($merges.Count - $ciBlocks) / $merges.Count, 1)
} else { $null }

$humanNeeded = if ($merges.Count) {
  $h = @($blocked | Where-Object { $_.detail -match 'HUMAN_ONLY_SURFACE|SCOPE_TOO_|CHANGES_REQUESTED' }).Count
  [math]::Round(100.0 * $h / $merges.Count, 1)
} else { $null }

$out = [pscustomobject]@{
  local_date                    = $Date
  cycles_started                = $starts.Count
  cycles_completed              = $ends.Count
  tasks_selected                = $selected.Count
  merges_succeeded              = $merged.Count
  merges_blocked_by_gate        = $blocked.Count
  merges_failed                 = $failed.Count
  reviews_performed             = $reviews.Count
  review_rejection_rate_pct     = if ($reviews.Count) { [math]::Round(100.0 * $rejected.Count / $reviews.Count, 1) } else { $null }
  ci_first_pass_rate_pct        = $ciFirstPass
  pct_blocked_needing_human     = $humanNeeded
  selection_to_merge_min_median = if ($latencies.Count) { (@($latencies | Sort-Object))[[int]($latencies.Count / 2)] } else { $null }
  avg_uninterrupted_runtime_min = if ($runtimes.Count) { [int](($runtimes | Measure-Object -Average).Average) } else { $null }
  duplicate_selections          = $dupes.Count
  halts                         = $halts.Count
  halt_causes                   = @($halts | Group-Object outcome | ForEach-Object { "$($_.Name)=$($_.Count)" })
  idle_events                   = $idles.Count
  idle_with_work_available      = @($idles | Where-Object { $_.detail -match 'queue_depth=[1-9]' }).Count
}
return $out
