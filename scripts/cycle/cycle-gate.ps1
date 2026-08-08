<#
.SYNOPSIS
  Decides whether ONE pull request may be merged autonomously. Fail-closed.

.DESCRIPTION
  This is the safety core of the autonomous cycle runner. It maps the operator's
  seven stated merge criteria onto mechanical checks and returns ALLOW or BLOCK
  with reasons. It NEVER merges — cycle-merge.ps1 does that, and only when this
  script has already returned ALLOW for the CURRENT head SHA.

  Design rules, in priority order:

  1. FAIL CLOSED. Every unknown, missing, or unparseable input is a BLOCK, never
     an ALLOW. There is no "probably fine" branch.
  2. ABSENT CI IS NOT GREEN. `mergeStateStatus: CLEAN` on a repo with zero
     checks means "nothing failed because nothing ran". Treating that as green is
     the single most dangerous mistake this script could make — orryx-standards
     has no workflows at all, so 3 of its PRs report CLEAN with no evidence
     whatsoever. Zero checks => BLOCK (NO_CI_EVIDENCE) unless the operator
     passes -AllowNoCI, which is deliberately not the default and is recorded in
     the verdict so it shows up in evidence.
  3. REVIEW IS SHA-PINNED. An independent review approves a specific tree, not a
     PR number. If new commits land after the review, the review is stale and the
     gate blocks. This is why reviewed_sha is compared, not just presence.
  4. SELF-APPROVAL IS NOT REVIEW. If the review artifact's reviewer identity
     equals its authored_by identity, it is not independent and is rejected.
  5. DECLARED PROTECTION IS ENFORCED BY NAME. branch-protection.json lists the
     exact required contexts. Context names must match byte-for-byte (requiring
     a workflow *name* where GitHub reports a *job id* deadlocks every PR — a
     trap already recorded in that file). We assert the declared contexts are
     present AND successful, rather than trusting mergeStateStatus alone.

  Testability: pass -InputObject to inject a PR state object and skip all network
  access. Test-CycleGate.ps1 relies on this; every rule above has a test.

.PARAMETER Repo
  owner/name, e.g. alexmclaren/orryx-core.

.PARAMETER Pr
  PR number.

.PARAMETER InputObject
  Pre-fetched PR state (same shape cycle-state.ps1 emits). When supplied, no gh
  calls are made. Used by tests and by the runner to avoid re-fetching.

.PARAMETER AllowNoCI
  Permit a repo with zero status checks to pass criterion C3. Off by default.
  Recorded in the verdict when used.

.PARAMETER MaxFiles
  Files-changed ceiling before the change is treated as scope-expanding. Default 40.

.PARAMETER MaxAdditions
  Added-lines ceiling before the change is treated as scope-expanding. Default 800.

.PARAMETER StateRoot
  Root for cycle state (reviews, evidence). Default D:\state\cycles.

.PARAMETER ProtectionFile
  Declared branch-protection state. Default D:\state\branch-protection.json.

.OUTPUTS
  A verdict object (also emitted as JSON with -AsJson).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [Parameter(Mandatory = $true)][int]$Pr,
  [psobject]$InputObject,
  [switch]$AllowNoCI,
  [int]$MaxFiles = 40,
  [int]$MaxAdditions = 800,
  [string]$StateRoot = 'D:\state\cycles',
  [string]$ProtectionFile = 'D:\state\branch-protection.json',
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- risk classification -----------------------------------------------------
# Paths that cross a human-only boundary. Matched case-insensitively against
# every changed file path. Deliberately broad: a false BLOCK costs one human
# glance, a false ALLOW can cost production.
$script:HumanOnlyPatterns = [ordered]@{
  migration      = '(^|/)(migrations?|alembic)/|\.sql$|schema\.prisma$'
  secret         = '(^|/)\.env|(^|/)secrets?/|\.pem$|\.key$|(^|/)credentials|id_rsa'
  money_or_legal = 'pricing|billing|stripe|payment|invoice|subscription|(^|/)legal/|terms-of|privacy-policy'
  infrastructure = '(^|/)terraform/|\.tf$|(^|/)k8s/|kustomiz|(^|/)helm/|Dockerfile|docker-compose'
  ci_or_policy   = '(^|/)\.github/workflows/|(^|/)\.pre-commit|gitleaks|(^|/)\.claude/settings'
  prod_config    = 'configmap|(^|/)production|prod\.(ya?ml|json|tfvars)$'
  privacy_phi    = '(^|/)phi/|patient|clinical.*(record|data)|deident'
}

