<#
  Add your own games to the site: one, or lots at once.

  Easiest: double-click "Add Game.bat", or drag game files (or a whole folder of them) onto it.
  From a terminal in this folder:
    powershell -ExecutionPolicy Bypass -File add-game.ps1
    powershell -ExecutionPolicy Bypass -File add-game.ps1 "C:\games\a.zip" "C:\games\b.swf" "C:\more games"
    powershell -ExecutionPolicy Bypass -File add-game.ps1 game.zip -Name "My Game" -Image cover.png
  Remove games you added (one or several):
    powershell -ExecutionPolicy Bypass -File add-game.ps1 -Remove

  A game is a ZIP of a web game (an index.html, or another .html file) or a Flash .swf.
  With several games, names come from the file names (bloons-td-5.swf -> "Bloons Td 5", or press R
  to rename them) and a picture with the same name next to a game (game.zip + game.png) is used;
  games without a picture show their first letter.
  Games go in games\custom\, pictures in img\custom\.

  Added games are part of the website: double-click "PUSH REPO.bat" to send them to GitHub,
  and GitHub Pages puts them live a minute or two later.
    -Local   keep this game on this PC only (listed in games\custom\games.local.json,
             kept out of git through .gitignore)
#>
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Zip = @(),  # game files and/or folders
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
    @($local | ForEach-Object { "games/custom/$($_.dir)/"; if ($_.img) { $_.img } }) + @($end)
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
  $picks = @()
  if ($Name) {
    $picks = @($script:list | Where-Object { $_.t -eq $Name } | Select-Object -First 1)
    if (-not $picks.Count) { throw "No added game is called '$Name'." }
  } else {
    Say ''; Say '  Your games:' White
    for ($i = 0; $i -lt $script:list.Count; $i++) { Say ("   {0}. {1}" -f ($i + 1), $script:list[$i].t) }
    $answer = Read-Host '  Number(s) to remove, e.g. 3 or 1,4,7 or 2-5 (just Enter to cancel)'
    if (-not $answer.Trim()) { exit 0 }
    $nums = @()
    foreach ($part in ($answer -split '[,\s]+' | Where-Object { $_ })) {
      if ($part -match '^(\d+)-(\d+)$') { $nums += [int]$Matches[1]..[int]$Matches[2] }
      elseif ($part -match '^\d+$') { $nums += [int]$part }
      else { throw "Didn't understand '$part'." }
    }
    foreach ($n in ($nums | Sort-Object -Unique)) {
      if ($n -lt 1 -or $n -gt $script:list.Count) { throw "There's no game number $n." }
      $picks += $script:list[$n - 1]
    }
  }
  foreach ($pick in $picks) {
    $dir = Join-Path $customDir $pick.dir
    if ($pick.dir -and (Test-Path -LiteralPath $dir)) { Remove-Item -LiteralPath $dir -Recurse -Force }
    if ($pick.img -and $pick.img -like 'img/custom/*') {
      $img = Join-Path $root ($pick.img -replace '/', '\')
      if (Test-Path -LiteralPath $img -PathType Leaf) { Remove-Item -LiteralPath $img -Force }
    }
    $script:list = @($script:list | Where-Object { $_.id -ne $pick.id })
    Say "Removed '$($pick.t)'." Green
  }
  Save-List
  if (@($picks | Where-Object { -not $_.local }).Count) { Push-Hint }
  Rebuild
  exit 0
}

# ---------------- add ----------------
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

