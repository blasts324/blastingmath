<#
  Sends everything new in this folder to GitHub, so the website updates.
  Easiest: double-click "PUSH REPO.bat".

  What stays on this PC: games added with "add-game.ps1 -Local", the single-file
  builds and anything else listed in .gitignore.
#>
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
Set-Location $root

Say ''
Say '  Push to GitHub' White
Say '  --------------' White
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Say '  Git is not installed (get it from git-scm.com).' Red; exit 1 }
if (-not (Test-Path (Join-Path $root '.git'))) { Say "  This folder isn't a git repo." Red; exit 1 }
$branch = "$(git rev-parse --abbrev-ref HEAD)".Trim()

# 1. save what changed as a commit
$changes = @(git status --porcelain --untracked-files=all)
if ($changes.Count) {
  # show each game folder as one line instead of every file inside it
  $shown = $changes | ForEach-Object { $_.Substring(3).Trim('"') } | ForEach-Object {
    if ($_ -match '^(games/(?:custom|flash|play)/[^/]+)/') { $Matches[1] + '/' } else { $_ }
  } | Sort-Object -Unique
  Say "  Changes to send:"
  $shown | Select-Object -First 30 | ForEach-Object { Say "   - $_" }
  if (@($shown).Count -gt 30) { Say "   ...and $(@($shown).Count - 30) more" }
  git add -A 2>$null   # (hides git's line-ending notices)
  git commit -q -m ("Update site " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  if ($LASTEXITCODE -ne 0) { Say "  Couldn't save the changes (git commit failed)." Red; exit 1 }
} else {
  Say '  No new changes in this folder.'
}

# 2. bring in anything changed on GitHub's website first
Say '  Checking GitHub...'
git fetch -q origin
if ($LASTEXITCODE -ne 0) { Say "  Can't reach GitHub (no internet?). Your changes are saved; run PUSH REPO again later." Red; exit 1 }
$behind = 0; [int]::TryParse("$(git rev-list --count HEAD..origin/$branch 2>$null)", [ref]$behind) | Out-Null
if ($behind -gt 0) {
  Say "  GitHub has $behind change(s) made elsewhere. Adding them first..."
  git pull -q --rebase origin $branch
  if ($LASTEXITCODE -ne 0) {
    git rebase --abort 2>$null
    Say "  Couldn't combine them with yours automatically. Nothing was pushed." Red
    exit 1
  }
}

# 3. push
$ahead = 0; [int]::TryParse("$(git rev-list --count origin/$branch..HEAD 2>$null)", [ref]$ahead) | Out-Null
if ($ahead -eq 0) { Say '  GitHub is already up to date.' Green; exit 0 }
Say "  Pushing to GitHub (big games can take a minute)..."
git push -q origin $branch
if ($LASTEXITCODE -ne 0) { Say "  Push failed (no internet, or not signed in to GitHub?). Your changes are saved; run PUSH REPO again later." Red; exit 1 }

Say ''
Say '  Done! The website updates in a minute or two:' Green
$url = "$(git remote get-url origin)".Trim()
if ($url -match 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$') { Say ("  https://{0}.github.io/{1}/" -f $Matches[1].ToLower(), $Matches[2]) White }
