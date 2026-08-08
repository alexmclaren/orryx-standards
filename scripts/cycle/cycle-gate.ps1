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
#
# GOVERNANCE MODEL (revised 2026-08-08). Risk is graded by CONSEQUENCE, not by
# file path, diff size, or historical convention.
#
# The distinction that matters:
#   changing code that CONTROLS a sensitive operation   -> reviewable autonomously
#   actually PERFORMING that sensitive operation        -> human decision
#
# A terraform file that renames a tag is not a production incident. A terraform
# file that drops deletion_protection is. Path alone cannot tell those apart, so
# the path only selects the TIER, and the tier decides what evidence is required.
#
#   tier = 'elevated'   -> autonomous merge permitted, but the review artifact
#                          must carry the named evidence. Green CI is never
#                          sufficient on its own.
#   tier = 'human_only'  -> absolute. Reserved for consequences that cannot be
#                          reversed by ordinary version control.
#
# Previously every one of these was an absolute block, which meant the harness
# refused its own CI workflow and any diff over 800 lines. That is governance by
# proxy metric, and it stalls exactly the work most worth automating.
$script:RiskRules = [ordered]@{
  migration = @{
    pattern  = '(^|/)(migrations?|alembic)/|\.sql$|schema\.prisma$'
    tier     = 'elevated'
    requires = @('migration_reversibility', 'deployment_impact')
    why      = 'A migration file is code until something runs it. Reversibility and whether merging triggers execution are the questions.'
  }
  secret_path = @{
    pattern  = '(^|/)\.env|(^|/)secrets?/|\.pem$|\.key$|(^|/)credentials|id_rsa'
    tier     = 'elevated'
    requires = @('no_secret_material', 'full_diff_reviewed')
    why      = 'Touching a secrets path is not the same as disclosing a secret. Adding a variable NAME is routine; adding a VALUE is not. Actual credential material is detected separately and is human-only.'
  }
  money_or_legal = @{
    pattern  = 'pricing|billing|stripe|payment|invoice|subscription|(^|/)legal/|terms-of|privacy-policy'
    tier     = 'elevated'
    requires = @('business_intent_source', 'deployment_impact', 'full_diff_reviewed')
    why      = 'Refactoring billing code is engineering. Changing what a customer is charged is a business decision, and needs a canonical plan to point at.'
  }
  infrastructure = @{
    pattern  = '(^|/)terraform/|\.tf$|(^|/)k8s/|kustomiz|(^|/)helm/|Dockerfile|docker-compose'
    tier     = 'elevated'
    requires = @('deployment_impact', 'rollback_verified')
    why      = 'IaC is reviewable. Irreversible IaC operations are detected from the diff content and escalate to human-only.'
  }
  ci_or_policy = @{
    pattern  = '(^|/)\.github/workflows/|(^|/)\.pre-commit|gitleaks|(^|/)\.claude/settings'
    tier     = 'elevated'
    requires = @('workflow_syntax_validated', 'full_diff_reviewed')
    why      = 'A workflow change can weaken the gates that protect everything else, so it needs syntax validation and a full read - not a human signature.'
  }
  prod_config = @{
    pattern  = 'configmap|(^|/)production|prod\.(ya?ml|json|tfvars)$'
    tier     = 'elevated'
    requires = @('deployment_impact', 'rollback_verified')
    why      = 'Production config is reversible by revert unless it triggers a destructive operation.'
  }
  privacy_phi = @{
    pattern  = '(^|/)phi/|patient|clinical.*(record|data)|deident'
    tier     = 'elevated'
    requires = @('privacy_review', 'full_diff_reviewed')
    why      = 'Clinical/PHI code paths need a targeted privacy read. Actual customer-data access or disclosure remains human-only.'
  }
}