# Paths typed or dragged into the window: several at once, some "quoted", maybe & 'like this'
function Split-Paths($text) {
  $out = @()
  foreach ($m in [regex]::Matches("$text", '"([^"]+)"|''([^'']+)''|(\S+)')) {
    $p = ($m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value).Trim()
    if ($p -and $p -ne '&') { $out += $p }
  }
  $out
}
# Files and folders -> the game files in them (.zip / .swf; a folder's top level only)
function Expand-Games($paths) {
  $out = @()
  foreach ($p in $paths) {
    $p = Clean-Path $p
    if (Test-Path -LiteralPath $p -PathType Container) {
      $found = @(Get-ChildItem -LiteralPath $p -File | Where-Object { $_.Extension -in '.zip', '.swf' } | Sort-Object Name)
      if (-not $found.Count) { Say "   No .zip or .swf files in $p" Yellow }
      $out += @($found | ForEach-Object { $_.FullName })
    } elseif (Test-Path -LiteralPath $p -PathType Leaf) {
      if ([IO.Path]::GetExtension($p).ToLower() -in '.zip', '.swf') { $out += (Resolve-Path -LiteralPath $p).Path }
      else { Say "   Skipped $p (not a .zip or .swf)" Yellow }
    } else { Say "   Not found: $p" Yellow }
  }
  @($out | Select-Object -Unique)
}
# "bloons-tower_defense.5.swf" -> "Bloons Tower Defense 5"
function Name-From-File($path) {
  $n = [IO.Path]::GetFileNameWithoutExtension($path) -replace '[_\-.]+', ' ' -replace '\s+', ' '
  (Get-Culture).TextInfo.ToTitleCase($n.Trim())
}
# a picture with the same name next to the game file: game.zip + game.png
function Find-Picture($path) {
  $dir = Split-Path $path; $base = [IO.Path]::GetFileNameWithoutExtension($path)
  foreach ($e in $imgExts) { $p = Join-Path $dir ($base + $e); if (Test-Path -LiteralPath $p -PathType Leaf) { return $p } }
  $null
}

