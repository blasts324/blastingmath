<#
  Add your own HTML5 game to the site.

  Easiest: double-click "Add Game.bat" (or drag a game ZIP onto it).
  From a terminal in this folder:
    powershell -ExecutionPolicy Bypass -File add-game.ps1
  Remove a game you added:
    powershell -ExecutionPolicy Bypass -File add-game.ps1 -Remove

  The ZIP has to contain a web game: an index.html (or another .html file), or a Flash .swf.
  Games go in games\custom\, pictures in img\custom\.

  Added games are part of the website: double-click "PUSH REPO.bat" to send them to GitHub,
  and GitHub Pages puts them live a minute or two later.
    -Local   keep this game on this PC only (listed in games\custom\games.local.json,
             kept out of git through .gitignore)
#>
param(
  [Parameter(Position = 0)][string]$Zip,
  [string]$Name,
  [string]$Image,
  [switch]$Remove,
  [switch]$Local
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$customDir = Join-Path $root 'games\custom'
$imgDir = Join-Path $root 'img\custom'
$listFile = Join-Path $customDir 'games.json'          # on the website
$localFile = Join-Path $customDir 'games.local.json'   # only on this PC
$imgExts = @('.png', '.jpg', '.jpeg', '.webp', '.gif')

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
# Dragging a file into a console pastes its path, sometimes wrapped in quotes or as & '...'
function Clean-Path($p) {
  $p = "$p".Trim()
  if ($p.StartsWith('& ')) { $p = $p.Substring(2).Trim() }
  $p.Trim('"', "'")
}
function Check-File($p, $exts) {
  $p = Clean-Path $p
  if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
  if ($exts -notcontains [IO.Path]::GetExtension($p).ToLower()) { return $null }
  (Resolve-Path -LiteralPath $p).Path
}
function Ask-File($prompt, $exts) {
  while ($true) {
    $p = Check-File (Read-Host $prompt) $exts
    if ($p) { return $p }
    Say "   That didn't work. It has to be an existing $($exts -join ' / ') file. Try again." Yellow
  }
}

# every added game, from both lists; .local says which list it lives in
$script:list = @()
foreach ($pair in @(@($listFile, $false), @($localFile, $true))) {
  if (Test-Path $pair[0]) {
    $raw = [IO.File]::ReadAllText($pair[0], [Text.Encoding]::UTF8)
    if ($raw.Trim()) {
      foreach ($g in (ConvertFrom-Json $raw)) {
        $g | Add-Member -NotePropertyName local -NotePropertyValue $pair[1] -Force
        $script:list += $g
      }
    }
  }
}
function Write-List($file, $items) {
  $lines = @($items | ForEach-Object { ConvertTo-Json -InputObject ($_ | Select-Object id, t, d, dir, src, img) -Compress })
  $json = if ($lines.Count) { "[`n  " + ($lines -join ",`n  ") + "`n]" } else { '[]' }
  [IO.File]::WriteAllText($file, $json, $utf8)
}
function Save-List {
  New-Item -ItemType Directory -Force $customDir | Out-Null
  $local = @($script:list | Where-Object { $_.local })
  Write-List $listFile @($script:list | Where-Object { -not $_.local })
  Write-List $localFile $local
  # keep local-only games out of git: rewrite the managed block in git's private exclude
  # file (.git\info\exclude), which works like .gitignore but never gets pushed
  $gi = Join-Path $root '.git\info\exclude'
  if (-not (Test-Path (Join-Path $root '.git'))) { $gi = Join-Path $root '.gitignore' }
  New-Item -ItemType Directory -Force (Split-Path $gi) | Out-Null
  $start = '# local-only games (managed by add-game.ps1)'; $end = '# end of local-only games'
  $text = if (Test-Path $gi) { [IO.File]::ReadAllText($gi) } else { '' }
  $text = [regex]::Replace($text, '(?s)\r?\n?' + [regex]::Escape($start) + '.*?' + [regex]::Escape($end) + '\r?\n?', "`n")
  $block = @($start, 'games/custom/games.local.json') +
    @($local | ForEach-Object { "games/custom/$($_.dir)/"; ($_.img -replace '^img/custom/', 'img/custom/') }) + @($end)
  [IO.File]::WriteAllText($gi, $text.TrimEnd() + "`n`n" + ($block -join "`n") + "`n", $utf8)
}
function Push-Hint { Say '  To put it on the website, double-click "PUSH REPO.bat".' White }
function Rebuild {
  $build = Join-Path $root 'build.ps1'
  if (Test-Path $build) { Say ''; & $build }
}

# ---------------- remove ----------------
if ($Remove) {
  if (-not $script:list.Count) { Say 'You have not added any games yet.'; exit 0 }
  $pick = $null
  if ($Name) {
    $pick = $script:list | Where-Object { $_.t -eq $Name } | Select-Object -First 1
    if (-not $pick) { throw "No added game is called '$Name'." }
  } else {
    Say ''; Say '  Your games:' White
    for ($i = 0; $i -lt $script:list.Count; $i++) { Say ("   {0}. {1}" -f ($i + 1), $script:list[$i].t) }
    $n = 0
    $answer = Read-Host '  Number of the game to remove (just Enter to cancel)'
    if (-not $answer) { exit 0 }
    if (-not [int]::TryParse($answer, [ref]$n) -or $n -lt 1 -or $n -gt $script:list.Count) { throw "There's no game number $answer." }
    $pick = $script:list[$n - 1]
  }
  $dir = Join-Path $customDir $pick.dir
  if ($pick.dir -and (Test-Path -LiteralPath $dir)) { Remove-Item -LiteralPath $dir -Recurse -Force }
  $img = Join-Path $root ($pick.img -replace '/', '\')
  if (Test-Path -LiteralPath $img) { Remove-Item -LiteralPath $img -Force }
  $script:list = @($script:list | Where-Object { $_.id -ne $pick.id })
  Save-List
  Say "Removed '$($pick.t)'." Green
  if (-not $pick.local) { Push-Hint }
  Rebuild
  exit 0
}

# ---------------- add ----------------
Say ''
Say '  Add your own game' White
Say '  -----------------' White
if ($Zip) {
  $zipPath = Check-File $Zip @('.zip', '.swf')
  if (-not $zipPath) { throw "Can't use '$Zip'. It has to be a .zip or a Flash .swf file." }
  Say "  Game file: $zipPath"
} else {
  $zipPath = Ask-File '  1) Drag the game ZIP (or a Flash .swf) into this window, then press Enter' @('.zip', '.swf')
}
$isSwf = [IO.Path]::GetExtension($zipPath).ToLower() -eq '.swf'

# Flash games get a small page that plays them with Ruffle (vendor\ruffle)
function Write-FlashPage($dir, $swfRel, $title) {
  $t = [Net.WebUtility]::HtmlEncode($title)
  $swfUrl = (($swfRel -split '\\') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $page = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$t</title>
</head>
<body>
<div id="game"></div>
<script>window.FLASH_GAME = { swf: '$swfUrl' };</script>
<script src="../../../js/flash-player.js?raw"></script>
</body>
</html>
"@
  [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $page, $utf8)
}

if ($Name) { $Name = $Name.Trim() }
while (-not $Name) { $Name = (Read-Host '  2) Type the game name, then press Enter').Trim() }

if ($Image) {
  $imgPath = Check-File $Image $imgExts
  if (-not $imgPath) { throw "Can't use '$Image' as the picture. Use a PNG (or JPG/WEBP/GIF)." }
} else {
  $imgPath = Ask-File '  3) Drag the game picture (PNG) into this window, then press Enter' $imgExts
}

# folder name from the game name, made unique
$base = ($Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $base) { $base = 'game' }
$slug = $base; $n = 2
while ((Test-Path (Join-Path $customDir $slug)) -or ($script:list | Where-Object { $_.dir -eq $slug })) { $slug = "$base-$n"; $n++ }

$dest = Join-Path $customDir $slug
New-Item -ItemType Directory -Force $dest | Out-Null
$destFull = [IO.Path]::GetFullPath($dest).TrimEnd('\') + '\'
try {
  $count = 0
  if ($isSwf) {
    Copy-Item -LiteralPath $zipPath (Join-Path $dest 'game.swf')
    $count = 1
  } else {
  Say '  Unpacking...'
  $zf = [IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    foreach ($e in $zf.Entries) {
      $target = [IO.Path]::GetFullPath((Join-Path $dest $e.FullName))
      # never write outside the game's own folder
      if (-not $target.StartsWith($destFull, [StringComparison]::OrdinalIgnoreCase)) { Say "   Skipped unsafe path in ZIP: $($e.FullName)" Yellow; continue }
      if (-not $e.Name) { New-Item -ItemType Directory -Force $target | Out-Null; continue }
      New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
      [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
      $count++
    }
  } finally { $zf.Dispose() }
  if (-not $count) { throw 'That ZIP is empty.' }
  }

  $byDepth = { ($_.FullName.Substring($destFull.Length) -split '\\').Count }
  $files = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Sort-Object $byDepth, FullName)
  # a Flash game (a .swf, or a ZIP with a .swf and no web page): make a Ruffle page for it
  if (-not ($files | Where-Object { $_.Extension -in '.html', '.htm' })) {
    $swf = $files | Where-Object { $_.Extension -eq '.swf' } | Select-Object -First 1
    if ($swf) {
      Write-FlashPage $dest $swf.FullName.Substring($destFull.Length) $Name
      Say '  Flash game: it will play with Ruffle.'
    }
  }

  # find the page that starts the game: the shallowest index.html, else the only .html
  $htmls = @(Get-ChildItem -LiteralPath $dest -Recurse -File |
    Where-Object { $_.Extension -in '.html', '.htm' } |
    Sort-Object $byDepth, FullName)
  if (-not $htmls.Count) { throw "There's no .html or .swf file in that ZIP, so it isn't a game the page can open." }
  $entry = $htmls | Where-Object { $_.Name -eq 'index.html' } | Select-Object -First 1
  if (-not $entry) {
    if ($htmls.Count -eq 1) { $entry = $htmls[0] }
    else {
      Say '  The ZIP has several .html files. Which one starts the game?' White
      $shown = [Math]::Min($htmls.Count, 20)
      for ($i = 0; $i -lt $shown; $i++) { Say ("   {0}. {1}" -f ($i + 1), $htmls[$i].FullName.Substring($destFull.Length)) }
      $k = 0
      while (-not ([int]::TryParse((Read-Host '  Number'), [ref]$k) -and $k -ge 1 -and $k -le $shown)) { Say '   Pick one of the numbers above.' Yellow }
      $entry = $htmls[$k - 1]
    }
  }
} catch {
  Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
  throw
}

$rel = ($entry.FullName.Substring($destFull.Length) -split '\\' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
$ext = [IO.Path]::GetExtension($imgPath).ToLower()
New-Item -ItemType Directory -Force $imgDir | Out-Null
Copy-Item -LiteralPath $imgPath (Join-Path $imgDir "$slug$ext") -Force

$script:list += [pscustomobject]@{
  id  = "my-$slug"
  t   = $Name
  d   = ''
  dir = $slug
  src = "games/custom/$slug/$rel"
  img = "img/custom/$slug$ext"
  local = [bool]$Local
}
Save-List

Say ''
Say "  Added '$Name' ($count files)." Green
Say "  It's in the 'My Games' section. Refresh the page to see it."
if ($Local) { Say '  Kept on this PC only (-Local).' }
else { Push-Hint }
Rebuild
