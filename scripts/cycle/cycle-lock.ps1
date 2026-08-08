<#
.SYNOPSIS
  Single-owner lock for the autonomous cycle runner, with stale-lock recovery.

.DESCRIPTION
  Stops two runners (a cron heartbeat and an operator-triggered run, or two
  catch-up burst fires) from selecting the same task and merging it twice.

  A lock is a JSON file recording owner, PID and UTC acquisition time.

  Stale recovery: a lock older than -TtlMinutes is reclaimable. The fleet has
  already been bitten by the opposite choice — an indefinite lock left after a
  crashed session blocks every later run and looks identical to "nothing to do".
  A TTL fails toward liveness; the merge gate is what protects correctness, so a
  reclaimed lock cannot cause an unsafe merge, only a wasted one.

  Also treats a lock whose PID is gone as stale regardless of age, so a machine
  restart recovers immediately rather than after the TTL.

      -Acquire   exit 0 = acquired, exit 1 = held by someone else
      -Release   release only if we own it (or -Force)
      -Status    print current holder

.PARAMETER Owner
  Identity string for the holder (default: "cycle-runner-<pid>").
#>
[CmdletBinding()]
param(
  [switch]$Acquire,
  [switch]$Release,
  [switch]$Status,
  [string]$Owner = "cycle-runner-$PID",
  [int]$TtlMinutes = 90,
  [switch]$Force,
  [string]$LockFile = 'D:\state\cycles\.runner.lock'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dir = Split-Path -Parent $LockFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

. (Join-Path $PSScriptRoot 'cycle-time.ps1')

$script:LockRaw = $null

function Read-Lock {
  $script:LockRaw = $null
  if (-not (Test-Path $LockFile)) { return $null }
  $script:LockRaw = Get-Content $LockFile -Raw
  try { return $script:LockRaw | ConvertFrom-Json } catch { return 'CORRUPT' }
}

function Test-Stale {
  param($Lock)
  if ($Lock -eq 'CORRUPT') { return $true }
  # PID gone => stale immediately (covers machine restart / killed session).
  if ($Lock.PSObject.Properties.Name -contains 'pid' -and $Lock.pid) {
    if (-not (Get-Process -Id ([int]$Lock.pid) -ErrorAction SilentlyContinue)) { return $true }
  }
  # Read acquired_utc from the RAW text, never from the parsed object:
  # ConvertFrom-Json has already coerced it to a local [datetime] with the Z
  # stripped, so ParseExact on it always threw — which made every lock look stale
  # and silently removed all mutual exclusion. See cycle-time.ps1.
  $t = Get-IsoUtcField -Line $script:LockRaw -Field 'acquired_utc'
  if (-not $t) { return $true }
  return (((Get-Date).ToUniversalTime() - $t).TotalMinutes -gt $TtlMinutes)
}

if ($Status) {
  $l = Read-Lock
  if (-not $l) { Write-Host 'unlocked'; exit 0 }
  if ($l -eq 'CORRUPT') { Write-Host 'CORRUPT lock file (reclaimable)'; exit 0 }
  $stale = Test-Stale -Lock $l
  Write-Host "held by $($l.owner) pid=$($l.pid) since $(Get-UtcStamp (Get-IsoUtcField -Line $script:LockRaw -Field 'acquired_utc')) stale=$stale"
  exit 0
}

if ($Acquire) {
  $l = Read-Lock
  if ($l) {
    if (Test-Stale -Lock $l) {
      $who = if ($l -eq 'CORRUPT') { 'corrupt' } else { $l.owner }
      Write-Host "reclaiming stale lock (was: $who)" -ForegroundColor Yellow
    } else {
      Write-Host "LOCKED by $($l.owner) since $(Get-UtcStamp (Get-IsoUtcField -Line $script:LockRaw -Field 'acquired_utc'))" -ForegroundColor Yellow
      exit 1
    }
  }
  [ordered]@{
    owner = $Owner; pid = $PID
    acquired_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    ttl_minutes = $TtlMinutes
  } | ConvertTo-Json | Set-Content -Path $LockFile -Encoding utf8
  Write-Host "acquired by $Owner"
  exit 0
}

if ($Release) {
  $l = Read-Lock
  if (-not $l) { Write-Host 'already unlocked'; exit 0 }
  if (-not $Force -and $l -ne 'CORRUPT' -and $l.owner -ne $Owner) {
    Write-Host "refusing to release a lock owned by $($l.owner) (use -Force)" -ForegroundColor Yellow
    exit 1
  }
  Remove-Item $LockFile -Force
  Write-Host 'released'
  exit 0
}

Write-Host 'Specify -Acquire, -Release or -Status.'
exit 2