# Adds one game; returns $true when it worked
function Add-One($gamePath, $title, $imgPath) {
  $isSwf = [IO.Path]::GetExtension($gamePath).ToLower() -eq '.swf'
  # folder name from the game name, made unique
  $base = ($title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
  if (-not $base) { $base = 'game' }
  $slug = $base; $n = 2
  while ((Test-Path (Join-Path $customDir $slug)) -or ($script:list | Where-Object { $_.dir -eq $slug })) { $slug = "$base-$n"; $n++ }

  $dest = Join-Path $customDir $slug
  New-Item -ItemType Directory -Force $dest | Out-Null
  $destFull = [IO.Path]::GetFullPath($dest).TrimEnd('\') + '\'
  try {
    $count = 0
    if ($isSwf) {
      Copy-Item -LiteralPath $gamePath (Join-Path $dest 'game.swf')
      $count = 1
    } else {
      $zf = [IO.Compression.ZipFile]::OpenRead($gamePath)
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
      if ($swf) { Write-FlashPage $dest $swf.FullName.Substring($destFull.Length) $title }
    }

    # find the page that starts the game: the shallowest index.html, else the only .html
    $htmls = @(Get-ChildItem -LiteralPath $dest -Recurse -File |
      Where-Object { $_.Extension -in '.html', '.htm' -and $_.FullName -notmatch '\\__MACOSX\\' } |
      Sort-Object $byDepth, FullName)
    if (-not $htmls.Count) { throw "There's no .html or .swf file in it, so it isn't a game the page can open." }
    $entry = $htmls | Where-Object { $_.Name -eq 'index.html' } | Select-Object -First 1
    if (-not $entry) {
      if ($htmls.Count -eq 1) { $entry = $htmls[0] }
      else {
        Say "   '$title' has several .html files. Which one starts the game?" White
        $shown = [Math]::Min($htmls.Count, 20)
        for ($i = 0; $i -lt $shown; $i++) { Say ("    {0}. {1}" -f ($i + 1), $htmls[$i].FullName.Substring($destFull.Length)) }
        $k = 0
        while (-not ([int]::TryParse((Read-Host '   Number'), [ref]$k) -and $k -ge 1 -and $k -le $shown)) { Say '    Pick one of the numbers above.' Yellow }
        $entry = $htmls[$k - 1]
      }
    }
  } catch {
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    Say "   Couldn't add '$title': $($_.Exception.Message)" Red
    return $false
  }

  $rel = ($entry.FullName.Substring($destFull.Length) -split '\\' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $img = ''
  if ($imgPath) {
    $ext = [IO.Path]::GetExtension($imgPath).ToLower()
    New-Item -ItemType Directory -Force $imgDir | Out-Null
    Copy-Item -LiteralPath $imgPath (Join-Path $imgDir "$slug$ext") -Force
    $img = "img/custom/$slug$ext"
  }
  $script:list += [pscustomobject]@{
    id = "my-$slug"; t = $title; d = ''; dir = $slug
    src = "games/custom/$slug/$rel"; img = $img; local = [bool]$Local
  }
  $what = if ($isSwf -or ($files | Where-Object { $_.Extension -eq '.swf' })) { 'Flash, plays with Ruffle' } elseif ($count -eq 1) { '1 file' } else { "$count files" }
  $pic = if ($img) { '' } else { ', no picture (shows its first letter)' }
  Say "   Added '$title' ($what$pic)." Green
  $true
}

Say ''
Say '  Add games' White
Say '  ---------' White
$paths = @()
foreach ($z in $Zip) { $paths += Split-Paths $z }
if (-not $paths.Count) {
  Say '  Drag one or more game ZIPs or Flash .swf files (or a folder full of them)'
  Say '  into this window, then press Enter.'
  while (-not $paths.Count) { $paths = @(Split-Paths (Read-Host '  1) Games')) }
}
$games = @(Expand-Games $paths)
if (-not $games.Count) { throw 'No games to add: use .zip or .swf files, or a folder with them.' }

# one entry per game: file, name, picture
$todo = @()
foreach ($g in $games) { $todo += [pscustomobject]@{ file = $g; name = (Name-From-File $g); img = (Find-Picture $g) } }

if ($todo.Count -eq 1) {
  # one game: ask for its name and picture (or take -Name / -Image)
  $one = $todo[0]
  Say "  Game file: $($one.file)"
  if ($Name) { $one.name = $Name.Trim() }
  else {
    $typed = (Read-Host "  2) Game name (just Enter for '$($one.name)')").Trim()
    if ($typed) { $one.name = $typed }
  }
  if ($Image) {
    $one.img = Check-File $Image $imgExts
    if (-not $one.img) { throw "Can't use '$Image' as the picture. Use a PNG (or JPG/WEBP/GIF)." }
  } elseif (-not $one.img) {
    while ($true) {
      $typed = Read-Host '  3) Drag the game picture into this window (just Enter for none)'
      if (-not $typed.Trim()) { break }
      $one.img = Check-File $typed $imgExts
      if ($one.img) { break }
      Say '   That has to be a PNG, JPG, WEBP or GIF file. Try again.' Yellow
    }
  } else { Say "  Picture: $($one.img)" }
} else {
  # many games: names from the file names, pictures with the same name next to them
  Say ''
  Say "  $($todo.Count) games:" White
  for ($i = 0; $i -lt $todo.Count; $i++) {
    $pic = if ($todo[$i].img) { 'picture found' } else { 'no picture' }
    Say ("   {0,2}. {1}   ({2}, {3})" -f ($i + 1), $todo[$i].name, [IO.Path]::GetFileName($todo[$i].file), $pic)
  }
  Say '  Tip: put a picture with the same name next to a game (game.zip + game.png) and it is used.' DarkGray
  $a = (Read-Host '  Add them all? Y = yes, R = rename some first, N = cancel').Trim().ToUpper()
  if ($a -eq 'N') { Say '  Nothing added.'; exit 0 }
  if ($a -eq 'R') {
    foreach ($t in $todo) {
      $typed = (Read-Host "   Name for $([IO.Path]::GetFileName($t.file)) (just Enter for '$($t.name)')").Trim()
      if ($typed) { $t.name = $typed }
    }
  }
}

# skip games that are already in the list under the same name
$added = 0; $skipped = 0; $failed = 0
Say ''
foreach ($t in $todo) {
  if ($script:list | Where-Object { $_.t -eq $t.name }) { Say "   Skipped '$($t.name)': a game with that name is already added." Yellow; $skipped++; continue }
  if (Add-One $t.file $t.name $t.img) { $added++ } else { $failed++ }
}
if ($added) { Save-List }

Say ''
$sum = "  Added $added game$(if ($added -ne 1) { 's' })"
if ($skipped) { $sum += ", skipped $skipped" }
if ($failed) { $sum += ", $failed failed" }
Say "$sum." $(if ($failed) { 'Yellow' } else { 'Green' })
if (-not $added) { exit 0 }
Say "  They're in the 'My Games' section. Refresh the page to see them."
if ($Local) { Say '  Kept on this PC only (-Local).' }
else { Push-Hint }
Rebuild
