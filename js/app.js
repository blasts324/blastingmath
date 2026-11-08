(() => {
'use strict';
const $ = s => document.querySelector(s);
let GAMES = window.GAMES || [];
let byId = {};
let CATS = ['All']; // filled in from the games once they're loaded
const FEATURED = { id: 'subway-roller', t: 'Subway Roller', src: window.FEATURED_SRC || 'games/subway-roller/index.html' }; // FEATURED_SRC is set in the single-file build
const SITE = 'Subway Roller Unblocked';

const store = {
  get(k, d){ try { const v = localStorage.getItem('hub.' + k); return v === null ? d : JSON.parse(v); } catch(e){ return d; } },
  set(k, v){ try { localStorage.setItem('hub.' + k, JSON.stringify(v)); } catch(e){} }
};
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* ---------- game list ---------- */
let cat = 'All', query = '', sort = 'new';
let counts = {};

function tile(g){
  return `<button type="button" class="tile" data-id="${esc(g.id)}">
    ${g.img ? `<img src="${esc(g.img)}" alt="" loading="lazy" decoding="async" data-l="${esc(g.t[0])}">` : `<span class="noimg">${esc(g.t[0])}</span>`}
    <strong>${esc(g.t)}</strong><small>${esc(g.c)}</small>
  </button>`;
}
function renderCats(){
  const items = CATS.filter(c => counts[c]);
  $('#cats').innerHTML = items.map(c =>
    `<li><button type="button" data-cat="${esc(c)}" aria-current="${c === cat}">${c === 'All' ? 'All games' : esc(c)}<span>${counts[c]}</span></button></li>`).join('');
  $('#catStrip').innerHTML = items.map(c =>
    `<button type="button" data-cat="${esc(c)}" aria-current="${c === cat}">${c === 'All' ? 'All' : esc(c)}</button>`).join('');
}
function renderGrid(){
  const q = query.trim().toLowerCase();
  let list = GAMES.filter(g => (cat === 'All' || g.c === cat) && (!q || g.t.toLowerCase().includes(q)));
  if (sort === 'az') list = list.slice().sort((a, b) => a.t.localeCompare(b.t));
  $('#grid').innerHTML = list.map(tile).join('');
  $('#listTitle').textContent = q ? `Results for "${query.trim()}"` : cat === 'All' ? 'All games' : cat + ' games';
  $('#count').textContent = list.length + (list.length === 1 ? ' game' : ' games');
  $('#empty').hidden = list.length > 0;
}
// broken thumbnails: swap in a plain letter block
$('#grid').addEventListener('error', e => {
  const img = e.target;
  if (img.tagName !== 'IMG') return;
  const d = document.createElement('span'); d.className = 'noimg'; d.textContent = img.dataset.l || '?';
  img.replaceWith(d);
}, true);

function pickCat(e){
  const b = e.target.closest('[data-cat]'); if (!b) return;
  cat = b.dataset.cat; query = ''; $('#q').value = '';
  renderCats(); renderGrid();
  if (e.currentTarget.id === 'cats') $('#games').scrollIntoView({ behavior: 'smooth' });
}
$('#cats').addEventListener('click', pickCat);
$('#catStrip').addEventListener('click', pickCat);
$('#sort').addEventListener('change', e => { sort = e.target.value; renderGrid(); });
let qTimer;
$('#q').addEventListener('input', e => {
  clearTimeout(qTimer);
  qTimer = setTimeout(() => {
    query = e.target.value;
    if (query && cat !== 'All') { cat = 'All'; renderCats(); }
    renderGrid();
  }, 120);
});
$('#q').addEventListener('keydown', e => { if (e.key === 'Enter') $('#games').scrollIntoView({ behavior: 'smooth' }); });
$('#randomBtn').onclick = () => openGame(GAMES[Math.random() * GAMES.length | 0].id);

/* ---------- recently played ---------- */
function pushRecent(id){
  const r = store.get('recent', []).filter(x => x !== id);
  r.unshift(id); store.set('recent', r.slice(0, 8)); renderRecent();
}
function renderRecent(){
  const r = store.get('recent', []).map(id => id === FEATURED.id ? FEATURED : byId[id]).filter(Boolean);
  $('#recentWrap').hidden = r.length === 0;
  $('#recent').innerHTML = r.map(g => `<li><button type="button" data-id="${esc(g.id)}">${esc(g.t)}</button></li>`).join('');
}
$('#clearRecent').onclick = () => { store.set('recent', []); renderRecent(); };
$('#recent').addEventListener('click', e => { const b = e.target.closest('[data-id]'); if (b) openGame(b.dataset.id); });

/* ---------- featured game ---------- */
const fFrame = $('#featuredFrame');
function playFeatured(){
  if (fFrame.hidden) {
    fFrame.src = FEATURED.src; fFrame.hidden = false; $('#cover').hidden = true;
    pushRecent(FEATURED.id);
    fFrame.addEventListener('load', () => fFrame.focus(), { once: true });
  }
  fFrame.focus();
}
$('#cover').addEventListener('click', playFeatured);
$('#reloadFeatured').onclick = () => { if (fFrame.hidden) playFeatured(); else fFrame.src = FEATURED.src; };
$('#fsFeatured').onclick = () => { if (fFrame.hidden) playFeatured(); fullscreen($('#stage')); };
function fullscreen(el){
  const fn = el.requestFullscreen || el.webkitRequestFullscreen;
  if (fn) { const p = fn.call(el); if (p && p.catch) p.catch(() => {}); }
}

/* ---------- player for the other games ---------- */
const player = $('#player'), pFrame = $('#pFrame');
function openGame(id, fromHash){
  if (id === FEATURED.id) {
    closeGame();
    $('#featured').scrollIntoView({ behavior: 'smooth' });
    return playFeatured();
  }
  const g = byId[id]; if (!g) return;
  $('#pTitle').textContent = g.t; $('#pCat').textContent = g.c;
  $('#pDesc').innerHTML = esc(g.d) + (g.by ? ` <span class="by">By ${esc(g.by)} · ${esc(g.license)} · <a href="${esc(g.home)}" target="_blank" rel="noopener">source</a></span>` : '');
  pFrame.src = g.src;
  player.hidden = false; document.body.style.overflow = 'hidden';
  pushRecent(id);
  document.title = g.t + ' - ' + SITE;
  if (!fromHash) history.pushState(null, '', '#game=' + id);
  setTimeout(() => pFrame.focus(), 50);
}
function closeGame(fromHash){
  if (player.hidden) return;
  player.hidden = true; pFrame.src = 'about:blank'; document.body.style.overflow = '';
  document.title = SITE;
  if (!fromHash && location.hash.startsWith('#game=')) history.pushState(null, '', location.pathname + location.search);
}
$('#grid').addEventListener('click', e => { const t = e.target.closest('.tile'); if (t) openGame(t.dataset.id); });
$('#closePlayer').onclick = () => closeGame();
$('#fsPlayer').onclick = () => fullscreen($('.player-stage'));
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && !player.hidden && !document.fullscreenElement) closeGame();
  if (e.key === '/' && document.activeElement !== $('#q')) { e.preventDefault(); $('#q').focus(); }
});
function fromHash(){
  const m = location.hash.match(/^#game=([\w-]+)/);
  if (m) openGame(m[1], true); else closeGame(true);
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
  renderCats(); renderGrid(); renderRecent(); fromHash();
});
})();
