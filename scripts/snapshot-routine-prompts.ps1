# Snapshots fleet routine prompts (SKILL.md) into version control.
# The live prompts in ~/.claude/scheduled-tasks are NOT a git repo; prompt-evolution
# mutates them weekly. This snapshot makes every change diffable and revertable.
# LEAK GUARD: personal tasks (japan-*, etc.) are excluded — never commit personal content.
param(
  [string]$Source = (Join-Path $env:USERPROFILE ".claude\scheduled-tasks"),
  [string]$Dest   = (Join-Path $PSScriptRoot "..\routines\prompts"),
  [string[]]$ExcludePatterns = @('japan-*')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Dest | Out-Null
$copied = @()
foreach ($dir in Get-ChildItem $Source -Directory) {
  $excluded = $false
  foreach ($p in $ExcludePatterns) { if ($dir.Name -like $p) { $excluded = $true; break } }
  if ($excluded) { continue }
  $skill = Join-Path $dir.FullName 'SKILL.md'
  if (Test-Path $skill) {
    $out = Join-Path $Dest $dir.Name
    New-Item -ItemType Directory -Force $out | Out-Null
    Copy-Item $skill (Join-Path $out 'SKILL.md') -Force
    $copied += $dir.Name
  }
}
Write-Output "Snapshotted $($copied.Count) prompts -> $Dest"
$copied | ForEach-Object { Write-Output "  $_" }
