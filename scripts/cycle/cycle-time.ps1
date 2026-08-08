<#
  Shared UTC-timestamp handling for the cycle harness. Dot-source it:

      . (Join-Path $PSScriptRoot 'cycle-time.ps1')

  WHY THIS FILE EXISTS
  --------------------
  `ConvertFrom-Json` silently coerces any ISO-8601-looking string into a
  [datetime] and re-renders it in the *local* short format with no offset:

      raw JSON      : "ts":"2026-08-07T12:01:04Z"
      after parse   : 08/07/2026 12:01:04     [System.DateTime]

  Two consequences, both observed live on 2026-08-07:

  1. `[datetime]::Parse()` / `ParseExact()` on the coerced value THROWS under a
     non-US culture ("String '07/17/2026 02:37:47' was not recognized...").
  2. The UTC basis is gone. Anything that then buckets by day, computes an age, or
     compares against a cron slot is silently working in the wrong basis — the
     exact failure class the fleet's DOC-36 rule exists to prevent.

  It caused three separate defects in one session: a PR-age table where failed
  parses silently carried the previous row's age forward (reporting 153d for a
  7-day-old PR), an exit-log day filter, and a runner lock that read every lock as
  stale and therefore never locked at all.

  RULE: never read a timestamp through ConvertFrom-Json. Pull it out of the raw
  text first with Get-IsoUtcField, then parse with Read-IsoUtc.
#>

Set-StrictMode -Version Latest

function Read-IsoUtc {
  <#
    Parse a strict ISO-8601 UTC string ("2026-08-07T12:01:04Z") to a [datetime]
    in UTC. Returns $null on anything it cannot parse — callers decide whether an
    unparseable timestamp is fatal, rather than getting a wrong answer.

    Accepts an optional fractional-seconds part, which append-exit-row.ps1 and
    .NET's round-trip "o" format both emit.
  #>
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  $formats = @(
    'yyyy-MM-ddTHH:mm:ssZ',
    'yyyy-MM-ddTHH:mm:ss.fffffffZ',
    'yyyy-MM-ddTHH:mm:ss.ffffffZ',
    'yyyy-MM-ddTHH:mm:ss.fffZ',
    "yyyy-MM-ddTHH:mm:ss.FFFFFFFK",
    'o'
  )
  $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
            [System.Globalization.DateTimeStyles]::AdjustToUniversal
  foreach ($f in $formats) {
    [datetime]$parsed = [datetime]::MinValue
    if ([datetime]::TryParseExact($Text, $f, [cultureinfo]::InvariantCulture, $styles, [ref]$parsed)) {
      return $parsed
    }
  }
  return $null
}

function Get-IsoUtcField {
  <#
    Extract a timestamp field from a raw JSON *line* without parsing the JSON, so
    ConvertFrom-Json never gets a chance to coerce it.

        Get-IsoUtcField -Line $line -Field 'ts'   ->  [datetime] (UTC) or $null
  #>
  param(
    [Parameter(Mandatory = $true)][string]$Line,
    [Parameter(Mandatory = $true)][string]$Field
  )
  $rx = '"' + [regex]::Escape($Field) + '"\s*:\s*"([^"]+)"'
  $m = [regex]::Match($Line, $rx)
  if (-not $m.Success) { return $null }
  return Read-IsoUtc -Text $m.Groups[1].Value
}

function Get-LocalDateLabel {
  <#
    The fleet's date LABEL basis: Australia/Brisbane, UTC+10, no DST. Filenames,
    report headings and day buckets use this; timestamps stay UTC with Z.
    Truncating a UTC timestamp to get a date label is the bug this prevents.
  #>
  param([datetime]$Utc = ((Get-Date).ToUniversalTime()))
  return $Utc.AddHours(10).ToString('yyyy-MM-dd')
}

function Get-UtcStamp {
  param([datetime]$Utc = ((Get-Date).ToUniversalTime()))
  return $Utc.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# --- HP-33: runs that outlive the day they started in -----------------------
#
# Observed twice, worsening: a scheduled-task session slept mid-run and finished
# on the NEXT local day (10h41m on 2026-08-06, 16h28m on 2026-08-07). Neither was
# clock skew — w32tm synced, no reboot, and sibling routines appended exit rows
# while the session idled.
#
# It is not a hang either. Each routine run takes roughly an hour and the
# dispatcher is serial (FH-77), so a long run crossing midnight is ordinary. The
# harm is not the duration — it is that a run finishing after midnight labels its
# artifact with "today", which is the wrong day, and its own consumers then cannot
# glob the input they need.
#
# So the correction is NOT to reap long-running sessions (that would strand
# mid-write work). It is to derive the date label from WHEN THE RUN STARTED — the
# scheduler's period — and to make boundary-crossing visible rather than silent.

function Get-RunDateLabel {
  <#
    The LOCAL date label an artifact should carry: the day the run STARTED, not the
    day it happens to finish. Pass the scheduler's lastRunAt (UTC).

    Deriving the label from the clock at write time is the bug: it silently
    reassigns a run to the following day and strands the previous day dark.
  #>
  param([Parameter(Mandatory = $true)][datetime]$RunStartUtc)
  return Get-LocalDateLabel -Utc $RunStartUtc
}

function Test-RunCrossedDateBoundary {
  <#
    Reports whether a run has outlived the local day it began in, and by how much.
    Returns an object rather than a bare bool so a routine can put real numbers in
    its report instead of "seems slow".

      crossed        - did the local date change since the run started
      elapsed_hours  - wall-clock hours, rounded to 2dp
      start_label    - the local date label the artifact SHOULD use
      now_label      - the local date label a naive clock read WOULD use
  #>
  param(
    [Parameter(Mandatory = $true)][datetime]$RunStartUtc,
    [datetime]$NowUtc = ((Get-Date).ToUniversalTime())
  )
  $startLabel = Get-LocalDateLabel -Utc $RunStartUtc
  $nowLabel   = Get-LocalDateLabel -Utc $NowUtc
  return [pscustomobject]@{
    crossed       = ($startLabel -ne $nowLabel)
    elapsed_hours = [math]::Round(($NowUtc - $RunStartUtc).TotalHours, 2)
    start_label   = $startLabel
    now_label     = $nowLabel
    correct_label = $startLabel
  }
}
