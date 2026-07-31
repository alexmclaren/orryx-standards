# Creates (or reuses) a per-session git worktree so concurrent agent sessions
# never share a working tree. Idempotent; safe to run anytime.
#
# Why this exists: on 2026-07-31 two separate agent sessions committed onto
# branches a third session had checked out, in two different repos, within the
# same hour (orryx-standards PR #19 picked up an unrelated 38-file commit;
# orryx-delivery-dashboard PR #10 picked up a CLAUDE.md commit). Nothing was
# lost, but both PRs had to be rebuilt before merge. A worktree per session
# removes the shared-checkout hazard entirely.
#
#   pwsh scripts/session-worktree.ps1 -Repo orryx-standards -Task env-ignore
#   -> D:\orryx-standards-wt-env-ignore   (branch wt/env-ignore, from origin/<default>)
#
#   -Base       branch/ref to fork from (default: the repo's origin/HEAD)
#   -Root       where repos live (default: D:\)
#   -List       show this repo's worktrees and exit
#   -Remove     remove the worktree for -Task (refuses if it has uncommitted work)
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Task,
  [string]$Base,
  [string]$Root = 'D:\',
  [switch]$List,
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'

$repoPath = Join-Path $Root $Repo
if (-not (Test-Path (Join-Path $repoPath '.git'))) {
  throw "Not a git repo: $repoPath"
}

if ($List) {
  git -C $repoPath worktree list
  exit 0
}

if (-not $Task) { throw "-Task is required (short kebab-case slug, e.g. 'env-ignore')" }
# Keep the slug filesystem- and branch-safe; the name ends up in a path AND a ref.
$slug = ($Task -replace '[^A-Za-z0-9-]', '-').Trim('-').ToLower()
if (-not $slug) { throw "-Task '$Task' reduced to an empty slug" }

$wtPath = Join-Path $Root "$Repo-wt-$slug"   # matches the existing D:\*-wt-* convention
$branch = "wt/$slug"

if ($Remove) {
  if (-not (Test-Path $wtPath)) { Write-Host "Nothing to remove: $wtPath"; exit 0 }
  # Refuse to discard work: `worktree remove` without -Force already errors on a
  # dirty tree, but check explicitly so the message says why.
  $dirty = git -C $wtPath status --porcelain
  if ($dirty) {
    throw "Refusing to remove $wtPath - it has uncommitted changes:`n$dirty"
  }
  git -C $repoPath worktree remove $wtPath
  git -C $repoPath worktree prune
  Write-Host "Removed $wtPath (branch $branch kept - delete it yourself if unwanted)"
  exit 0
}

# Reuse an existing worktree rather than failing: re-running mid-session is the
# common case, and silently landing somewhere else would be worse than a no-op.
if (Test-Path $wtPath) {
  Write-Host "Reusing existing worktree"
  Write-Host "  path   : $wtPath"
  Write-Host "  branch : $(git -C $wtPath branch --show-current)"
  exit 0
}

git -C $repoPath fetch --quiet origin

if (-not $Base) {
  # origin/HEAD is the repo's real default branch - do not assume 'main'.
  # orryx-delivery-dashboard is on 'master'.
  $head = git -C $repoPath symbolic-ref --quiet refs/remotes/origin/HEAD 2>$null
  if (-not $head) {
    git -C $repoPath remote set-head origin --auto | Out-Null
    $head = git -C $repoPath symbolic-ref --quiet refs/remotes/origin/HEAD 2>$null
  }
  if (-not $head) { throw "Cannot determine origin/HEAD for $Repo - pass -Base explicitly" }
  $Base = ($head -replace '^refs/remotes/', '')
}

$branchExists = git -C $repoPath rev-parse --verify --quiet $branch
if ($branchExists) {
  git -C $repoPath worktree add $wtPath $branch          # resume prior work
} else {
  git -C $repoPath worktree add -b $branch $wtPath $Base # fresh branch off Base
}

Write-Host ""
Write-Host "Worktree ready - cd here before you edit or commit:"
Write-Host "  path   : $wtPath"
Write-Host "  branch : $branch"
Write-Host "  base   : $Base"
Write-Host ""
Write-Host "When finished:  pwsh $PSCommandPath -Repo $Repo -Task $slug -Remove"