function Get-ChangeClass {
  param([string[]]$Paths)
  if (-not $Paths -or $Paths.Count -eq 0) { return 'unknown' }
  $isDoc  = $true; $isDep = $true
  foreach ($p in $Paths) {
    if ($p -notmatch '\.(md|txt|rst|adoc)$') { $isDoc = $false }
    if ($p -notmatch '(package(-lock)?\.json|yarn\.lock|pnpm-lock\.yaml|requirements.*\.txt|poetry\.lock|go\.(mod|sum)|Cargo\.(toml|lock))$') { $isDep = $false }
  }
  if ($isDoc) { return 'docs' }
  if ($isDep) { return 'deps' }
  return 'code'
}

function Get-RiskFlags {
  param([string[]]$Paths)
  $flags = @()
  foreach ($name in $script:HumanOnlyPatterns.Keys) {
    $rx = $script:HumanOnlyPatterns[$name]
    $hit = @($Paths | Where-Object { $_ -match $rx })
    if ($hit.Count -gt 0) {
      $flags += [pscustomobject]@{ flag = $name; paths = @($hit | Select-Object -First 5) }
    }
  }
  return $flags
}

# --- input -------------------------------------------------------------------
# NOTE: this local is deliberately NOT called $pr. PowerShell variable names are
# case-insensitive, so `$pr` IS the `[int]$Pr` parameter, and a parameter's type
# constraint persists for the variable's lifetime — assigning the state object to
# it throws "Cannot convert ... to Int32". Caught by Test-CycleGate.ps1.
# True unless the live path cannot establish review-thread state, in which case we
# fail closed rather than assume "no unresolved threads".
$threadsVerified = $true

if ($InputObject) {
  $prState = $InputObject
} else {
  $env:GH_PAGER = ''
  # NOTE: reviewThreads is NOT a valid `gh pr view --json` field on gh 2.30.0
  # (the installed version) — including it makes the whole call fail with
  # "Unknown JSON field". Thread state is fetched separately via GraphQL below.
  $fields = 'number,isDraft,mergeable,mergeStateStatus,headRefOid,reviewDecision,files,additions,deletions,statusCheckRollup,baseRefName,title,url,body,labels'
  $raw = & gh pr view $Pr --repo $Repo --json $fields 2>&1
  if ($LASTEXITCODE -ne 0) {
    $v = [pscustomobject]@{
      repo = $Repo; pr = $Pr; verdict = 'BLOCK'; head_sha = $null
      reasons = @([pscustomobject]@{ code = 'PR_FETCH_FAILED'; detail = ($raw | Out-String).Trim() })
      change_class = 'unknown'; risk_flags = @(); evaluated_utc = (Get-Date).ToUniversalTime().ToString('o')
    }
    if ($AsJson) { return ($v | ConvertTo-Json -Depth 8) } else { return $v }
  }
  $prState = $raw | ConvertFrom-Json

  # Unresolved review threads (operator criterion 5). GraphQL is the only source
  # for this on gh 2.30.0. If it cannot be determined, block — an unverified
  # thread state is exactly the ambiguity this gate exists to refuse.
  $parts = $Repo.Split('/')
  # Build the arg strings first. `-F o=$parts[0]` does NOT index inside a bare
  # argument — PowerShell passes the array then a literal "[0]", the call fails,
  # and every PR silently reports REVIEW_THREADS_UNVERIFIED (i.e. never mergeable).
  $argOwner = "o=$($parts[0])"
  $argName  = "n=$($parts[1])"
  $argPr    = "p=$Pr"
  $gq = 'query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){reviewThreads(first:100){nodes{isResolved}}}}}'
  $tRaw = & gh api graphql -f query=$gq -f $argOwner -f $argName -F $argPr 2>&1
  if ($LASTEXITCODE -eq 0) {
    try {
      $nodes = @(($tRaw | ConvertFrom-Json).data.repository.pullRequest.reviewThreads.nodes)
      $prState | Add-Member -NotePropertyName reviewThreads -NotePropertyValue $nodes -Force
    } catch { $threadsVerified = $false }
  } else {
    $threadsVerified = $false
  }
}

