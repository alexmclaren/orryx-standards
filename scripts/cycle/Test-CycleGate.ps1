<#
  Self-test for cycle-gate.ps1 — the merge-authority safety core.

  No test framework on purpose: plain asserts, runnable anywhere pwsh is, zero
  install. Every rule in the gate has at least one test, and every fail-closed
  path is asserted to BLOCK rather than merely "not ALLOW".

      pwsh -NoProfile -File scripts/cycle/Test-CycleGate.ps1

  Exit code 0 = all passed, 1 = at least one failure.
#>
[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gate = Join-Path $PSScriptRoot 'cycle-gate.ps1'
if (-not (Test-Path $gate)) { throw "cycle-gate.ps1 not found beside this test at $gate" }

$sandbox    = Join-Path ([IO.Path]::GetTempPath()) ("cyclegate-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
$reviewDir  = Join-Path $sandbox 'reviews'
New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null

$protFile = Join-Path $sandbox 'branch-protection.json'
@{
  repos = @{
    'acme/protected'   = @{ branch = 'main'; expected = @{ contexts = @('backend-tests', 'Gitleaks (full tree, blocking)') } }
    'acme/unprotected' = @{ branch = 'main'; expected = $null }
  }
} | ConvertTo-Json -Depth 8 | Set-Content -Path $protFile -Encoding utf8

$HEAD = 'a'* 40
$OTHER = 'b'* 40

function New-PrState {
  param([hashtable]$Override = @{})
  $base = @{
    number = 1; isDraft = $false; mergeable = 'MERGEABLE'; mergeStateStatus = 'CLEAN'
    headRefOid = $HEAD; reviewDecision = ''; baseRefName = 'main'; title = 't'; url = 'u'
    additions = 10; deletions = 1
    files = @(@{ path = 'src/app.ts' })
    statusCheckRollup = @(@{ name = 'backend-tests'; status = 'COMPLETED'; conclusion = 'SUCCESS' })
    reviewThreads = @()
    # A benign patch by default. Elevated risk requires a patch to be present at
    # all, so tests that assert elevated behaviour must supply one.
    patch = "diff --git a/src/app.ts b/src/app.ts`n+const x = 1;`n"
  }
  foreach ($k in $Override.Keys) { $base[$k] = $Override[$k] }
  return ([pscustomobject]$base)
}

# All evidence keys any elevated rule can demand. Tests pass a subset to prove a
# missing key still blocks.
$ALL_EVIDENCE = @{
  full_diff_reviewed = $true; workflow_syntax_validated = $true
  deployment_impact = $true; rollback_verified = $true
  migration_reversibility = $true; business_intent_source = $true
  privacy_review = $true; no_secret_material = $true; second_review_pass = $true
}

function Write-Review {
  param([string]$Repo, [int]$Pr, [string]$Sha = $HEAD, [string]$Verdict = 'APPROVE',
        [string]$Reviewer = 'reviewer-pass', [string]$AuthoredBy = 'implementer-pass',
        [string]$Depth = 'ordinary', [hashtable]$Evidence, [hashtable]$Marker)
  $p = Join-Path $reviewDir (($Repo -replace '/', '__') + "__$Pr.json")
  $o = @{ reviewed_sha = $Sha; verdict = $Verdict; reviewer = $Reviewer; authored_by = $AuthoredBy
          review_depth = $Depth; at = (Get-Date).ToUniversalTime().ToString('o') }
  if ($Evidence) { $o.evidence = $Evidence }
  if ($Marker)   { $o.marker_adjudication = $Marker }
  $o | ConvertTo-Json -Depth 6 | Set-Content -Path $p -Encoding utf8
}

function Invoke-Gate {
  param([string]$Repo, [int]$Pr, [psobject]$State, [switch]$AllowNoCI, [int]$MaxFiles = 40)
  $p = @{ Repo = $Repo; Pr = $Pr; InputObject = $State; StateRoot = $sandbox
          ProtectionFile = $protFile; MaxFiles = $MaxFiles }
  if ($AllowNoCI) { $p.AllowNoCI = $true }
  & $gate @p
}

$pass = 0; $fail = 0
function Check {
  param([string]$Name, [scriptblock]$Body)
  try {
    & $Body
    $script:pass++
    if (-not $Quiet) { Write-Host "  PASS  $Name" -ForegroundColor DarkGreen }
  } catch {
    $script:fail++
    Write-Host "  FAIL  $Name" -ForegroundColor Red
    Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
  }
}
function Assert-Verdict {
  param($Result, [string]$Expected)
  if ($Result.verdict -ne $Expected) {
    throw "expected verdict $Expected, got $($Result.verdict). reasons: $(($Result.reasons | ForEach-Object { $_.code }) -join ',')"
  }
}
function Assert-Reason {
  param($Result, [string]$Code)
  $codes = @($Result.reasons | ForEach-Object { $_.code })
  if ($codes -notcontains $Code) { throw "expected reason '$Code'; got: $($codes -join ',')" }
}
function Assert-Equal {
  param($Actual, $Expected, [string]$What = 'value')
  if ($Actual -ne $Expected) { throw "$What : expected '$Expected', got '$Actual'" }
}

Write-Host "cycle-gate self-test" -ForegroundColor Cyan
Write-Host "  sandbox: $sandbox"

# ---- the one and only ALLOW path -------------------------------------------
Check 'ALLOW when every criterion is satisfied' {
  Write-Review -Repo 'acme/unprotected' -Pr 10
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 10 -State (New-PrState)
  Assert-Verdict $r 'ALLOW'
}

# ---- C1 draft --------------------------------------------------------------
Check 'BLOCK a draft PR' {
  Write-Review -Repo 'acme/unprotected' -Pr 11
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 11 -State (New-PrState @{ isDraft = $true })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'IS_DRAFT'
}

# ---- C2 mergeability -------------------------------------------------------
Check 'BLOCK when mergeStateStatus=BEHIND' {
  Write-Review -Repo 'acme/unprotected' -Pr 12
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 12 -State (New-PrState @{ mergeStateStatus = 'BEHIND' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MERGE_STATE_NOT_CLEAN'
}
Check 'BLOCK when conflicting (DIRTY)' {
  Write-Review -Repo 'acme/unprotected' -Pr 13
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 13 -State (New-PrState @{ mergeable = 'CONFLICTING'; mergeStateStatus = 'DIRTY' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NOT_MERGEABLE'
}
Check 'BLOCK when mergeability still UNKNOWN (fail closed)' {
  Write-Review -Repo 'acme/unprotected' -Pr 14
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 14 -State (New-PrState @{ mergeable = 'UNKNOWN'; mergeStateStatus = 'UNKNOWN' })
  Assert-Verdict $r 'BLOCK'
}

# ---- C3 CI evidence -- the most dangerous rule -----------------------------
Check 'BLOCK when zero checks reported (absent CI is NOT green)' {
  Write-Review -Repo 'acme/unprotected' -Pr 20
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 20 -State (New-PrState @{ statusCheckRollup = @() })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NO_CI_EVIDENCE'
}
Check 'zero checks may pass C3 only with explicit -AllowNoCI, and it is recorded' {
  Write-Review -Repo 'acme/unprotected' -Pr 21
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 21 -State (New-PrState @{ statusCheckRollup = @() }) -AllowNoCI
  Assert-Verdict $r 'ALLOW'
  Assert-Equal $r.allow_no_ci $true 'allow_no_ci recorded in verdict'
}
Check 'BLOCK on a failing check' {
  Write-Review -Repo 'acme/unprotected' -Pr 22
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 22 -State (New-PrState @{
    statusCheckRollup = @(@{ name = 'backend-tests'; status = 'COMPLETED'; conclusion = 'FAILURE' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'CI_NOT_GREEN'
}
Check 'BLOCK while a check is still running' {
  Write-Review -Repo 'acme/unprotected' -Pr 23
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 23 -State (New-PrState @{
    statusCheckRollup = @(@{ name = 'backend-tests'; status = 'IN_PROGRESS'; conclusion = $null }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'CI_INCOMPLETE'
}
Check 'SKIPPED and NEUTRAL conclusions are acceptable' {
  Write-Review -Repo 'acme/unprotected' -Pr 24
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 24 -State (New-PrState @{
    statusCheckRollup = @(
      @{ name = 'a'; status = 'COMPLETED'; conclusion = 'SKIPPED' },
      @{ name = 'b'; status = 'COMPLETED'; conclusion = 'NEUTRAL' }) })
  Assert-Verdict $r 'ALLOW'
}

# ---- C4 declared protection, enforced by exact name ------------------------
Check 'BLOCK when a declared required context did not report' {
  Write-Review -Repo 'acme/protected' -Pr 30
  $r = Invoke-Gate -Repo 'acme/protected' -Pr 30 -State (New-PrState)   # only backend-tests present
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REQUIRED_CONTEXT_MISSING'
}
Check 'ALLOW when every declared required context reports SUCCESS' {
  Write-Review -Repo 'acme/protected' -Pr 31
  $r = Invoke-Gate -Repo 'acme/protected' -Pr 31 -State (New-PrState @{
    statusCheckRollup = @(
      @{ name = 'backend-tests'; status = 'COMPLETED'; conclusion = 'SUCCESS' },
      @{ name = 'Gitleaks (full tree, blocking)'; status = 'COMPLETED'; conclusion = 'SUCCESS' }) })
  Assert-Verdict $r 'ALLOW'
}
Check 'required-context match is byte-exact (case difference does NOT satisfy it)' {
  Write-Review -Repo 'acme/protected' -Pr 32
  $r = Invoke-Gate -Repo 'acme/protected' -Pr 32 -State (New-PrState @{
    statusCheckRollup = @(
      @{ name = 'Backend-Tests'; status = 'COMPLETED'; conclusion = 'SUCCESS' },
      @{ name = 'Gitleaks (full tree, blocking)'; status = 'COMPLETED'; conclusion = 'SUCCESS' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REQUIRED_CONTEXT_MISSING'
}
Check 'BLOCK when protection is declared for a different base branch' {
  Write-Review -Repo 'acme/protected' -Pr 33
  $r = Invoke-Gate -Repo 'acme/protected' -Pr 33 -State (New-PrState @{
    baseRefName = 'develop'
    statusCheckRollup = @(
      @{ name = 'backend-tests'; status = 'COMPLETED'; conclusion = 'SUCCESS' },
      @{ name = 'Gitleaks (full tree, blocking)'; status = 'COMPLETED'; conclusion = 'SUCCESS' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'PROTECTION_UNDECLARED_FOR_BASE'
}
Check 'BLOCK when the protection declaration file is missing' {
  Write-Review -Repo 'acme/unprotected' -Pr 34
  $r = & $gate -Repo 'acme/unprotected' -Pr 34 -InputObject (New-PrState) -StateRoot $sandbox `
        -ProtectionFile (Join-Path $sandbox 'nope.json')
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'PROTECTION_FILE_MISSING'
}

# ---- C5 review state -------------------------------------------------------
Check 'BLOCK when changes were requested' {
  Write-Review -Repo 'acme/unprotected' -Pr 40
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 40 -State (New-PrState @{ reviewDecision = 'CHANGES_REQUESTED' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'CHANGES_REQUESTED'
}
Check 'BLOCK on unresolved review threads' {
  Write-Review -Repo 'acme/unprotected' -Pr 41
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 41 -State (New-PrState @{
    reviewThreads = @(@{ isResolved = $false }, @{ isResolved = $true }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'UNRESOLVED_REVIEW_THREADS'
}

# ---- C6 human-only surfaces -----------------------------------------------
$humanOnly = @{
  'a DB migration'      = 'backend/migrations/0007_add_col.py'
  'a raw SQL file'      = 'db/fix.sql'
  'a dotenv file'       = 'services/.env.production'
  'a private key'       = 'deploy/id_rsa.key'
  'pricing code'        = 'src/pricing/tiers.ts'
  'Stripe integration'  = 'api/stripe_webhook.py'
  'terraform'           = 'infra/terraform/rds.tf'
  'kubernetes config'   = 'k8s/configmap.yaml'
  'a CI workflow'       = '.github/workflows/deploy.yml'
  'legal terms'         = 'legal/terms-of-service.md'
  'patient data code'   = 'app/patient_record.py'
}
$i = 50
foreach ($what in $humanOnly.Keys) {
  $path = $humanOnly[$what]
  $n = $i; $i++
  # These are now ELEVATED, not absolute. An ordinary-depth review must still not
  # clear them: the change blocks for want of evidence, not for want of a human.
  Check "ELEVATED: $what needs evidence, ordinary review does not clear it ($path)" {
    Write-Review -Repo 'acme/unprotected' -Pr $n
    $r = Invoke-Gate -Repo 'acme/unprotected' -Pr $n -State (New-PrState @{ files = @(@{ path = $path }) })
    Assert-Verdict $r 'BLOCK'
    Assert-Reason $r 'ELEVATED_EVIDENCE_MISSING'
    Assert-Reason $r 'ELEVATED_REVIEW_REQUIRED'
  }.GetNewClosure()
}

# ---- C6b explicit human-gate markers --------------------------------------
# Regression guard: orryx-flow #49 was ALLOWed on 2026-08-08 despite carrying
# "[REQUIRES HUMAN REVIEW]" in its title, because every risk check was path-based.
Check 'BLOCK on [REQUIRES HUMAN REVIEW] in the title' {
  Write-Review -Repo 'acme/unprotected' -Pr 61
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 61 -State (New-PrState @{
    title = 'fix(security): reject non-access JWTs as bearer credentials [REQUIRES HUMAN REVIEW]' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MARKER_UNADJUDICATED'
}
Check 'BLOCK on [REQUIRES HUMAN REVIEW] in the body' {
  Write-Review -Repo 'acme/unprotected' -Pr 62
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 62 -State (New-PrState @{
    body = "Implements the thing.`n`n[REQUIRES HUMAN REVIEW] - touches consent logic." })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MARKER_UNADJUDICATED'
}
Check 'BLOCK on a do-not-merge label' {
  Write-Review -Repo 'acme/unprotected' -Pr 63
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 63 -State (New-PrState @{
    labels = @(@{ name = 'do-not-merge' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MARKER_UNADJUDICATED'
}
Check 'BLOCK on DO NOT MERGE in the title' {
  Write-Review -Repo 'acme/unprotected' -Pr 64
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 64 -State (New-PrState @{
    title = 'RLS fail-closed + secret scrub (DO NOT MERGE - staged)' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MARKER_UNADJUDICATED'
}
Check 'the marker match is not so loose it catches ordinary review wording' {
  Write-Review -Repo 'acme/unprotected' -Pr 65
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 65 -State (New-PrState @{
    title  = 'chore(deps): bump tsx from 4.23.1 to 4.23.4'
    body   = 'Please review when you get a chance. Requires human review of the changelog? No.'
    labels = @(@{ name = 'dependencies' }) })
  Assert-Verdict $r 'ALLOW'
}

# ---- C7 scope --------------------------------------------------------------
Check 'BLOCK when the change touches too many files' {
  Write-Review -Repo 'acme/unprotected' -Pr 70
  $many = 1..45 | ForEach-Object { @{ path = "src/f$_.ts" } }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 70 -State (New-PrState @{ files = $many })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'SCOPE_EVIDENCE_MISSING'; Assert-Reason $r 'ELEVATED_REVIEW_REQUIRED'
}
Check 'BLOCK when additions exceed the ceiling' {
  Write-Review -Repo 'acme/unprotected' -Pr 71
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 71 -State (New-PrState @{ additions = 5000 })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'SCOPE_EVIDENCE_MISSING'; Assert-Reason $r 'SECOND_REVIEW_REQUIRED'
}
Check 'BLOCK when no changed files are reported at all' {
  Write-Review -Repo 'acme/unprotected' -Pr 72
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 72 -State (New-PrState @{ files = @() })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NO_FILES_REPORTED'
}

# ---- C8 independent, SHA-pinned review ------------------------------------
Check 'BLOCK when no review artifact exists' {
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 80 -State (New-PrState)   # no Write-Review
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NO_INDEPENDENT_REVIEW'
}
Check 'BLOCK when the review approved a different SHA (new commits landed)' {
  Write-Review -Repo 'acme/unprotected' -Pr 81 -Sha $OTHER
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 81 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_STALE'
}
Check 'BLOCK when the review verdict is not APPROVE' {
  Write-Review -Repo 'acme/unprotected' -Pr 82 -Verdict 'REJECT'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 82 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_NOT_APPROVED'
}
Check 'BLOCK self-approval: reviewer identity equals the author identity' {
  Write-Review -Repo 'acme/unprotected' -Pr 83 -Reviewer 'same-pass' -AuthoredBy 'same-pass'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 83 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_NOT_INDEPENDENT'
}
Check 'BLOCK when the review records no reviewer identity' {
  Write-Review -Repo 'acme/unprotected' -Pr 84 -Reviewer ''
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 84 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_NO_REVIEWER'
}
Check 'BLOCK when the review artifact is corrupt' {
  $p = Join-Path $reviewDir 'acme__unprotected__85.json'
  Set-Content -Path $p -Value '{ not json' -Encoding utf8
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 85 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_UNREADABLE'
}

# ---- change classification ------------------------------------------------
Check 'classify a docs-only change' {
  Write-Review -Repo 'acme/unprotected' -Pr 90
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 90 -State (New-PrState @{ files = @(@{ path = 'README.md' }, @{ path = 'docs/x.md' }) })
  Assert-Equal $r.change_class 'docs' 'change_class'
}
Check 'classify a lockfile-only dependency bump' {
  Write-Review -Repo 'acme/unprotected' -Pr 91
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 91 -State (New-PrState @{ files = @(@{ path = 'package.json' }, @{ path = 'package-lock.json' }) })
  Assert-Equal $r.change_class 'deps' 'change_class'
}
Check 'classify a code change' {
  Write-Review -Repo 'acme/unprotected' -Pr 92
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 92 -State (New-PrState)
  Assert-Equal $r.change_class 'code' 'change_class'
}

# ---- multiple independent failures all surface -----------------------------
Check 'every failing criterion is reported, not just the first' {
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 99 -State (New-PrState @{
    isDraft = $true; mergeStateStatus = 'DIRTY'; mergeable = 'CONFLICTING'
    statusCheckRollup = @(); files = @(@{ path = 'infra/terraform/main.tf' }) })
  Assert-Verdict $r 'BLOCK'
  foreach ($c in @('IS_DRAFT', 'NOT_MERGEABLE', 'MERGE_STATE_NOT_CLEAN', 'NO_CI_EVIDENCE', 'ELEVATED_EVIDENCE_MISSING', 'NO_INDEPENDENT_REVIEW')) {
    Assert-Reason $r $c
  }
}

# ---- falsification regressions (2026-08-08 commissioning) ------------------
# Each of these ALLOWed before the fix. They are the reason the gate is trusted.
function Remove-Field { param([psobject]$O, [string]$Name) $O.PSObject.Properties.Remove($Name); return $O }

Check 'FALSIFY F1: absent additions must BLOCK, not default to 0 and pass scope' {
  Write-Review -Repo 'acme/unprotected' -Pr 100
  $s = Remove-Field (New-PrState @{ files = @(@{ path = 'src/a.ts' }, @{ path = 'src/b.ts' }) }) 'additions'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 100 -State $s
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'ADDITIONS_UNKNOWN'
}
Check 'FALSIFY F5: absent reviewThreads must BLOCK, not read as "no unresolved threads"' {
  Write-Review -Repo 'acme/unprotected' -Pr 101
  $s = Remove-Field (New-PrState) 'reviewThreads'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 101 -State $s
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_THREADS_UNVERIFIED'
}
Check 'FALSIFY F2a: lowercase mergeable must not satisfy MERGEABLE' {
  Write-Review -Repo 'acme/unprotected' -Pr 102
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 102 -State (New-PrState @{ mergeable = 'mergeable' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NOT_MERGEABLE'
}
Check 'FALSIFY F2b: lowercase mergeStateStatus must not satisfy CLEAN' {
  Write-Review -Repo 'acme/unprotected' -Pr 103
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 103 -State (New-PrState @{ mergeStateStatus = 'clean' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MERGE_STATE_NOT_CLEAN'
}
Check 'FALSIFY F7: lowercase review verdict must not satisfy APPROVE' {
  Write-Review -Repo 'acme/unprotected' -Pr 104 -Verdict 'approve'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 104 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_NOT_APPROVED'
}
Check 'FALSIFY: a review for a different PR number is not reused' {
  Write-Review -Repo 'acme/unprotected' -Pr 1050          # note: 1050, not 105
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 105 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NO_INDEPENDENT_REVIEW'
}
Check 'FALSIFY: absent statusCheckRollup property blocks like an empty one' {
  Write-Review -Repo 'acme/unprotected' -Pr 106
  $s = Remove-Field (New-PrState) 'statusCheckRollup'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 106 -State $s
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'NO_CI_EVIDENCE'
}
Check 'FALSIFY: legacy commit-status shape with state=PENDING blocks' {
  Write-Review -Repo 'acme/unprotected' -Pr 107
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 107 -State (New-PrState @{
    statusCheckRollup = @(@{ context = 'legacy-ci'; state = 'PENDING' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'CI_NOT_GREEN'
}
Check 'FALSIFY: reviewer differing only by case is still self-approval' {
  Write-Review -Repo 'acme/unprotected' -Pr 108 -Reviewer 'Same' -AuthoredBy 'same'
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 108 -State (New-PrState)
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'REVIEW_NOT_INDEPENDENT'
}

# ---- GOVERNANCE: evidence-based escalation (2026-08-08) ---------------------
# The whole point of the tiered model: elevated risk is mergeable autonomously,
# but ONLY on evidence. Green CI must never be sufficient by itself.

Check 'GOVERNANCE: elevated risk + green CI + ordinary review => BLOCK' {
  Write-Review -Repo 'acme/unprotected' -Pr 200 -Depth 'ordinary' -Evidence $ALL_EVIDENCE
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 200 -State (New-PrState @{ files = @(@{ path = '.github/workflows/ci.yml' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'ELEVATED_REVIEW_REQUIRED'
}
Check 'GOVERNANCE: elevated risk + elevated review but ONE evidence key missing => BLOCK' {
  $partial = $ALL_EVIDENCE.Clone(); $partial.Remove('workflow_syntax_validated')
  Write-Review -Repo 'acme/unprotected' -Pr 201 -Depth 'elevated' -Evidence $partial
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 201 -State (New-PrState @{ files = @(@{ path = '.github/workflows/ci.yml' }) })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'ELEVATED_EVIDENCE_MISSING'
}
Check 'GOVERNANCE: a CI workflow change CAN reach ALLOW with elevated review + full evidence' {
  Write-Review -Repo 'acme/unprotected' -Pr 202 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 202 -State (New-PrState @{ files = @(@{ path = '.github/workflows/ci.yml' }) })
  Assert-Verdict $r 'ALLOW'
  Assert-Equal $r.risk_tier 'elevated' 'risk_tier'
}
Check 'GOVERNANCE: elevated risk with NO patch available => BLOCK (cannot clear content checks)' {
  Write-Review -Repo 'acme/unprotected' -Pr 203 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $s = New-PrState @{ files = @(@{ path = 'infra/terraform/main.tf' }) }
  $s.PSObject.Properties.Remove('patch')
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 203 -State $s
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'PATCH_UNAVAILABLE'
}

# ---- ABSOLUTE: irreversible CONSEQUENCE, no evidence can clear it ----------
Check 'ABSOLUTE: destructive SQL in the diff is human-only even with full evidence' {
  Write-Review -Repo 'acme/unprotected' -Pr 210 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 210 -State (New-PrState @{
    files = @(@{ path = 'db/migrations/007.sql' })
    patch = "diff --git a/db/migrations/007.sql`n+DROP TABLE customers;`n" })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'HUMAN_ONLY_ACTION'
}
Check 'ABSOLUTE: removing deletion_protection is human-only even with full evidence' {
  Write-Review -Repo 'acme/unprotected' -Pr 211 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 211 -State (New-PrState @{
    files = @(@{ path = 'infra/terraform/rds.tf' })
    patch = "diff --git a/infra/terraform/rds.tf`n-  deletion_protection = true`n+  deletion_protection = false`n" })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'HUMAN_ONLY_ACTION'
}
Check 'ABSOLUTE: added credential material is human-only even with full evidence' {
  Write-Review -Repo 'acme/unprotected' -Pr 212 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 212 -State (New-PrState @{
    files = @(@{ path = 'services/.env' })
    patch = "diff --git a/services/.env`n+AWS_ACCESS_KEY_ID=AKIA1234567890ABCDEF`n" })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'HUMAN_ONLY_ACTION'
}
Check 'PROPORTIONALITY: an ordinary IaC edit (tag rename) is elevated, NOT human-only' {
  Write-Review -Repo 'acme/unprotected' -Pr 213 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 213 -State (New-PrState @{
    files = @(@{ path = 'infra/terraform/tags.tf' })
    patch = "diff --git a/infra/terraform/tags.tf`n-  Owner = `"old`"`n+  Owner = `"new`"`n" })
  Assert-Verdict $r 'ALLOW'
  Assert-Equal $r.risk_tier 'elevated' 'risk_tier'
}

# ---- MARKERS: evidence to be adjudicated, never silently stripped ----------
Check 'MARKER: adjudicated as still applicable => BLOCK' {
  Write-Review -Repo 'acme/unprotected' -Pr 220 -Depth 'elevated' -Evidence $ALL_EVIDENCE `
    -Marker @{ placed_by = 'security-routine'; reason = 'auth path unverified'; still_valid = $true; consequence_is_human_only = $false }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 220 -State (New-PrState @{ title = 'fix [REQUIRES HUMAN REVIEW]' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MARKER_STILL_VALID'
}
Check 'MARKER: adjudicated as a genuine human-only consequence => BLOCK HUMAN_ONLY_ACTION' {
  Write-Review -Repo 'acme/unprotected' -Pr 221 -Depth 'elevated' -Evidence $ALL_EVIDENCE `
    -Marker @{ placed_by = 'alex'; reason = 'rotates a live production credential'; still_valid = $false; consequence_is_human_only = $true }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 221 -State (New-PrState @{ title = 'x [REQUIRES HUMAN REVIEW]' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'HUMAN_ONLY_ACTION'
}
Check 'MARKER: superseded blanket policy + reversible consequence => ALLOW, reasoning on record' {
  Write-Review -Repo 'acme/unprotected' -Pr 222 -Depth 'elevated' -Evidence $ALL_EVIDENCE `
    -Marker @{ placed_by = 'CLAUDE.base.md s7 blanket policy'; reason = 'generic marker for any security-labelled change'
               still_valid = $false; superseded_by = 'operator authority 2026-08-08'; consequence_is_human_only = $false }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 222 -State (New-PrState @{ title = 'fix(security): x [REQUIRES HUMAN REVIEW]' })
  Assert-Verdict $r 'ALLOW'
}
Check 'MARKER: adjudication without placed_by/reason is incomplete => BLOCK' {
  Write-Review -Repo 'acme/unprotected' -Pr 223 -Depth 'elevated' -Evidence $ALL_EVIDENCE `
    -Marker @{ still_valid = $false; consequence_is_human_only = $false }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 223 -State (New-PrState @{ title = 'x [DO NOT MERGE]' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'MARKER_ADJUDICATION_INCOMPLETE'
}
Check 'MARKER: unknown still_valid defaults to still-applicable (fail closed)' {
  Write-Review -Repo 'acme/unprotected' -Pr 224 -Depth 'elevated' -Evidence $ALL_EVIDENCE `
    -Marker @{ placed_by = 'x'; reason = 'y' }   # both flags omitted
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 224 -State (New-PrState @{ title = 'x [REQUIRES HUMAN REVIEW]' })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'HUMAN_ONLY_ACTION'
}

# ---- SCOPE: proportionate evidence, not a hard ceiling --------------------
Check 'SCOPE: a large generated batch reaches ALLOW with full diff review + second pass' {
  Write-Review -Repo 'acme/unprotected' -Pr 230 -Depth 'elevated' -Evidence $ALL_EVIDENCE
  $many = 1..42 | ForEach-Object { @{ path = "routines/prompts/r$_/SKILL.md" } }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 230 -State (New-PrState @{ files = $many; additions = 2200 })
  Assert-Verdict $r 'ALLOW'
  Assert-Equal $r.scope_elevated $true 'scope_elevated'
}
Check 'SCOPE: >3x ceiling without second_review_pass => BLOCK' {
  $noSecond = $ALL_EVIDENCE.Clone(); $noSecond.Remove('second_review_pass')
  Write-Review -Repo 'acme/unprotected' -Pr 231 -Depth 'elevated' -Evidence $noSecond
  $many = 1..130 | ForEach-Object { @{ path = "src/f$_.ts" } }
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 231 -State (New-PrState @{ files = $many; additions = 3000 })
  Assert-Verdict $r 'BLOCK'; Assert-Reason $r 'SECOND_REVIEW_REQUIRED'
}
Check 'SCOPE: an ordinary small change needs no elevated review at all' {
  Write-Review -Repo 'acme/unprotected' -Pr 232
  $r = Invoke-Gate -Repo 'acme/unprotected' -Pr 232 -State (New-PrState)
  Assert-Verdict $r 'ALLOW'
  Assert-Equal $r.risk_tier 'ordinary' 'risk_tier'
}

Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  $pass passed, $fail failed" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 } else { exit 0 }
