<#
  Renames the featured game everywhere on the site: page text, titles,
  the game's own menu, the game folder and the cover image.

  Usage (from this folder):
    powershell -ExecutionPolicy Bypass -File rename.ps1 "New Name"

  It works out the current name by itself, so you can run it again later.
#>
param([Parameter(Mandatory = $true, Position = 0)][string]$Name)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
function Read-Text($p) { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Write-Text($p, $t) { [IO.File]::WriteAllText($p, $t, $utf8) }
function Html($s) { $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;') }
function Js($s) { $s.Replace('\', '\\').Replace("'", "\'") }

$Name = $Name.Trim()
if (-not $Name) { throw 'Give a name, e.g.: rename.ps1 "My Game"' }

# Current name and folder slug live in js/app.js
$app = Join-Path $root 'js\app.js'
$m = [regex]::Match((Read-Text $app), "const FEATURED = \{ id: '([^']+)', t: '((?:\\.|[^'\\])*)'")
if (-not $m.Success) { throw 'Could not find the current game name in js/app.js' }
$oldSlug = $m.Groups[1].Value
$oldName = $m.Groups[2].Value -replace '\\(.)', '$1'

$newSlug = ($Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $newSlug) { $newSlug = 'featured-game' }
if ($oldName -ceq $Name -and $oldSlug -eq $newSlug) { Write-Host "It's already called '$Name'."; exit 0 }

# Folder and cover image
if ($newSlug -ne $oldSlug) {
  $oldDir = Join-Path $root "games\$oldSlug"
  $newDir = Join-Path $root "games\$newSlug"
  if ((Test-Path $newDir) -and ($oldSlug -ine $newSlug)) { throw "games\$newSlug already exists" }
  if (Test-Path $oldDir) { Rename-Item $oldDir "$newSlug-tmp"; Rename-Item (Join-Path $root "games\$newSlug-tmp") $newSlug }
  $oldImg = Join-Path $root "img\$oldSlug.jpg"
  if (Test-Path $oldImg) { Rename-Item $oldImg "$newSlug-tmp.jpg"; Rename-Item (Join-Path $root "img\$newSlug-tmp.jpg") "$newSlug.jpg" }
}

# Text in pages, scripts and styles (the game catalogue and three.js are left alone)
$changed = @()
Get-ChildItem -Path $root -Recurse -File -Include *.html, *.js, *.css, package.json |
  Where-Object { $_.Name -notin @('three.min.js', 'games.js', 'single-file.html') -and $_.FullName -notlike '*\games\custom\*' } |
  ForEach-Object {
    $t = Read-Text $_.FullName
    $before = $t
    if ($_.Extension -eq '.js') { $t = $t.Replace((Js $oldName), (Js $Name)) }
    else { $t = $t.Replace((Html $oldName), (Html $Name)) }
    $t = $t.Replace($oldSlug, $newSlug)
    if ($t -cne $before) { Write-Text $_.FullName $t; $changed += $_.FullName.Substring($root.Length + 1) }
  }

Write-Host "Renamed '$oldName' to '$Name'."
Write-Host "Folder: games\$newSlug   Cover: img\$newSlug.jpg"
Write-Host "Updated files:"; $changed | ForEach-Object { Write-Host "  $_" }

# Rebuild the single-file version so it matches
& (Join-Path $root 'build.ps1')