# Safe property read. Handles BOTH shapes we get in practice:
#   - PSCustomObject, from `gh ... --json | ConvertFrom-Json` (the production path)
#   - IDictionary/hashtable, from callers that build state literally (tests, runner)
# PSObject.Properties does NOT expose hashtable keys, so a dictionary-blind version
# silently returned the default for every field of an injected hashtable — which
# read as "no files changed, no checks ran" and would have disabled the risk scan.
# Returns $default when absent or null so StrictMode access is always safe.
function Prop { param($o, [string]$n, $default = $null)
  if ($null -eq $o) { return $default }
  if ($o -is [System.Collections.IDictionary]) {
    if ($o.Contains($n) -and $null -ne $o[$n]) { return $o[$n] } else { return $default }
  }
  if ($o.PSObject.Properties.Name -contains $n -and $null -ne $o.$n) { return $o.$n }
  return $default
}

$headSha    = Prop $prState 'headRefOid'
$files      = @(Prop $prState 'files' @())
$paths      = @($files | ForEach-Object { Prop $_ 'path' } | Where-Object { $_ })
$rollup     = @(Prop $prState 'statusCheckRollup' @())
$threads    = @(Prop $prState 'reviewThreads' @())
$additions  = [int](Prop $prState 'additions' 0)
$isDraft    = [bool](Prop $prState 'isDraft' $true)          # unknown => treat as draft (fail closed)
$mergeable  = [string](Prop $prState 'mergeable' 'UNKNOWN')
$mergeState = [string](Prop $prState 'mergeStateStatus' 'UNKNOWN')
$reviewDec  = [string](Prop $prState 'reviewDecision' '')

$reasons = New-Object System.Collections.Generic.List[object]
function Deny { param([string]$Code, [string]$Detail) $reasons.Add([pscustomobject]@{ code = $Code; detail = $Detail }) }

$changeClass = Get-ChangeClass -Paths $paths
$riskFlags   = Get-RiskFlags  -Paths $paths

# --- C1  draft ---------------------------------------------------------------
if ($isDraft) { Deny 'IS_DRAFT' 'PR is a draft; drafts are never auto-merged.' }

# --- C2  mergeable / no conflicts -------------------------------------------
if ($mergeable -ne 'MERGEABLE') { Deny 'NOT_MERGEABLE' "mergeable=$mergeable (need MERGEABLE)." }
if ($mergeState -ne 'CLEAN') {
  # BEHIND is recoverable by an update; DIRTY needs conflict resolution; UNSTABLE
  # means a check is failing; UNKNOWN means GitHub has not finished computing.
  Deny 'MERGE_STATE_NOT_CLEAN' "mergeStateStatus=$mergeState (need CLEAN)."
}

# --- C3  CI evidence exists AND is green ------------------------------------
$checkSummary = @()
if ($rollup.Count -eq 0) {
  if ($AllowNoCI) {
    $checkSummary += 'NO_CHECKS(allowed by -AllowNoCI)'
  } else {
    Deny 'NO_CI_EVIDENCE' 'Zero status checks reported. Absent CI is not a pass; re-run with -AllowNoCI only if the repo genuinely has no CI and the operator accepts that.'
  }
} else {
  foreach ($c in $rollup) {
    $name  = if (Prop $c 'name') { Prop $c 'name' } else { Prop $c 'context' 'unnamed' }
    $concl = if (Prop $c 'conclusion') { Prop $c 'conclusion' } else { Prop $c 'state' 'UNKNOWN' }
    $status = [string](Prop $c 'status' '')
    $checkSummary += "$name=$concl"
    if ($status -and $status -notin @('COMPLETED')) {
      Deny 'CI_INCOMPLETE' "check '$name' status=$status (still running); re-evaluate when complete."
      continue
    }
    if ([string]$concl -notin @('SUCCESS', 'NEUTRAL', 'SKIPPED')) {
      Deny 'CI_NOT_GREEN' "check '$name' conclusion=$concl."
    }
  }
}