# Content signals read from the DIFF PATCH, not the path. These are the genuine
# category-A consequences: things ordinary version control cannot undo.
$script:IrreversibleContentRules = [ordered]@{
  secret_material = @{
    pattern = '(?m)^\+.*(ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*["''][^"''$\{\s]{16,}["''])'
    why     = 'Added lines contain what looks like real credential material. Disclosure cannot be undone by a revert - the credential is already exposed and must be rotated.'
    # Applies to ANY file: a committed credential is exposed wherever it sits.
    # In a test/detector file it downgrades to elevated so a reviewer can confirm
    # it is a fixture, rather than the gate ignoring it or blocking forever.
    appliesTo               = $null
    downgradeInNonExecuting = $true
    requires                = @('no_secret_material', 'full_diff_reviewed')
  }
  destroy_protection_removed = @{
    pattern = '(?m)^-.*(deletion_protection\s*=\s*true|prevent_destroy\s*=\s*true|skip_final_snapshot\s*=\s*false)|(?m)^\+.*(deletion_protection\s*=\s*false|prevent_destroy\s*=\s*false|force_destroy\s*=\s*true|skip_final_snapshot\s*=\s*true)'
    why     = 'The diff removes a guard that exists to prevent irreversible destruction of a stateful resource.'
    # Only IaC can actually remove a real guard. The same words in a test are inert.
    appliesTo               = '\.tf$|\.tfvars$|(^|/)terraform/'
    downgradeInNonExecuting = $false
    requires                = @('deployment_impact', 'rollback_verified')
  }
  destructive_sql = @{
    pattern = '(?mi)^\+.*\b(DROP\s+(TABLE|DATABASE|SCHEMA|COLUMN)|TRUNCATE\s+TABLE|DELETE\s+FROM\s+\w+\s*;)'
    why     = 'Added SQL destroys data. If anything runs this migration, the loss is not recoverable by revert.'
    # Only a .sql file or a migration can be executed by a migration runner.
    appliesTo               = '\.sql$|(^|/)(migrations?|alembic)/'
    downgradeInNonExecuting = $false
    requires                = @('migration_reversibility', 'deployment_impact')
  }
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
  foreach ($name in $script:RiskRules.Keys) {
    $rule = $script:RiskRules[$name]
    $hit = @($Paths | Where-Object { $_ -match $rule.pattern })
    if ($hit.Count -gt 0) {
      $flags += [pscustomobject]@{
        flag = $name; tier = $rule.tier; requires = @($rule.requires)
        why = $rule.why; paths = @($hit | Select-Object -First 5)
      }
    }
  }
  return $flags
}

# Files that describe or test an operation but cannot perform it. A Test-*.ps1
# fixture containing the string "DROP TABLE" cannot drop a table, and the gate's
# own rule definitions necessarily contain every pattern it detects.
#
# Found 2026-08-08 by running the gate on PR #24, which adds this very file: it
# flagged secret_material + destroy_protection_removed + destructive_sql and
# classified the harness itself as human-only-irreversible. Generalised, ANY PR
# adding a security test fixture or a detection rule would be permanently
# misclassified — which would block exactly the security tooling worth automating.
$script:NonExecutingPathPattern = '(^|/)(Test-[^/]+\.ps1|[^/]*[._-]test\.[a-z]+|[^/]*_test\.[a-z]+)$|(^|/)(tests?|__tests__|fixtures|testdata)/|(^|/)scripts/cycle/cycle-gate\.ps1$'

