/* Shared Flash game page: shows the "Goofle" loading screen while the .swf downloads,
   then plays it with Ruffle (vendor/ruffle). A game page sets window.FLASH_GAME first:
     <script>window.FLASH_GAME = { swf: 'game.swf' };</script>
     <script src="../../../js/flash-player.js?raw"></script>
   Optional: root (path to the site folder, default '../../../'). */
(function () {
  'use strict';
  var cfg = window.FLASH_GAME || {};
  var root = cfg.root || '../../../';
  var swf = cfg.swf || 'game.swf';

  /* ---------- loading screen ---------- */
  var style = document.createElement('style');
  style.textContent =
    'html,body{margin:0;height:100%;background:#000;overflow:hidden}' +
    '#game{width:100%;height:100%}' +
    '#loading{position:fixed;inset:0;z-index:10;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;' +
      'background:#120f22;color:#fff;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;transition:opacity .35s}' +
    '#loading.done{opacity:0;pointer-events:none}' +
    '#loading .brand{font-size:clamp(40px,12vw,84px);font-weight:900;letter-spacing:-.02em}' +
    '#loading .bar{width:min(320px,70vw);height:10px;border-radius:5px;background:rgba(255,255,255,.12);overflow:hidden}' +
    '#loading .bar i{display:block;height:100%;width:0;background:#e8572a;border-radius:5px;transition:width .15s}' +
    '#loading .bar.wait i{width:35%;animation:slide 1.1s ease-in-out infinite alternate}' +
    '@keyframes slide{from{margin-left:0}to{margin-left:65%}}' +
    '#loading .pct{font-size:13px;color:#a59fcf;font-weight:700;letter-spacing:.08em}';
  document.head.appendChild(style);

  var screen = document.createElement('div');
  screen.id = 'loading';
  screen.innerHTML = '<div class="brand">Goofle</div><div class="bar"><i></i></div><div class="pct">LOADING</div>';
  document.body.appendChild(screen);
  var fill = screen.querySelector('.bar i'), bar = screen.querySelector('.bar'), pct = screen.querySelector('.pct');
  function show(p) {
    if (p == null) { bar.className = 'bar wait'; pct.textContent = 'LOADING'; return; }
    bar.className = 'bar'; fill.style.width = Math.round(p * 100) + '%'; pct.textContent = Math.round(p * 100) + '%';
  }
  function hide() { show(1); screen.classList.add('done'); setTimeout(function () { screen.remove(); }, 400); }
  function fail(msg) { bar.style.display = 'none'; pct.textContent = msg; }

  /* ---------- download the game with progress ---------- */
  var downloaded = (window.fetch && window.ReadableStream)
    ? fetch(swf).then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        var total = +res.headers.get('Content-Length') || 0;
        if (!res.body || !total) { show(null); return res.arrayBuffer(); }
        var reader = res.body.getReader(), got = 0, parts = [];
        return (function pump() {
          return reader.read().then(function (r) {
            if (r.done) {
              var out = new Uint8Array(got), o = 0;
              parts.forEach(function (c) { out.set(c, o); o += c.length; });
              return out.buffer;
            }
            parts.push(r.value); got += r.value.length; show(Math.min(got / total, 0.99));
            return pump();
          });
        })();
      })
    : Promise.resolve(null); // very old browser: let Ruffle fetch it

  /* ---------- Ruffle ---------- */
  window.RufflePlayer = window.RufflePlayer || {};
  window.RufflePlayer.config = {
    publicPath: root + 'vendor/ruffle/', autoplay: 'on', unmuteOverlay: 'hidden',
    splashScreen: false, letterbox: 'on',
    openUrlMode: 'confirm' // links inside a game (app store ads etc.) ask before leaving the site
  };
  var ruffleReady = new Promise(function (ok, no) {
    var s = document.createElement('script');
    s.src = root + 'vendor/ruffle/ruffle.js?raw';
    s.onload = ok; s.onerror = function () { no(new Error('Ruffle did not load')); };
    document.head.appendChild(s);
  });

  Promise.all([ruffleReady, downloaded]).then(function (res) {
    var data = res[1];
    var holder = document.getElementById('game') || document.body.appendChild(Object.assign(document.createElement('div'), { id: 'game' }));
    var player = window.RufflePlayer.newest().createPlayer();
    player.style.width = '100%'; player.style.height = '100%';
    holder.appendChild(player);
    var api = player.ruffle ? player.ruffle() : player;
    // play the bytes already downloaded; base keeps the game's own relative links working
    var opts = data ? { data: data, swfFileName: swf.split('/').pop(), base: new URL(swf, location.href).href } : { url: swf };
    var loaded = api.load(opts);
    var done = false;
    function finish() { if (!done) { done = true; hide(); } }
    player.addEventListener('loadedmetadata', finish);
    player.addEventListener('loadeddata', finish);
    if (loaded && loaded.then) loaded.then(function () { setTimeout(finish, 300); }, function () { fail('COULD NOT START THE GAME'); });
    else setTimeout(finish, 1500);
  }).catch(function (e) {
    fail('COULD NOT LOAD THE GAME');
    if (window.console) console.error(e);
  });
})();
