import 'dart:convert';

import 'package:testeador_base/src/mirador/brushes.dart';

/// El catálogo de pinceles tal como lo consume la página. Una sola fuente de
/// verdad: la UI no repite colores ni teclas, los lee de acá.
List<Map<String, Object?>> brushCatalogJson() => [
  for (final b in kBrushes)
    {
      'key': b.key,
      'id': b.id,
      'label': b.label,
      'color': b.color,
      'verdict': b.verdict.wire,
      'instruction': b.instruction,
    },
];

/// La página del panel. Autocontenida: sin CDN, sin fuentes remotas.
String miradorHtml() => _html.replaceFirst(
  '/*__PRECEDENCE__*/',
  jsonEncode(const [
    'fix_test',
    'fix_code',
    'variants',
    'explain',
    'replace_baseline',
  ]),
);

const String _html = r'''
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>mirador — supervisión visual</title>
<style>
  :root {
    --bg: #14120e; --panel: #1d1a15; --line: #322c22; --ink: #ece5d6;
    --dim: #a09883; --gold: #c9a227; --red: #d92d20; --green: #2e9e5b;
  }
  @media (prefers-color-scheme: light) {
    :root {
      --bg: #f5f1e6; --panel: #fffdf6; --line: #ded5c0; --ink: #2b2418;
      --dim: #6e6553; --gold: #9a7b12;
    }
  }
  * { box-sizing: border-box; }
  html, body { height: 100%; margin: 0; }
  body {
    display: flex; background: var(--bg); color: var(--ink);
    font: 13px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  aside {
    width: 290px; flex: 0 0 290px; border-right: 1px solid var(--line);
    display: flex; flex-direction: column; background: var(--panel);
  }
  aside header { padding: 10px 12px; border-bottom: 1px solid var(--line); }
  aside h1 { margin: 0; font-size: 13px; letter-spacing: .12em; text-transform: uppercase; color: var(--gold); }
  aside .sub { color: var(--dim); font-size: 11px; margin-top: 2px; }
  #queue { flex: 1; overflow: auto; }
  .item {
    padding: 8px 12px; border-bottom: 1px solid var(--line); cursor: pointer;
    display: grid; grid-template-columns: 34px 1fr; gap: 8px; align-items: start;
  }
  .item:hover { background: #ffffff0a; }
  .item.sel { background: #ffffff14; box-shadow: inset 3px 0 0 var(--gold); }
  .marks { color: var(--red); font-weight: 700; letter-spacing: -1px; }
  .item .slug { font-weight: 600; }
  .item .meta { color: var(--dim); font-size: 11px; }
  .item .vd { font-size: 11px; margin-top: 2px; }
  .badge { display: inline-block; padding: 0 4px; border: 1px solid currentColor; border-radius: 2px; font-size: 10px; }
  .done { opacity: .55; }
  main { flex: 1; display: flex; flex-direction: column; min-width: 0; }
  #bar {
    padding: 8px 12px; border-bottom: 1px solid var(--line); display: flex;
    gap: 12px; align-items: center; flex-wrap: wrap; background: var(--panel);
  }
  #bar .grow { flex: 1; }
  #intent {
    flex: 1 1 260px; min-width: 0; color: var(--dim);
    display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
    overflow: hidden;
  }
  #stage { flex: 1; overflow: auto; position: relative; display: grid; place-items: start center; padding: 14px; }
  #wrap { position: relative; line-height: 0; }
  #wrap img { max-width: 100%; height: auto; display: block; }
  #cv { position: absolute; inset: 0; width: 100%; height: 100%; cursor: crosshair; touch-action: none; }
  #prevImg { position: absolute; inset: 0; width: 100%; height: auto; }
  #clip { position: absolute; inset: 0; overflow: hidden; }
  #palette { display: flex; gap: 4px; flex-wrap: wrap; padding: 8px 12px; border-top: 1px solid var(--line); background: var(--panel); }
  .brush {
    display: flex; align-items: center; gap: 5px; padding: 3px 7px;
    border: 1px solid var(--line); border-radius: 3px; cursor: pointer; font-size: 11px;
  }
  .brush.on { border-color: var(--ink); background: #ffffff14; }
  .dot { width: 9px; height: 9px; border-radius: 50%; }
  kbd {
    border: 1px solid var(--line); border-bottom-width: 2px; border-radius: 3px;
    padding: 0 4px; font: inherit; font-size: 10px; color: var(--dim);
  }
  button {
    font: inherit; color: var(--ink); background: transparent; cursor: pointer;
    border: 1px solid var(--line); border-radius: 3px; padding: 4px 9px;
  }
  button:hover { border-color: var(--ink); }
  button.primary { border-color: var(--gold); color: var(--gold); }
  textarea {
    width: 100%; background: var(--bg); color: var(--ink); border: 1px solid var(--line);
    border-radius: 3px; padding: 6px; font: inherit; resize: vertical;
  }
  #notes { padding: 8px 12px; border-top: 1px solid var(--line); background: var(--panel); display: grid; gap: 6px; }
  #notes label { color: var(--dim); font-size: 11px; }
  #help {
    position: fixed; inset: 0; background: #000000d0; display: none; place-items: center; padding: 24px; z-index: 9;
  }
  #help.on { display: grid; }
  #help div { background: var(--panel); border: 1px solid var(--line); padding: 18px 22px; max-width: 620px; }
  #help table { border-collapse: collapse; }
  #help td { padding: 2px 10px 2px 0; vertical-align: top; }
  #toast {
    position: fixed; bottom: 14px; left: 50%; transform: translateX(-50%);
    background: var(--panel); border: 1px solid var(--gold); color: var(--gold);
    padding: 8px 14px; border-radius: 3px; display: none;
  }
  #toast.on { display: block; }
  .empty { padding: 40px; color: var(--dim); text-align: center; }
  #strip { display: flex; gap: 8px; align-items: flex-start; }
  #strip figure { margin: 0; flex: 1 1 0; min-width: 0; cursor: pointer; }
  #strip img { width: 100%; height: auto; display: block; border: 2px solid transparent; }
  #strip figcaption { padding: 4px 0; color: var(--dim); text-align: center; }
  #strip .on img { border-color: var(--gold); }
  #strip .on figcaption { color: var(--gold); }

  /* Paneles angostos (el panel lateral del IDE, media pantalla): la cola pasa
     arriba en una tira, los controles se compactan y el resto es la imagen —
     que es lo único que no se puede achicar sin perder el sentido. */
  @media (max-width: 1000px) {
    body { flex-direction: column; }
    aside {
      width: 100%; flex: 0 0 auto; max-height: 26vh;
      border-right: 0; border-bottom: 1px solid var(--line);
    }
    aside header { padding: 6px 10px; }
    #queue { display: flex; overflow-x: auto; }
    .item {
      grid-template-columns: 1fr; gap: 2px; min-width: 132px;
      border-bottom: 0; border-right: 1px solid var(--line);
    }
    .item .meta { display: none; }
    #bar { gap: 6px; padding: 6px 10px; }
    #bar button { padding: 3px 6px; }
    #bar kbd { display: none; }
    #intent { flex-basis: 100%; -webkit-line-clamp: 3; }
    #stage { padding: 6px; min-height: 45vh; }
    #notes { padding: 6px 10px; }
    #notes textarea { rows: 1; }
    #palette { gap: 3px; padding: 6px 10px; }
    .brush { padding: 2px 5px; }
  }
</style>
</head>
<body>
<aside>
  <header>
    <h1>mirador</h1>
    <div class="sub" id="sub">cargando…</div>
  </header>
  <div id="queue"></div>
</aside>

<main>
  <div id="bar">
    <strong id="title">—</strong>
    <span class="meta" id="intent"></span>
    <span class="grow"></span>
    <span id="viewName" class="meta"></span>
    <button onclick="cycleView()">vista <kbd>D</kbd></button>
    <button onclick="setDecision('accept')">aceptar <kbd>A</kbd></button>
    <button onclick="setDecision('reject')">rechazar <kbd>R</kbd></button>
    <button onclick="setDecision('variants')">variantes <kbd>V</kbd></button>
    <button class="primary" onclick="send()">enviar <kbd>⏎</kbd></button>
    <button onclick="toggleHelp()"><kbd>?</kbd></button>
  </div>

  <div id="stage">
    <div id="wrap">
      <div id="clip"><img id="prevImg" alt=""></div>
      <img id="img" alt="">
      <canvas id="cv"></canvas>
    </div>
    <div id="strip" style="display:none"></div>
    <div class="empty" id="empty" style="display:none">Sin capturas para revisar.</div>
  </div>

  <div id="palette"></div>
  <div id="notes">
    <label>Instrucciones para esta captura</label>
    <textarea id="note" rows="2" placeholder="lo que quieras aclarar sobre esta pantalla…"></textarea>
    <label>Instrucciones de la ronda (van con todo el veredicto)</label>
    <textarea id="roundNote" rows="2" placeholder="algo que aplique a todo el cambio…"></textarea>
  </div>
</main>

<div id="help" onclick="toggleHelp()"><div>
  <h3 style="margin-top:0">Teclas</h3>
  <table>
    <tr><td><kbd>1</kbd>…<kbd>0</kbd></td><td>elegir pincel</td></tr>
    <tr><td><kbd>Tab</kbd></td><td>ciclar pincel</td></tr>
    <tr><td><kbd>+</kbd> <kbd>-</kbd></td><td>grosor</td></tr>
    <tr><td><kbd>U</kbd> / <kbd>⇧U</kbd></td><td>deshacer trazo / limpiar</td></tr>
    <tr><td><kbd>←</kbd> <kbd>→</kbd></td><td>captura anterior / siguiente</td></tr>
    <tr><td><kbd>D</kbd></td><td>vista: nueva → previa → A/B → overlay → tríptico</td></tr>
    <tr><td><kbd>A</kbd></td><td>aceptar lo propuesto para esta captura</td></tr>
    <tr><td><kbd>R</kbd></td><td>rechazar / revertir el cambio</td></tr>
    <tr><td><kbd>V</kbd></td><td>pedir 3 variantes de la captura entera</td></tr>
    <tr><td><kbd>⏎</kbd></td><td>enviar el veredicto</td></tr>
  </table>
  <p style="color:var(--dim)">Doble click sobre un trazo para anotarlo. Si una captura
  tiene marcas de varios pinceles, manda el de mayor precedencia:
  el test miente › arreglar › variantes › explicar › aprobar.</p>
</div></div>
<div id="toast"></div>

<script>
const PRECEDENCE = /*__PRECEDENCE__*/;
const VIEWS = ['nueva', 'previa', 'A/B', 'overlay', 'tríptico'];
let BRUSHES = [], ITEMS = [], STATE = [], cur = 0, brushIx = 1, width = 6, view = 0;
let strokes = [], drawing = null, split = 0.5;

const $ = (id) => document.getElementById(id);
const item = () => ITEMS[cur];
const st = () => STATE[cur];

function toast(msg) {
  const t = $('toast'); t.textContent = msg; t.classList.add('on');
  setTimeout(() => t.classList.remove('on'), 2200);
}

async function boot() {
  const r = await fetch('/queue');
  const data = await r.json();
  BRUSHES = data.brushes;
  ITEMS = data.items;
  STATE = ITEMS.map((i) => ({ decision: null, marks: [], note: '', chosen: null }));
  $('sub').textContent = ITEMS.length + ' captura(s) · ordenadas por severidad';
  renderPalette();
  renderQueue();
  if (!ITEMS.length) {
    $('empty').style.display = 'block';
    $('wrap').style.display = 'none';
    return;
  }
  select(0);
}

function renderPalette() {
  $('palette').innerHTML = BRUSHES.map((b, i) =>
    '<span class="brush' + (i === brushIx ? ' on' : '') + '" onclick="pick(' + i + ')" title="' +
    b.instruction.replace(/"/g, '&quot;') + '">' +
    '<span class="dot" style="background:' + b.color + '"></span>' + b.label +
    ' <kbd>' + b.key + '</kbd></span>').join('');
}

function renderQueue() {
  $('queue').innerHTML = ITEMS.map((it, i) => {
    const s = STATE[i];
    const decided = s.decision || s.marks.length;
    const vd = s.marks.length ? verdictOf(s.marks)
      : s.decision === 'accept' ? it.proposedVerdict
      : s.decision === 'reject' ? 'fix_code'
      : s.decision === 'variant' ? 'variants ' + roman(s.chosen + 1)
      : s.decision === 'variants' ? 'variants'
      : it.proposedVerdict;
    return '<div class="item' + (i === cur ? ' sel' : '') + (decided ? ' done' : '') +
      '" onclick="select(' + i + ')">' +
      '<div class="marks">' + ('!'.repeat(it.marks) || (it.isNew ? '~new' : '·')) + '</div>' +
      '<div><div class="slug">' + esc(it.slug) + '</div>' +
      '<div class="meta">' + esc(it.scenario) + ' · ' + esc(it.actor) +
      (it.status !== 'ok' ? ' · <span style="color:var(--red)">' + it.status + '</span>' : '') + '</div>' +
      '<div class="vd"><span class="badge">' + esc(vd || '?') + '</span>' +
      (decided ? ' <span style="color:var(--green)">✓</span>' : '') + '</div></div></div>';
  }).join('');
}

function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"]/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
}

function shotUrl(path) { return '/shot?p=' + encodeURIComponent(path); }

function select(i) {
  if (i < 0 || i >= ITEMS.length) return;
  if (ITEMS[cur]) st().note = $('note').value;
  cur = i;
  strokes = st().marks.slice();
  const it = item();
  $('title').textContent = it.scenario + ' / ' + it.actor + ' / ' + it.slug;
  $('intent').textContent = it.intent ? '“' + it.intent + '”' : '(sin intent declarado)';
  $('note').value = st().note || '';
  if (it.variants && it.variants.length) {
    renderStrip(it);
  } else {
    $('strip').style.display = 'none';
    $('wrap').style.display = '';
    view = it.diff ? 4 : 0;
    applyView();
  }
  renderQueue();
}

// Modo variantes: las alternativas ya implementadas y capturadas, lado a lado.
// Se elige con 1/2/3 (o click); 0 descarta las tres y pide otra vuelta.
function renderStrip(it) {
  $('wrap').style.display = 'none';
  const strip = $('strip');
  strip.style.display = 'flex';
  strip.innerHTML = it.variants.map((v, i) =>
    '<figure class="' + (st().chosen === i ? 'on' : '') + '" onclick="chooseVariant(' + i + ')">' +
    '<img src="' + shotUrl(v) + '" alt="">' +
    '<figcaption>' + roman(i + 1) + ' · ' + esc(v.split('/').pop()) +
    ' <kbd>' + (i + 1) + '</kbd></figcaption></figure>').join('');
  $('viewName').textContent = it.variants.length + ' variante(s) · elegí con ' +
    it.variants.map((_, i) => i + 1).join('/') + ', 0 = ninguna';
}

function roman(n) { return ['I', 'II', 'III', 'IV', 'V'][n - 1] || String(n); }

function chooseVariant(i) {
  const it = item();
  if (!it.variants || !it.variants.length) return;
  st().chosen = i;
  st().decision = 'variant';
  renderStrip(it);
  renderQueue();
  toast('elegiste la variante ' + roman(i + 1));
}

function applyView() {
  const it = item();
  const name = VIEWS[view];
  $('viewName').textContent = name + (it.marks ? ' · ' + (it.ratio * 100).toFixed(2) + '% distinto' : '');
  const img = $('img'), prev = $('prevImg'), clip = $('clip');
  clip.style.display = 'none'; prev.style.opacity = '1'; img.style.opacity = '1';
  const main = { 'nueva': it.capture, 'previa': it.baseline || it.capture,
                 'A/B': it.capture, 'overlay': it.capture, 'tríptico': it.diff || it.capture }[name];
  img.src = shotUrl(main);
  img.onload = () => sizeCanvas();
  if (name === 'A/B' && it.baseline) {
    clip.style.display = 'block';
    prev.src = shotUrl(it.baseline);
    clip.style.width = (split * 100) + '%';
  } else if (name === 'overlay' && it.baseline) {
    clip.style.display = 'block';
    clip.style.width = '100%';
    prev.src = shotUrl(it.baseline);
    prev.style.opacity = '0.5';
  }
}

function sizeCanvas() {
  const img = $('img'), cv = $('cv');
  cv.width = img.naturalWidth; cv.height = img.naturalHeight;
  redraw();
}

function cycleView() { view = (view + 1) % VIEWS.length; applyView(); }

function pick(i) { brushIx = i; renderPalette(); }

// Coordenadas de IMAGEN, no de pantalla: el veredicto tiene que seguir siendo
// válido con cualquier zoom o tamaño de ventana.
function toImage(ev) {
  const cv = $('cv'), r = cv.getBoundingClientRect();
  return [ (ev.clientX - r.left) * (cv.width / r.width),
           (ev.clientY - r.top) * (cv.height / r.height) ];
}

$('cv').addEventListener('pointerdown', (ev) => {
  if (!ITEMS.length) return;
  $('cv').setPointerCapture(ev.pointerId);
  drawing = { brush: BRUSHES[brushIx].id, points: [toImage(ev)], width };
});
$('cv').addEventListener('pointermove', (ev) => {
  if (!drawing) return;
  drawing.points.push(toImage(ev));
  redraw();
});
$('cv').addEventListener('pointerup', () => {
  if (!drawing) return;
  if (drawing.points.length === 1) drawing.points.push(drawing.points[0]);
  strokes.push(drawing);
  st().marks = strokes.slice();
  drawing = null;
  redraw(); renderQueue();
});
$('cv').addEventListener('dblclick', (ev) => {
  const at = toImage(ev);
  const hit = strokes.slice().reverse().find((s) =>
    s.points.some((p) => Math.hypot(p[0] - at[0], p[1] - at[1]) < 30));
  if (!hit) return;
  const note = prompt('Nota para este trazo:', hit.note || '');
  if (note !== null) { hit.note = note; st().marks = strokes.slice(); redraw(); }
});

function redraw() {
  const cv = $('cv'), g = cv.getContext('2d');
  g.clearRect(0, 0, cv.width, cv.height);
  const all = drawing ? strokes.concat([drawing]) : strokes;
  for (const s of all) {
    const b = BRUSHES.find((x) => x.id === s.brush) || BRUSHES[0];
    g.strokeStyle = b.color; g.lineWidth = s.width || width;
    g.lineJoin = 'round'; g.lineCap = 'round';
    g.beginPath();
    s.points.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1]));
    g.stroke();
    if (s.brush === 'mover' && s.points.length > 1) arrowHead(g, s, b.color);
    if (s.note) {
      g.fillStyle = b.color;
      g.font = (14 * (cv.width / 900)).toFixed(0) + 'px sans-serif';
      g.fillText('✎ ' + s.note, s.points[0][0] + 8, s.points[0][1] - 8);
    }
  }
}

function arrowHead(g, s, color) {
  const n = s.points.length, a = s.points[n - 2], b = s.points[n - 1];
  const ang = Math.atan2(b[1] - a[1], b[0] - a[0]), L = 18;
  g.fillStyle = color; g.beginPath(); g.moveTo(b[0], b[1]);
  g.lineTo(b[0] - L * Math.cos(ang - 0.4), b[1] - L * Math.sin(ang - 0.4));
  g.lineTo(b[0] - L * Math.cos(ang + 0.4), b[1] - L * Math.sin(ang + 0.4));
  g.closePath(); g.fill();
}

function verdictOf(marks) {
  const vs = marks.map((m) => (BRUSHES.find((b) => b.id === m.brush) || {}).verdict);
  for (const v of PRECEDENCE) if (vs.includes(v)) return v;
  return 'inconclusive';
}

function setDecision(kind) {
  if (!ITEMS.length) return;
  st().decision = kind;
  renderQueue();
  toast(kind === 'accept' ? 'aceptado lo propuesto'
      : kind === 'reject' ? 'rechazado: se revierte'
      : 'se piden 3 variantes');
  if (cur + 1 < ITEMS.length) select(cur + 1);
}

async function send() {
  if (ITEMS.length) st().note = $('note').value;
  const decisions = ITEMS.map((it, i) => {
    const s = STATE[i];
    let verdict, judgedBy = 'human', rationale;
    if (s.marks.length) {
      verdict = verdictOf(s.marks);
      rationale = s.marks.map((m) => {
        const b = BRUSHES.find((x) => x.id === m.brush) || {};
        return b.label + (m.note ? ': ' + m.note : '');
      }).join(' · ');
    } else if (s.decision === 'reject') {
      verdict = 'fix_code'; rationale = 'Rechazado en el panel: revertir el cambio.';
    } else if (s.decision === 'variants') {
      verdict = 'variants'; rationale = 'Se piden 3 variantes de esta pantalla.';
    } else if (s.decision === 'variant' && s.chosen != null) {
      verdict = 'variants';
      rationale = 'Elegida la variante ' + roman(s.chosen + 1) + ' de ' +
        it.variants.length + '.';
    } else if (s.decision === 'accept') {
      verdict = it.proposedVerdict; judgedBy = 'agent';
      rationale = it.rationale || 'Aceptado en bloque lo propuesto.';
    } else {
      return null;
    }
    return {
      scenario: it.scenario, actor: it.actor, slug: it.slug,
      capture: it.capture ? it.capture.split('/').pop() : null,
      verdict, rationale, judgedBy,
      marks: s.marks.map((m) => ({
        brush: m.brush, note: m.note || null,
        rect: bounds(m.points), points: m.points,
      })),
      note: s.note || null,
      chosenVariant: (s.chosen != null && it.variants && it.variants[s.chosen])
        ? it.variants[s.chosen].split('/').pop() : null,
    };
  }).filter(Boolean);

  if (!decisions.length) { toast('nada decidido todavía'); return; }
  const res = await fetch('/verdict', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ decisions, roundNote: $('roundNote').value || null }),
  });
  if (res.ok) {
    document.body.innerHTML =
      '<div class="empty" style="margin:auto">Veredicto enviado: ' + decisions.length +
      ' captura(s).<br>Podés cerrar esta pestaña.</div>';
  } else {
    toast('falló el envío (' + res.status + ')');
  }
}

function bounds(pts) {
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
  const x = Math.min(...xs), y = Math.min(...ys);
  return [x, y, Math.max(...xs) - x, Math.max(...ys) - y];
}

function toggleHelp() { $('help').classList.toggle('on'); }

addEventListener('keydown', (ev) => {
  if (ev.target.tagName === 'TEXTAREA') return;
  const k = ev.key;
  const vs = (item() && item().variants) || [];
  if (vs.length) {
    if (k === '0') {
      st().chosen = null; st().decision = 'variants';
      renderQueue(); toast('ninguna: se piden otras');
      ev.preventDefault(); return;
    }
    const n = parseInt(k, 10);
    if (n >= 1 && n <= vs.length) {
      chooseVariant(n - 1); ev.preventDefault(); return;
    }
  }
  const bi = BRUSHES.findIndex((b) => b.key === k);
  if (bi >= 0) { pick(bi); ev.preventDefault(); return; }
  if (k === 'Tab') { pick((brushIx + 1) % BRUSHES.length); ev.preventDefault(); return; }
  if (k === '+' || k === '=') { width = Math.min(40, width + 2); toast('grosor ' + width); return; }
  if (k === '-') { width = Math.max(2, width - 2); toast('grosor ' + width); return; }
  if (k === 'u') { strokes.pop(); st().marks = strokes.slice(); redraw(); renderQueue(); return; }
  if (k === 'U') { strokes = []; st().marks = []; redraw(); renderQueue(); return; }
  if (k === 'ArrowLeft') { select(cur - 1); return; }
  if (k === 'ArrowRight') { select(cur + 1); return; }
  if (k === 'd' || k === 'D') { cycleView(); return; }
  if (k === 'a' || k === 'A') { setDecision('accept'); return; }
  if (k === 'r' || k === 'R') { setDecision('reject'); return; }
  if (k === 'v' || k === 'V') { setDecision('variants'); return; }
  if (k === 'Enter') { send(); return; }
  if (k === '?') { toggleHelp(); return; }
});

boot();
</script>
</body>
</html>
''';
