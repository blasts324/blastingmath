<#
  Builds single-file.html: the whole site in one HTML file.
  Inside it: the page, its CSS and JS, the game list, the cover image,
  the icon, and the featured game with three.js baked in.
  The GameDistribution games still load from GameDistribution (needs internet).

  Usage (from this folder):
    powershell -ExecutionPolicy Bypass -File build.ps1
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
function Read-Text($p) { [IO.File]::ReadAllText((Join-Path $root $p), [Text.Encoding]::UTF8) }
function DataUri($p, $type) { "data:$type;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root $p))) }
# keep inlined scripts from closing their <script> tag early
function SafeJs($s) { $s.Replace('</', '<\/') }

$app = Read-Text 'js\app.js'
$m = [regex]::Match($app, "const FEATURED = \{ id: '([^']+)'")
if (-not $m.Success) { throw 'Could not find the featured game in js/app.js' }
$slug = $m.Groups[1].Value

# 1. The featured game with three.js inlined, packed as base64 and opened from a blob URL
$game = Read-Text "games\$slug\index.html"
$tag = '<script src="../../js/three.min.js?raw"></script>'
if (-not $game.Contains($tag)) { throw "three.js script tag not found in games\$slug\index.html" }
$game = $game.Replace($tag, '<script>' + (SafeJs (Read-Text 'js\three.min.js')) + '</script>')
$gameB64 = [Convert]::ToBase64String($utf8.GetBytes($game))
$loader = "<script>(function(){var b=atob('$gameB64'),u=new Uint8Array(b.length);for(var i=0;i<b.length;i++)u[i]=b.charCodeAt(i);" +
          "window.FEATURED_SRC=URL.createObjectURL(new Blob([u],{type:'text/html'}));})();</script>"

# 2. Your own games (added with add-game.ps1)
#    Pictures are packed in. A game that is one single .html file is packed in too;
#    games made of many files are linked from games\custom\ (keep single-file.html next to that folder).
$custom = @()
$listFile = Join-Path $root 'games\custom\games.json'
if (Test-Path $listFile) {
  $raw = [IO.File]::ReadAllText($listFile, [Text.Encoding]::UTF8)
  if ($raw.Trim()) { foreach ($g in (ConvertFrom-Json $raw)) { $custom += $g } }
}
$mime = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'; '.gif' = 'image/gif' }
$blobs = @(); $linked = @()
foreach ($g in $custom) {
  $imgRel = $g.img -replace '/', '\'
  if (Test-Path (Join-Path $root $imgRel)) { $g.img = DataUri $imgRel $mime[[IO.Path]::GetExtension($imgRel).ToLower()] }
  $dir = Join-Path $root "games\custom\$($g.dir)"
  $files = @(Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue)
  if ($files.Count -eq 1 -and $files[0].Extension -in '.html', '.htm') {
    $blobs += "'" + $g.id + "':'" + [Convert]::ToBase64String([IO.File]::ReadAllBytes($files[0].FullName)) + "'"
  } else { $linked += $g.t }
}
$customJson = '[' + (@($custom | ForEach-Object { ConvertTo-Json -InputObject $_ -Compress }) -join ',') + ']'
$customScript = "<script>window.CUSTOM_GAMES=$customJson;(function(){var L={" + ($blobs -join ',') + "};" +
  "function B(s){var b=atob(s),u=new Uint8Array(b.length);for(var i=0;i<b.length;i++)u[i]=b.charCodeAt(i);return URL.createObjectURL(new Blob([u],{type:'text/html'}));}" +
  "window.CUSTOM_GAMES.forEach(function(g){if(L[g.id])g.src=B(L[g.id]);});})();</script>"

# 3. The page with everything else inlined
$script:html = Read-Text 'index.html'
function Swap($old, $new) {
  if (-not $script:html.Contains($old)) { throw "Not found in index.html: $old" }
  $script:html = $script:html.Replace($old, $new)
}
Swap '<link rel="stylesheet" href="css/style.css">' ("<style>`n" + (Read-Text 'css\style.css') + '</style>')
Swap "img/$slug.jpg" (DataUri "img\$slug.jpg" 'image/jpeg')
Swap 'img/favicon.svg' (DataUri 'img\favicon.svg' 'image/svg+xml')
Swap '<script src="js/games.js?raw"></script>' ('<script>' + (SafeJs (Read-Text 'js\games.js')) + '</script>')
Swap '<script src="js/app.js?raw"></script>' ($loader + "`n" + (SafeJs $customScript).Replace('<\/script>', '</script>') + "`n<script>" + (SafeJs $app) + '</script>')

$out = Join-Path $root 'single-file.html'
[IO.File]::WriteAllText($out, $script:html, $utf8)
$mb = [math]::Round((Get-Item $out).Length / 1MB, 2)
Write-Host "Built single-file.html ($mb MB)"
if ($linked.Count) {
  Write-Host "These games are made of many files, so single-file.html links to them in games\custom\"
  Write-Host "instead of packing them in. Keep single-file.html next to the games folder for them to work:"
  $linked | ForEach-Object { Write-Host "  - $_" }
}

# the .svg version too (only when build-svg.ps1 is present)
$svgBuild = Join-Path $root 'build-svg.ps1'
if (Test-Path $svgBuild) { & $svgBuild }