# --- C4  declared branch protection satisfied by NAME -----------------------
$declared = $null
if (Test-Path $ProtectionFile) {
  try {
    $prot = Get-Content $ProtectionFile -Raw | ConvertFrom-Json
    if ($prot.repos.PSObject.Properties.Name -contains $Repo) { $declared = $prot.repos.$Repo }
  } catch { Deny 'PROTECTION_FILE_UNREADABLE' "Could not parse $ProtectionFile : $($_.Exception.Message)" }
} else {
  Deny 'PROTECTION_FILE_MISSING' "$ProtectionFile not found; cannot confirm criterion 4 (repository rules permit the merge)."
}

if ($declared -and (Prop $declared 'expected')) {
  $expected = $declared.expected
  $wantBranch = [string](Prop $declared 'branch' '')
  $baseRef    = [string](Prop $prState 'baseRefName' '')
  if ($wantBranch -and $baseRef -and $wantBranch -ne $baseRef) {
    # Protection is declared for a different branch than this PR targets; we have
    # no declaration covering the actual base, so we cannot clear C4.
    Deny 'PROTECTION_UNDECLARED_FOR_BASE' "branch-protection.json declares '$wantBranch' but PR targets '$baseRef'."
  }
  $wantCtx = @(Prop $expected 'contexts' @())
  foreach ($ctx in $wantCtx) {
    $match = $rollup | Where-Object {
      $n = if (Prop $_ 'name') { Prop $_ 'name' } else { Prop $_ 'context' '' }
      $n -ceq $ctx                                    # byte-exact, case-sensitive
    }
    if (-not $match) {
      Deny 'REQUIRED_CONTEXT_MISSING' "declared required context '$ctx' did not report on this PR."
    } else {
      $mc = @($match)[0]
      $concl = if (Prop $mc 'conclusion') { Prop $mc 'conclusion' } else { Prop $mc 'state' 'UNKNOWN' }
      if ([string]$concl -notin @('SUCCESS', 'NEUTRAL', 'SKIPPED')) {
        Deny 'REQUIRED_CONTEXT_NOT_GREEN' "declared required context '$ctx' conclusion=$concl."
      }
    }
  }
}

# --- C5  no blocking review state / unresolved threads ----------------------
if ($reviewDec -eq 'CHANGES_REQUESTED') { Deny 'CHANGES_REQUESTED' 'A reviewer requested changes.' }
if (-not $threadsVerified) {
  Deny 'REVIEW_THREADS_UNVERIFIED' 'Could not determine review-thread resolution state (GraphQL query failed); refusing to assume there are none.'
} else {
  $unresolved = @($threads | Where-Object { -not [bool](Prop $_ 'isResolved' $false) })
  if ($unresolved.Count -gt 0) { Deny 'UNRESOLVED_REVIEW_THREADS' "$($unresolved.Count) unresolved review thread(s)." }
}

# --- C6  human-only risk surface -------------------------------------------
foreach ($f in $riskFlags) {
  Deny 'HUMAN_ONLY_SURFACE' "$($f.flag): $($f.paths -join ', ')"
}

# --- C6b  explicit [REQUIRES HUMAN REVIEW] marker ---------------------------
# CLAUDE.base.md §7 defines this tag as THE way an author or routine marks a
# change as human-gated: clinical logic, patient matching, compliance
# interpretation, privacy decisions, production data, low-confidence output.
# Found by running the gate live on 2026-08-08: orryx-flow #49
# ("fix(security): reject non-access JWTs as bearer credentials
# [REQUIRES HUMAN REVIEW]") passed every path-based check and was ALLOWed,
# because the marker lives in the title/body/labels, not in a file path. A
# path-only risk scan cannot see an author's explicit escalation.
$declaredHuman = @()
$prTitleRaw = [string](Prop $prState 'title' '')
$prBodyRaw  = [string](Prop $prState 'body'  '')
$labelNames = @(@(Prop $prState 'labels' @()) | ForEach-Object { [string](Prop $_ 'name' '') })
if ($prTitleRaw -match '(?i)\[\s*REQUIRES\s+HUMAN\s+REVIEW\s*\]') { $declaredHuman += 'title' }
if ($prBodyRaw  -match '(?i)\[\s*REQUIRES\s+HUMAN\s+REVIEW\s*\]') { $declaredHuman += 'body' }
foreach ($ln in $labelNames) {
  if ($ln -match '(?i)requires[- ]?human[- ]?review|do[- ]not[- ]merge|human[- ]gated') { $declaredHuman += "label:$ln" }
}
if ($prTitleRaw -match '(?i)\bDO\s+NOT\s+MERGE\b' -or $prBodyRaw -match '(?i)\bDO\s+NOT\s+MERGE\b') {
  $declaredHuman += 'do-not-merge'
}
if ($declaredHuman.Count -gt 0) {
  Deny 'REQUIRES_HUMAN_REVIEW_TAG' "the change is explicitly marked human-gated in: $($declaredHuman -join ', ')"
}