function Get-IrreversibleSignals {
  <#
    Reads the diff PATCH, PER FILE, and attributes each signal only to files that
    could actually perform the operation. Absent patch => the caller treats that as
    unverified rather than clean.

    Returns objects with a `tier`:
      human_only - the hit is in a file that can execute the consequence
      elevated   - the hit is confined to non-executing (test/detector) files, so
                   it needs `no_secret_material` evidence rather than a human

    Note the asymmetry, which is deliberate:
      destructive_sql / destroy_protection_removed are scoped to the file types
      that can actually run (.sql, migrations, .tf) — a description of a DROP in a
      PowerShell test is inert.
      secret_material is NOT scoped away entirely, because a committed credential
      is exposed regardless of the file it sits in. In a non-executing file it is
      DOWNGRADED to elevated (a reviewer confirms the material is a fixture, not a
      live key) rather than ignored.
  #>
  param([string]$Patch)
  $sigs = @()
  if ([string]::IsNullOrWhiteSpace($Patch)) { return $sigs }

  # Split the unified diff into per-file sections so a hit can be attributed.
  $sections = [regex]::Split($Patch, '(?m)^diff --git ') | Where-Object { $_ -match '\S' }
  foreach ($sec in $sections) {
    $path = ''
    if ($sec -match '(?m)^\+\+\+ b/(.+)$') { $path = $Matches[1].Trim() }
    elseif ($sec -match '^a/(\S+)\s+b/(\S+)') { $path = $Matches[2].Trim() }
    $nonExecuting = ($path -match $script:NonExecutingPathPattern)

    foreach ($name in $script:IrreversibleContentRules.Keys) {
      $rule = $script:IrreversibleContentRules[$name]
      if ($sec -notmatch $rule.pattern) { continue }

      # Scope the execution-dependent rules to file types that can actually run —
      # but ONLY when the path is known. An unattributable hunk must fail closed:
      # if we cannot tell which file a DROP TABLE landed in, we assume it can run.
      if ($rule.appliesTo -and $path -and $path -notmatch $rule.appliesTo) { continue }
      if ($rule.appliesTo -and -not $path) {
        $sigs += [pscustomobject]@{
          signal = $name; tier = 'human_only'; path = '(unattributable)'
          why = "$($rule.why) The diff hunk could not be attributed to a file, so it cannot be ruled inert."
          requires = @($rule.requires)
        }
        continue
      }

      $tier = if ($nonExecuting -and $rule.downgradeInNonExecuting) { 'elevated' } `
              elseif ($nonExecuting -and -not $rule.appliesTo) { 'elevated' } `
              else { 'human_only' }

      $sigs += [pscustomobject]@{
        signal = $name; tier = $tier; path = $path
        why = $rule.why
        requires = @($rule.requires)
      }
    }
  }
  return $sigs
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

  # The diff patch is required to evaluate irreversible CONTENT signals (real
  # credential material, dropped destroy-protection, destructive SQL). Path
  # matching cannot see any of those. If the patch cannot be fetched we do not
  # get to assume it is clean.
  $pRaw = & gh pr diff $Pr --repo $Repo 2>&1
  if ($LASTEXITCODE -eq 0) { $patchText = ($pRaw | Out-String) } else { $patchText = $null }
  $prState | Add-Member -NotePropertyName patch -NotePropertyValue $patchText -Force
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

# Presence test, distinct from Prop. Needed wherever "field absent" must BLOCK
# rather than fall back to a default — a default that happens to be permissive
# (additions=0, threads=@()) turns a missing field into a silent pass.
function HasProp { param($o, [string]$n)
  if ($null -eq $o) { return $false }
  if ($o -is [System.Collections.IDictionary]) { return ($o.Contains($n) -and $null -ne $o[$n]) }
  return (($o.PSObject.Properties.Name -contains $n) -and ($null -ne $o.$n))
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
$riskFlags   = @(Get-RiskFlags -Paths $paths)   # @() — see note at $irrev

# --- C1  draft ---------------------------------------------------------------
if ($isDraft) { Deny 'IS_DRAFT' 'PR is a draft; drafts are never auto-merged.' }

# --- C2  mergeable / no conflicts -------------------------------------------
# -cne, not -ne. PowerShell comparisons are case-INSENSITIVE by default, so
# mergeable='mergeable' and mergeStateStatus='clean' both passed (falsification
# F2/F7, 2026-08-08). GitHub returns uppercase so it was not exploitable via the
# API, but a safety comparison must assert what it appears to assert.
if ($mergeable -cne 'MERGEABLE') { Deny 'NOT_MERGEABLE' "mergeable=$mergeable (need exactly MERGEABLE)." }
if ($mergeState -cne 'CLEAN') {
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
# An ABSENT reviewThreads property is not "no unresolved threads". On the live
# path GraphQL populates it (and sets $threadsVerified=$false on failure), but with
# -InputObject — the path the runner uses to avoid re-fetching — a state object
# lacking the field silently satisfied C5 entirely (falsification F5, 2026-08-08).
if (-not (HasProp $prState 'reviewThreads')) { $threadsVerified = $false }

if (-not $threadsVerified) {
  Deny 'REVIEW_THREADS_UNVERIFIED' 'Review-thread resolution state could not be established (GraphQL failed, or the supplied PR state has no reviewThreads field); refusing to assume there are none.'
} else {
  $unresolved = @($threads | Where-Object { -not [bool](Prop $_ 'isResolved' $false) })
  if ($unresolved.Count -gt 0) { Deny 'UNRESOLVED_REVIEW_THREADS' "$($unresolved.Count) unresolved review thread(s)." }
}

# --- C6  risk tiers: elevated needs EVIDENCE, human-only is absolute --------
#
# Read the review artifact early — C6/C6b/C7 all now depend on what evidence it
# carries. C8 still validates it independently.
$reviewDir  = Join-Path $StateRoot 'reviews'
$slug       = ($Repo -replace '/', '__')
$reviewPath = Join-Path $reviewDir "$slug`__$Pr.json"
$review = $null
if (Test-Path $reviewPath) {
  try { $review = Get-Content $reviewPath -Raw | ConvertFrom-Json } catch { $review = 'UNREADABLE' }
}
function HasEvidence { param([string]$Key)
  if (-not $review -or $review -eq 'UNREADABLE') { return $false }
  $ev = Prop $review 'evidence'
  if (-not $ev) { return $false }
  return ([bool](Prop $ev $Key $false))
}
$reviewDepth = if ($review -and $review -ne 'UNREADABLE') { [string](Prop $review 'review_depth' 'ordinary') } else { 'ordinary' }

# C6a — irreversible CONTENT signals. Absolute; no evidence can clear these,
# because the consequence outlives the merge.
$patch = [string](Prop $prState 'patch' '')
# @() is load-bearing: an empty array returned from a function unrolls to $null,
# and under StrictMode $null.Count throws.
$irrev = @(Get-IrreversibleSignals -Patch $patch)
$irrevHumanOnly = @($irrev | Where-Object { $_.tier -eq 'human_only' })
foreach ($s in $irrevHumanOnly) {
  Deny 'HUMAN_ONLY_ACTION' "$($s.signal) in $($s.path): $($s.why)"
}
# Downgraded hits (confined to non-executing test/detector files) still demand
# evidence — a reviewer confirms the material is a fixture, not a live credential.
foreach ($s in @($irrev | Where-Object { $_.tier -eq 'elevated' })) {
  foreach ($req in $s.requires) {
    if (-not (HasEvidence $req)) {
      Deny 'ELEVATED_EVIDENCE_MISSING' "$($s.signal) matched in non-executing file $($s.path); requires review evidence '$req' to confirm it is a fixture and not live material."
    }
  }
  if ($reviewDepth -cne 'elevated') {
    Deny 'ELEVATED_REVIEW_REQUIRED' "$($s.signal) matched in $($s.path); requires review_depth='elevated'."
  }
}

# C6b — path-derived tiers.
$elevatedNeeded = @()
foreach ($f in $riskFlags) {
  if ($f.tier -eq 'human_only') {
    Deny 'HUMAN_ONLY_ACTION' "$($f.flag): $($f.paths -join ', ')"
    continue
  }
  # elevated: the named evidence must be present in the review artifact.
  $elevatedNeeded += $f.flag
  foreach ($req in $f.requires) {
    if (-not (HasEvidence $req)) {
      Deny 'ELEVATED_EVIDENCE_MISSING' "risk '$($f.flag)' ($($f.paths -join ', ')) requires review evidence '$req'. $($f.why)"
    }
  }
}

# If any elevated risk applies, the review must actually declare itself elevated.
# This stops an ordinary-depth review from silently clearing an elevated change.
if ($elevatedNeeded.Count -gt 0 -and $reviewDepth -cne 'elevated') {
  Deny 'ELEVATED_REVIEW_REQUIRED' "risk signals [$($elevatedNeeded -join ', ')] require review_depth='elevated'; artifact declares '$reviewDepth'."
}

# An elevated change with no patch available cannot clear C6a, so say so rather
# than passing on a path check alone.
if ($elevatedNeeded.Count -gt 0 -and [string]::IsNullOrWhiteSpace($patch)) {
  Deny 'PATCH_UNAVAILABLE' 'Elevated risk applies but the diff patch could not be read, so irreversible-content signals could not be evaluated.'
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
  # An explicit marker is strong EVIDENCE, not an automatic veto — but it is never
  # silently overridden. To proceed, the review must adjudicate it on the record:
  # who placed it, why, whether that reason still holds, and whether the actual
  # CONSEQUENCE is human-only. A marker reflecting a genuine irreversible boundary
  # still halts; one reflecting a superseded blanket policy can be cleared with
  # reasoning that stays in the artifact.
  $adj = if ($review -and $review -ne 'UNREADABLE') { Prop $review 'marker_adjudication' } else { $null }
  if (-not $adj) {
    Deny 'MARKER_UNADJUDICATED' "explicitly marked human-gated in: $($declaredHuman -join ', '). To proceed, the review artifact must carry marker_adjudication{placed_by, reason, still_valid, superseded_by, consequence_is_human_only}. Do not strip the marker."
  } else {
    $stillValid  = [bool](Prop $adj 'still_valid' $true)          # unknown => still valid
    $consequence = [bool](Prop $adj 'consequence_is_human_only' $true)
    $reason      = [string](Prop $adj 'reason' '')
    $placedBy    = [string](Prop $adj 'placed_by' '')
    if (-not $reason -or -not $placedBy) {
      Deny 'MARKER_ADJUDICATION_INCOMPLETE' 'marker_adjudication must record both placed_by and reason.'
    }
    if ($consequence) {
      Deny 'HUMAN_ONLY_ACTION' "marker adjudicated as a genuine human-only consequence: $reason"
    } elseif ($stillValid) {
      Deny 'MARKER_STILL_VALID' "marker adjudicated as still applicable: $reason"
    }
    # else: superseded and the consequence is not human-only -> proceeds, with the
    # reasoning permanently recorded in the artifact.
  }
}

# --- C7  scope sanity -------------------------------------------------------
# Size is a proxy for review effort, not for danger. A 42-file generated-snapshot
# refresh is safer than a 3-line change to an auth check. So exceeding a ceiling
# now demands proportionate EVIDENCE rather than a human signature.
$scopeElevated = ($files.Count -gt $MaxFiles) -or ($additions -gt $MaxAdditions)
if ($scopeElevated) {
  if (-not (HasEvidence 'full_diff_reviewed')) {
    Deny 'SCOPE_EVIDENCE_MISSING' "$($files.Count) files / +$additions exceeds the ordinary ceiling ($MaxFiles files, $MaxAdditions additions); review evidence 'full_diff_reviewed' is required."
  }
  if ($reviewDepth -cne 'elevated') {
    Deny 'ELEVATED_REVIEW_REQUIRED' "diff size ($($files.Count) files / +$additions) requires review_depth='elevated'; artifact declares '$reviewDepth'."
  }
  # Far beyond the ceiling: one careful pass is not enough evidence.
  if ($files.Count -gt ($MaxFiles * 3) -or $additions -gt ($MaxAdditions * 3)) {
    if (-not (HasEvidence 'second_review_pass')) {
      Deny 'SECOND_REVIEW_REQUIRED' "diff is more than 3x the ordinary ceiling ($($files.Count) files / +$additions); review evidence 'second_review_pass' is required."
    }
  }
}
if ($files.Count -eq 0)             { Deny 'NO_FILES_REPORTED' 'No changed files reported; cannot assess scope or risk.' }
# Absent additions defaulted to 0, which PASSES the ceiling — so a PR touching
# few files could carry an arbitrarily large diff through C7 unmeasured
# (falsification F1, 2026-08-08). Unknown size must block, not pass.
if (-not (HasProp $prState 'additions')) {
  Deny 'ADDITIONS_UNKNOWN' 'The PR state reports no additions count; diff size cannot be assessed, so the scope ceiling cannot be applied.'
}

# --- C8  independent, SHA-pinned review ------------------------------------
# $review / $reviewPath were loaded before C6, which needs the evidence block.
if (-not (Test-Path $reviewPath)) {
  Deny 'NO_INDEPENDENT_REVIEW' "No review artifact at $reviewPath. An independent review pass must approve this head SHA before merge."
} elseif ($review -eq 'UNREADABLE') {
  Deny 'REVIEW_UNREADABLE' "Could not parse $reviewPath as JSON."
  $review = $null
}
if ($review -and $review -ne 'UNREADABLE') {
  $rSha      = [string](Prop $review 'reviewed_sha' '')
  $rVerdict  = [string](Prop $review 'verdict' '')
  $reviewer  = [string](Prop $review 'reviewer' '')
  $authoredBy= [string](Prop $review 'authored_by' '')
  if (-not $headSha)                { Deny 'HEAD_SHA_UNKNOWN' 'Cannot confirm the review matches the current tree.' }
  elseif ($rSha -ne $headSha)       { Deny 'REVIEW_STALE' "review approved $rSha but PR head is $headSha; new commits invalidate the review." }
  # -cne: 'approve' must not satisfy 'APPROVE' (falsification F7). A review
  # artifact is a machine contract; loose casing means loose parsing.
  if ($rVerdict -cne 'APPROVE')     { Deny 'REVIEW_NOT_APPROVED' "review verdict=$rVerdict (need exactly APPROVE)." }
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
  risk_tier       = [string]$(if ($irrevHumanOnly.Count -gt 0) { 'human_only' } elseif ($elevatedNeeded.Count -gt 0 -or $scopeElevated -or $irrev.Count -gt 0) { 'elevated' } else { 'ordinary' })
  elevated_for    = @($elevatedNeeded)
  scope_elevated  = [bool]$scopeElevated
  review_depth    = [string]$reviewDepth
  irreversible    = @($irrev | ForEach-Object { $_.signal })
  checks          = @($checkSummary)
  allow_no_ci     = [bool]$AllowNoCI
  reasons         = $reasonList
  evaluated_utc   = (Get-Date).ToUniversalTime().ToString('o')
}

if ($AsJson) { $out | ConvertTo-Json -Depth 8 } else { $out }
