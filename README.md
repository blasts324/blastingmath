# Subway Roller Unblocked

Subway Roller (a 3D endless runner made for this site) plus a list of browser games that
play right in the page: open-source HTML5 games, Flash games (played with
[Ruffle](https://ruffle.rs)) and games you add yourself.

- Website: https://blasts324.github.io/blastingmath/ (GitHub Pages, updates on every push)
- One-file versions: `single-file.html` and `single-file.svg` (build them yourself, see below)
- npm / jsDelivr copies: `NPM-PUBLISH.bat` (see below)

Everything is done with double-click `.bat` files or a PowerShell command on Windows.

---

## Contents

1. [What you need](#1-what-you-need)
2. [What's in this folder](#2-whats-in-this-folder)
3. [Try the site on your PC](#3-try-the-site-on-your-pc)
4. [Add or remove a game](#4-add-or-remove-a-game)
5. [Rename the featured game](#5-rename-the-featured-game)
6. [Put the website online (GitHub Pages)](#6-put-the-website-online-github-pages)
7. [One-file versions: single-file.html and single-file.svg](#7-one-file-versions-single-filehtml-and-single-filesvg)
8. [Publish to npm and jsDelivr](#8-publish-to-npm-and-jsdelivr)
9. [Files that stay on your PC](#9-files-that-stay-on-your-pc)
10. [Troubleshooting](#10-troubleshooting)
11. [Credits and licenses](#11-credits-and-licenses)

---

## 1. What you need

| Tool | Needed for | Get it |
|---|---|---|
| Windows + PowerShell | everything (it comes with Windows) | - |
| Git | pushing the website to GitHub | https://git-scm.com |
| Python 3 | trying the site locally, and the smallest `single-file.svg` | https://python.org |
| Node.js (includes npm) | publishing to npm / jsDelivr | https://nodejs.org |
| An npm account | publishing to npm | `npm login` |

Python is optional for the `.svg` build: without it the build still works, but uses gzip instead
of LZMA and the file comes out bigger.

## 2. What's in this folder

```
index.html            the site's page
css/style.css         its styles
js/app.js             the page's code (game list, player, search, recently played)
js/games.js           the list of hosted games (games/play/ and games/flash/)
js/flash-player.js    the "Goofle" loading screen + Ruffle, used by every Flash game page
js/three.min.js       three.js, used by Subway Roller
games/subway-roller/  the featured game
games/play/           open-source HTML5 games (each keeps its license file)
games/flash/          Flash games: game.swf + a small index.html each
games/custom/         games added with Add Game (list: games.json, and games.local.json for this PC only)
img/                  covers and thumbnails
vendor/ruffle/        Ruffle, the Flash player (MIT / Apache-2.0)

Add Game.bat          add a game              -> add-game.ps1
Remove Game.bat       remove an added game    -> add-game.ps1 -Remove
PUSH REPO.bat         send everything to GitHub (the website updates) -> push-repo.ps1
NPM-PUBLISH.bat       publish to npm / jsDelivr                        -> npm-publish.ps1 -> build-npm.ps1
build.ps1             builds single-file.html (and then single-file.svg)
build-svg.ps1         builds single-file.svg
rename.ps1            renames the featured game everywhere
```

## 3. Try the site on your PC

The page loads its game list with `fetch`, so open it through a small local web server rather
than double-clicking `index.html`:

```bash
python -m http.server 4517
```

Then open http://localhost:4517 in your browser. Press `Ctrl+C` in that window to stop it.

## 4. Add or remove a game

**Add:** double-click **`Add Game.bat`** (or drag a ZIP onto it). It asks for:

1. the game: a **ZIP** of a web game (with an `index.html`, or another `.html` file), or a Flash **`.swf`**
   (a ZIP with a `.swf` and no web page works too),
2. the game's **name**,
3. a **picture** for its tile (PNG, JPG, WEBP or GIF).

It unpacks the game into `games\custom\<name>\`, copies the picture to `img\custom\`, adds it to
`games\custom\games.json` (the "My Games" category) and rebuilds the one-file versions.
Flash games get a page that uses the Goofle loading screen and Ruffle automatically.

From a terminal you can skip the questions:

```bash
powershell -ExecutionPolicy Bypass -File add-game.ps1 "C:\path\game.zip" -Name "My Game" -Image "C:\path\cover.png"
```

Add `-Local` to keep a game **on this PC only**: it goes in `games.local.json`, git ignores it,
and it is never pushed to GitHub or published to npm.

**Remove:** double-click **`Remove Game.bat`** and pick the number of the game.

Only add games you're allowed to share: added games go on the public website and into the
npm packages.

## 5. Rename the featured game

```bash
powershell -ExecutionPolicy Bypass -File rename.ps1 "New Name"
```

It changes the name in the page, titles and the game's own menu, renames the game folder and
cover image, and rebuilds the one-file versions. Run it again any time to rename again.

## 6. Put the website online (GitHub Pages)

Double-click **`PUSH REPO.bat`**. It:

1. commits every change in this folder (except what `.gitignore` lists),
2. brings in changes made on GitHub's website first (so nothing is overwritten),
3. pushes to GitHub.

The workflow in `.github/workflows/static.yml` then deploys the site to GitHub Pages; it's live
a minute or two later at https://blasts324.github.io/blastingmath/.

GitHub refuses single files over 100 MB, so very big games can't go in the repo as-is.

## 7. One-file versions: single-file.html and single-file.svg

```bash
powershell -ExecutionPolicy Bypass -File build.ps1
```

(Add Game, Remove Game and rename.ps1 run this for you.) It makes two files you can copy anywhere:

### single-file.html

The whole page in one HTML file: styles, scripts, pictures, Subway Roller and single-file custom
games are packed in. Hosted games and Flash games are linked from the folder, so keep it next to
the `games\` folder for those.

### single-file.svg

The whole site, with **every game inside**, in one `.svg` file that runs straight in a browser
(Chrome, Edge, Firefox). Open it from disk; it works offline (games that load things from the
internet themselves still need it).

How it works:

- the page is converted to XHTML and placed inside an SVG `<foreignObject>`;
- every file every game needs is packed at the end of the file in **blocks**: identical files are
  stored once, all Flash games are compressed together (they share a lot), and each block uses
  LZMA or gzip, whichever is smaller;
- the blocks are written as text with a 91-letter alphabet (23% overhead, base64 is 33%);
- opening a game unpacks only its blocks (in a background worker, with an "Unpacking..." screen)
  and starts it in a frame; a small script in that frame sends the game's file requests to the
  packed copies.

The first build takes a few minutes (LZMA is slow). Compressed blocks are kept in `.svg-cache\`,
so later builds take seconds and only redo games that changed.

To build it on its own, or with options:

```bash
powershell -ExecutionPolicy Bypass -File build-svg.ps1
```

| Option | What it does |
|---|---|
| `-Exclude id1,id2` | leave those games out (ids are in `js/games.js` and `games\custom\*.json`) |
| `-Out path\name.svg` | write it somewhere else |
| `-SplitMB 48` | keep every file under 48 MB: bigger games go into `name.part1.txt`, `.part2.txt`... next to the `.svg` (these only work when the `.svg` is opened from a web address, not from disk) |
| `-Packs folder` | put those bigger games into shared npm "data packs" instead (used by NPM-PUBLISH) |

## 8. Publish to npm and jsDelivr

[jsDelivr](https://www.jsdelivr.com) serves every npm package for free, so a published package
gives you a link like:

```
https://cdn.jsdelivr.net/npm/nebula-flux@1.0.3/single-file.svg
```

### How to publish

1. Once: install Node.js and log in: `npm login`.
2. Double-click **`NPM-PUBLISH.bat`**. It asks:

   ```
     1) Update nebula-flux          (same link, new version)
     2) New package, random name    (new link, random .svg name)
   ```

   - **1** publishes the next version of `nebula-flux` (the link keeps the same file name).
   - **2** makes a brand-new package with a random name made of random letters (from the
     system's cryptographic random generator, checked to be free on npm), and gives its page a
     random `.svg` name too. It shows you the link before anything is uploaded.

3. Type **Y** to go ahead.
4. npm asks you to approve **each upload** in the browser: when it prints
   `Press ENTER to open in the browser...`, press Enter and approve.
5. At the end it prints the link. Every link you publish is also saved in `npm\links.txt`.

Without the menu (e.g. for a script):

```bash
powershell -ExecutionPolicy Bypass -File npm-publish.ps1 -Choice 1
powershell -ExecutionPolicy Bypass -File npm-publish.ps1 -Choice 2 -DryRun   # build and show the link, publish nothing
powershell -ExecutionPolicy Bypass -File build-npm.ps1 -Name my-package -SvgName my-page.svg -Publish
```

### jsDelivr's limits, and how they're handled

jsDelivr serves files up to **50 MB** and npm packages up to **150 MB**. So a publish is split:

- **The page package** (`nebula-flux` or a random name) holds one `.svg` under 48 MB: the page
  and the smaller games. This is the only thing uploaded again on each publish.
- **Data packs** hold the bigger games. They are npm packages with random names, each under
  148 MB with every file under 48 MB, and as many as needed.
  **Each data pack is uploaded once and never again**, and every link uses the same packs:
  blocks are found by a hash of their content, so a later build (under any name) reuses what's
  already uploaded. Only a game that's new or changed goes into a new pack.
  `npm\packs\registry.json` records which block is in which pack. Packs still to be uploaded wait
  in `npm\packs\<name>\`; once uploaded, their local copy is deleted.
- Opening a big game downloads its data pack files from jsDelivr, then unpacks them. So these
  copies have to be opened from the jsDelivr link, not from disk (use `single-file.svg` for that).

Games in this PC's local list (`games.local.json`) are never published. To leave a game out of
npm only, add its id to `$leaveOut` near the top of `build-npm.ps1`.

### Older links update themselves

Every page published this way checks `latest.json` in this GitHub repo when it opens (through
jsDelivr and raw.githubusercontent.com, whichever answer is newer). If a newer build was
published, under any package name, it switches to that link and keeps the open game.

After publishing, `build-npm.ps1` waits until jsDelivr serves the new link (so older links never
jump to a 404), commits and pushes **only** `latest.json`, and clears jsDelivr's cache of it.
If that step timed out, finish it later:

```bash
powershell -ExecutionPolicy Bypass -File build-npm.ps1 -Name nebula-flux -UpdateLatest
```

Versions published before this existed (nebula-flux 1.0.0 to 1.0.2, quantum-pancake,
cosmic-hedgehog, mighty-acorn) keep working but don't switch to newer builds.

## 9. Files that stay on your PC

`.gitignore` keeps these out of the GitHub repo:

| What | Why |
|---|---|
| `single-file.html`, `single-file.svg`, `.svg-cache\`, `npm\` | build output (big, rebuilt any time) |
| `games/custom/games.local.json` | games added with `-Local` |
| `build-svg.ps1`, `build-npm.ps1`, `npm-publish.ps1`, `NPM-PUBLISH.bat` | the `.svg` and npm tools are kept on this PC only |

So a fresh clone of the repo has the website, Add Game, PUSH REPO and `build.ps1`, but not the
`.svg` / npm tools; copy those four files over from this PC to use them elsewhere.

## 10. Troubleshooting

| Problem | Fix |
|---|---|
| `npm error code EOTP` | npm wants your approval: run `NPM-PUBLISH.bat` in a normal window and press Enter at "Press ENTER to open in the browser", then approve. |
| `npm error 404` on a new package | Normal: it just means the name is free. |
| jsDelivr shows 404 right after publishing | npm is still processing the package; wait a few minutes. |
| jsDelivr: "File size exceeded the configured limit of 50 MB" | A file is over 50 MB: publish with `NPM-PUBLISH.bat`, which keeps every file under 48 MB. |
| jsDelivr: "Package size exceeded the configured limit of 150 MB" | Same: `NPM-PUBLISH.bat` keeps every package under 148 MB. |
| `.svg` game says "Could not load this game" | A split/npm copy was opened from disk, or its data pack isn't on jsDelivr yet. |
| PUSH REPO: "Couldn't combine them with yours automatically" | The same file was changed on GitHub and here. Resolve it with git, then run PUSH REPO again. |
| PUSH REPO: push failed | No internet, not signed in to GitHub, or a file over 100 MB. |
| Build says "Python not found: using gzip" | Install Python 3 for the smaller LZMA build (optional). |

## 11. Credits and licenses

- **Subway Roller** was made for this site.
- **Hosted games** (`games/play/`) are open source; each folder keeps its license file, and the
  site's footer lists them under "Game credits".
- **Papa's games** come from Flipline Studios' free-games-for-your-site packages.
- **Ruffle** (Flash player): MIT / Apache-2.0. **three.js**: MIT.
- Games added with Add Game belong to their makers; make sure you're allowed to share them.