# --- C7  scope sanity -------------------------------------------------------
if ($files.Count -gt $MaxFiles)     { Deny 'SCOPE_TOO_MANY_FILES' "$($files.Count) files changed (ceiling $MaxFiles)." }
if ($additions -gt $MaxAdditions)   { Deny 'SCOPE_TOO_MANY_ADDITIONS' "$additions additions (ceiling $MaxAdditions)." }
if ($files.Count -eq 0)             { Deny 'NO_FILES_REPORTED' 'No changed files reported; cannot assess scope or risk.' }

# --- C8  independent, SHA-pinned review ------------------------------------
$reviewDir  = Join-Path $StateRoot 'reviews'
$slug       = ($Repo -replace '/', '__')
$reviewPath = Join-Path $reviewDir "$slug`__$Pr.json"
$review     = $null
if (-not (Test-Path $reviewPath)) {
  Deny 'NO_INDEPENDENT_REVIEW' "No review artifact at $reviewPath. An independent review pass must approve this head SHA before merge."
} else {
  try { $review = Get-Content $reviewPath -Raw | ConvertFrom-Json }
  catch { Deny 'REVIEW_UNREADABLE' "Could not parse $reviewPath : $($_.Exception.Message)" }
}
if ($review) {
  $rSha      = [string](Prop $review 'reviewed_sha' '')
  $rVerdict  = [string](Prop $review 'verdict' '')
  $reviewer  = [string](Prop $review 'reviewer' '')
  $authoredBy= [string](Prop $review 'authored_by' '')
  if (-not $headSha)                { Deny 'HEAD_SHA_UNKNOWN' 'Cannot confirm the review matches the current tree.' }
  elseif ($rSha -ne $headSha)       { Deny 'REVIEW_STALE' "review approved $rSha but PR head is $headSha; new commits invalidate the review." }
  if ($rVerdict -ne 'APPROVE')      { Deny 'REVIEW_NOT_APPROVED' "review verdict=$rVerdict (need APPROVE)." }
  if (-not $reviewer)               { Deny 'REVIEW_NO_REVIEWER' 'review artifact does not record a reviewer identity.' }
  if ($reviewer -and $authoredBy -and $reviewer -eq $authoredBy) {
    Deny 'REVIEW_NOT_INDEPENDENT' "reviewer '$reviewer' is the same identity that authored the change."
  }
}

# --- verdict ---------------------------------------------------------------
$verdict = if ($reasons.Count -eq 0) { 'ALLOW' } else { 'BLOCK' }

# Build every field into a local first. Composing this object from inline
# pipelines and function calls made a type error report a line number inside the
# literal with no indication of which field caused it — expensive to debug for no
# benefit.
$riskFlagNames = @()
if ($null -ne $riskFlags) { foreach ($rf in $riskFlags) { $riskFlagNames += [string]$rf.flag } }
$reasonList = @()
if ($reasons.Count -gt 0) { $reasonList = $reasons.ToArray() }
$prUrl   = [string](Prop $prState 'url' '')
$prTitle = [string](Prop $prState 'title' '')

$out = [pscustomobject]@{
  repo            = [string]$Repo
  pr              = [int]$Pr
  url             = $prUrl
  title           = $prTitle
  verdict         = [string]$verdict
  head_sha        = [string]$headSha
  change_class    = [string]$changeClass
  files_changed   = [int]$files.Count
  additions       = [int]$additions
  risk_flags      = $riskFlagNames
  checks          = @($checkSummary)
  allow_no_ci     = [bool]$AllowNoCI
  reasons         = $reasonList
  evaluated_utc   = (Get-Date).ToUniversalTime().ToString('o')
}

if ($AsJson) { $out | ConvertTo-Json -Depth 8 } else { $out }
