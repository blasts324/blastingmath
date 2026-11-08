(() => {
'use strict';
const $ = s => document.querySelector(s);
const $$ = s => Array.prototype.slice.call(document.querySelectorAll(s));
let GAMES = window.GAMES || [];
let byId = {};
let CATS = ['All']; // filled in from the games once they're loaded
const FEATURED = { id: 'subway-roller', t: 'Subway Roller', c: 'Featured', d: 'Roll down the rails, dodge trams and grab sparks. Arrow keys or swipe.', src: window.FEATURED_SRC || 'games/subway-roller/index.html' }; // FEATURED_SRC is set in the single-file build
const SITE = 'Subway Roller Unblocked';

const store = {
  get(k, d){ try { const v = localStorage.getItem('hub.' + k); return v === null ? d : JSON.parse(v); } catch(e){ return d; } },
  set(k, v){ try { localStorage.setItem('hub.' + k, JSON.stringify(v)); } catch(e){} }
};
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* ---------- views: home and all games ---------- */
let view = 'home';
function setView(v, push){
  view = v;
  $('#viewHome').hidden = v !== 'home';
  $('#viewGames').hidden = v !== 'games';
  $$('.tab').forEach(b => b.classList.toggle('on', b.dataset.go === v));
  $$('.rail-btn').forEach(b => {
    const g = b.dataset.go;
    b.classList.toggle('on', v === 'home' ? g === 'home' : (g === 'games' && cat === 'All') || g === 'cat:' + cat);
  });
  $('#addrScheme').textContent = 'roller://' + (v === 'home' ? 'home' : cat === 'All' ? 'games' : 'games/' + cat.toLowerCase().replace(/\s+/g, '-'));
  if (push) history.pushState(null, '', v === 'home' ? location.pathname + location.search : '#games');
  window.scrollTo(0, 0);
}
function go(target){
  if (target === 'home') return setView('home', view !== 'home');
  if (target === 'games') { cat = 'All'; query = ''; $('#q').value = ''; renderCats(); renderGrid(); return setView('games', view !== 'games'); }
  if (target === 'random') return GAMES.length && openGame(GAMES[Math.random() * GAMES.length | 0].id);
  if (target === 'featured') return openGame(FEATURED.id);
  if (target === 'credits') {
    const d = $('#creditsDetails'); d.open = true;
    return $('#creditsBox').scrollIntoView({ behavior: 'smooth' });
  }
  if (target.indexOf('cat:') === 0) {
    cat = target.slice(4); query = ''; $('#q').value = '';
    renderCats(); renderGrid();
    return setView('games', view !== 'games');
  }
}
document.addEventListener('click', e => {
  const b = e.target.closest('[data-go]');
  if (b) { e.preventDefault(); go(b.dataset.go); }
});

/* ---------- game list ---------- */
let cat = 'All', query = '', sort = 'new';
let counts = {};

function tile(g){
  return `<button type="button" class="tile" data-id="${esc(g.id)}">
    ${g.img ? `<img src="${esc(g.img)}" alt="" loading="lazy" decoding="async" data-l="${esc(g.t[0])}">` : `<span class="noimg">${esc(g.t[0])}</span>`}
    <strong>${esc(g.t)}</strong><small>${esc(g.c)}</small>
  </button>`;
}
function recentGames(){ return store.get('recent', []).map(id => id === FEATURED.id ? FEATURED : byId[id]).filter(Boolean); }
function renderCats(){
  const r = recentGames().length;
  const items = CATS.filter(c => counts[c]).concat(r ? ['Recent'] : []);
  if (cat === 'Recent' && !r) cat = 'All';
  $('#catStrip').innerHTML = items.map(c =>
    `<button type="button" data-cat="${esc(c)}" aria-current="${c === cat}">${c === 'All' ? 'All games' : esc(c)}<span>${c === 'Recent' ? r : counts[c]}</span></button>`).join('');
}
const plain = s => String(s).toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();  // "Papa's" matches "papas" and "papa s"
function renderGrid(){
  const q = plain(query), qs = q.replace(/ /g, '');
  let list = cat === 'Recent' ? recentGames()
    : GAMES.filter(g => (cat === 'All' || g.c === cat) && (!q || plain(g.t).includes(q) || plain(g.t).replace(/ /g, '').includes(qs)));
  if (sort === 'az') list = list.slice().sort((a, b) => a.t.localeCompare(b.t));
  $('#grid').innerHTML = list.map(tile).join('');
  $('#listTitle').textContent = q ? `Results for "${query.trim()}"` : cat === 'All' ? 'All games' : cat === 'Recent' ? 'Recently played' : /games$/i.test(cat) ? cat : cat + ' games';
  $('#count').textContent = list.length + (list.length === 1 ? ' game' : ' games');
  $('#empty').hidden = list.length > 0;
}
function renderHome(){
  // newest first: your own games, then the newest hosted ones
  $('#homeGrid').innerHTML = GAMES.slice(0, 12).map(tile).join('');
  $('#gameCount').textContent = GAMES.length + 1;  // + Subway Roller
  $('#flashCount').textContent = counts.Flash || 0;
  $('#qaMine').hidden = !counts['My Games'];
  $$('.rail-btn[data-go="cat:My Games"]').forEach(b => { b.hidden = !counts['My Games']; });
}
// broken thumbnails: swap in a plain letter block
document.addEventListener('error', e => {
  const img = e.target;
  if (!img || img.tagName !== 'IMG' || !img.closest('.tile')) return;
  const d = document.createElement('span'); d.className = 'noimg'; d.textContent = img.dataset.l || '?';
  img.replaceWith(d);
}, true);

$('#catStrip').addEventListener('click', e => {
  const b = e.target.closest('[data-cat]'); if (!b) return;
  cat = b.dataset.cat; query = ''; $('#q').value = '';
  renderCats(); renderGrid(); setView('games', false);
});
$('#sort').addEventListener('change', e => { sort = e.target.value; renderGrid(); });

/* ---------- search (top bar and the big one on Home) ---------- */
let qTimer;
function search(text){
  query = text;
  if (cat !== 'All') { cat = 'All'; renderCats(); }
  renderGrid();
  if (view !== 'games') setView('games', true);
}
$('#q').addEventListener('input', e => {
  clearTimeout(qTimer);
  qTimer = setTimeout(() => search(e.target.value), 120);
});
$('#heroSearch').addEventListener('submit', () => {
  const v = $('#hq').value.trim();
  $('#q').value = v; search(v);
  $('#q').focus();
});
$('#randomBtn').onclick = () => go('random');
$('#fsPage').onclick = () => document.fullscreenElement ? document.exitFullscreen() : fullscreen(document.documentElement);

/* ---------- clock ---------- */
function tick(){
  const d = new Date();
  $('#clockTime').textContent = d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  $('#clockDate').textContent = d.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
}
tick(); setInterval(tick, 1000);

/* ---------- recently played ---------- */
function pushRecent(id){
  const r = store.get('recent', []).filter(x => x !== id);
  r.unshift(id); store.set('recent', r.slice(0, 12)); renderRecent();
}
function renderRecent(){
  const r = recentGames();
  $('#recentWrap').hidden = r.length === 0;
  $('#recent').innerHTML = r.map(tile).join('');
}
$('#clearRecent').onclick = () => { store.set('recent', []); renderRecent(); renderCats(); if (cat === 'Recent') renderGrid(); };

/* ---------- player (every game, Subway Roller too) ---------- */
const player = $('#player'), pFrame = $('#pFrame');
let current = null;
function fullscreen(el){
  const fn = el.requestFullscreen || el.webkitRequestFullscreen;
  if (fn) { const p = fn.call(el); if (p && p.catch) p.catch(() => {}); }
}
function openGame(id, fromHash){
  const g = id === FEATURED.id ? FEATURED : byId[id]; if (!g) return;
  current = g;
  $('#pTitle').textContent = g.t; $('#pCat').textContent = g.c;
  $('#pDesc').innerHTML = esc(g.d || '') + (g.by ? ` <span class="by">By ${esc(g.by)} · ${esc(g.license)} · <a href="${esc(g.home)}" target="_blank" rel="noopener">source</a></span>` : '');
  pFrame.src = g.src;
  player.hidden = false; document.body.style.overflow = 'hidden';
  pushRecent(g.id);
  document.title = g.t + ' - ' + SITE;
  if (!fromHash) history.pushState(null, '', '#game=' + g.id);
  setTimeout(() => pFrame.focus(), 50);
}
function closeGame(fromHash){
  if (player.hidden) return;
  player.hidden = true; pFrame.src = 'about:blank'; document.body.style.overflow = '';
  current = null;
  document.title = SITE;
  if (!fromHash && location.hash.startsWith('#game=')) history.pushState(null, '', view === 'games' ? '#games' : location.pathname + location.search);
}
document.addEventListener('click', e => {
  const t = e.target.closest('.tile');
  if (t) openGame(t.dataset.id);
});
$('#cover').addEventListener('click', () => openGame(FEATURED.id));
$('#playFeatured').addEventListener('click', () => openGame(FEATURED.id));
$('#closePlayer').onclick = () => closeGame();
$('#reloadPlayer').onclick = () => { if (current) pFrame.src = current.src; };
$('#fsPlayer').onclick = () => fullscreen($('.player-stage'));
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && !player.hidden && !document.fullscreenElement) closeGame();
  const typing = /^(INPUT|TEXTAREA|SELECT)$/.test((document.activeElement || {}).tagName || '');
  if (e.key === '/' && !typing && player.hidden) { e.preventDefault(); (view === 'home' ? $('#hq') : $('#q')).focus(); }
});
function fromHash(){
  const m = location.hash.match(/^#game=([\w-]+)/);
  if (m) return openGame(m[1], true);
  closeGame(true);
  if (location.hash === '#games') { if (view !== 'games') { renderGrid(); setView('games', false); } }
  else if (view !== 'home') setView('home', false);
}
window.addEventListener('popstate', fromHash);

/* ---------- your own games (added with "Add Game.bat") ---------- */
function loadCustom(){
  if (window.CUSTOM_GAMES) return Promise.resolve(window.CUSTOM_GAMES); // the single-file build has them inside
  // games.json is on the website; games.local.json only exists on the PC they were added on
  const get = f => fetch('games/custom/' + f, { cache: 'no-store' })
    .then(r => r.ok ? r.json() : [])
    .catch(() => []);
  return Promise.all([get('games.json'), get('games.local.json')]).then(([web, local]) =>
    [].concat(Array.isArray(web) ? web : [], Array.isArray(local) ? local : []));
}
loadCustom().then(list => {
  const mine = (Array.isArray(list) ? list : []).map(g => ({
    id: g.id, t: g.t, c: 'My Games', d: g.d || 'One of my own games.', src: g.src, img: g.img
  }));
  GAMES = mine.concat(GAMES);
  byId = Object.fromEntries(GAMES.map(g => [g.id, g]));
  counts = GAMES.reduce((m, g) => (m[g.c] = (m[g.c] || 0) + 1, m), { All: GAMES.length });
  const others = [...new Set(GAMES.map(g => g.c))].filter(c => c !== 'My Games').sort();
  CATS = ['All'].concat(mine.length ? ['My Games'] : [], others);
  // one line per author/license, e.g. all of Flipline's games together
  const groups = new Map();
  GAMES.filter(g => g.by).forEach(g => {
    const k = g.by + '|' + g.license + '|' + g.home;
    if (!groups.has(k)) groups.set(k, { by: g.by, license: g.license, home: g.home, titles: [] });
    groups.get(k).titles.push(g.t);
  });
  $('#credits').innerHTML = [...groups.values()].map(c =>
    `<li><b>${c.titles.map(esc).join(', ')}</b> by ${esc(c.by)}, ${esc(c.license)} (<a href="${esc(c.home)}" target="_blank" rel="noopener">${c.home.includes('github.com') ? 'source' : 'website'}</a>)</li>`).join('') +
    '<li><b>Ruffle</b> flash player, MIT / Apache-2.0 (<a href="https://github.com/ruffle-rs/ruffle" target="_blank" rel="noopener">source</a>)</li>' +
    '<li><b>three.js</b>, MIT (<a href="https://github.com/mrdoob/three.js" target="_blank" rel="noopener">source</a>)</li>';
  renderCats(); renderGrid(); renderHome(); renderRecent();
  setView(location.hash === '#games' ? 'games' : 'home', false);
  fromHash();
});
})();
