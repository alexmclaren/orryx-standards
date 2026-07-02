# Regenerates the Mermaid fleet DAG in architecture/03-fleet-dag.md
# from routines/routine-schedule.json. Idempotent; safe to run anytime.
param(
  [string]$Schedule = (Join-Path $PSScriptRoot "..\routines\routine-schedule.json"),
  [string]$Target   = (Join-Path $PSScriptRoot "..\architecture\03-fleet-dag.md")
)
$ErrorActionPreference = 'Stop'
$data = Get-Content $Schedule -Raw | ConvertFrom-Json

$lines = @('flowchart TD')
foreach ($L in ($data._meta.layers.PSObject.Properties.Name | Sort-Object)) {
  $desc = $data._meta.layers.$L -replace '"', "'"
  $lines += "  subgraph $L[`"$L — $desc`"]"
  foreach ($r in $data.routines.PSObject.Properties) {
    if ($r.Value.layer -eq $L) {
      $id = $r.Name -replace '[^A-Za-z0-9]', '_'
      $lines += "    $id[`"$($r.Name)<br/>$($r.Value.cadence) · $($r.Value.cron)`"]"
    }
  }
  $lines += '  end'
}
foreach ($r in $data.routines.PSObject.Properties) {
  $id = $r.Name -replace '[^A-Za-z0-9]', '_'
  foreach ($dep in @($r.Value.depends_on)) {
    if ($dep) { $lines += "  $($dep -replace '[^A-Za-z0-9]','_') --> $id" }
  }
}

$fence = '```'
$block = "$fence" + "mermaid`n" + ($lines -join "`n") + "`n$fence"
$content = Get-Content $Target -Raw
$pattern = '(?s)(<!-- GENERATED:fleet-dag:start -->).*?(<!-- GENERATED:fleet-dag:end -->)'
if ($content -notmatch $pattern) { throw "Markers not found in $Target" }
$content = [regex]::Replace($content, $pattern, "`$1`n$block`n`$2")
Set-Content -Path $Target -Value $content -NoNewline -Encoding utf8
Write-Output "Fleet DAG regenerated from $(Split-Path $Schedule -Leaf) ($(@($data.routines.PSObject.Properties).Count) routines)."
