// Запускается только с jsdom и живым локальным сервером Neovim (без внешней сети).
const { JSDOM } = require('jsdom');
const base = process.argv[2];
const nativeFetch = global.fetch;
const origin = new URL(base).origin;
const delay = ms => new Promise(r => setTimeout(r, ms));
async function waitFor(fn, label) {
  const until = Date.now() + 6000;
  while (Date.now() < until) { if (await fn()) return; await delay(30); }
  throw new Error('timeout: ' + label);
}
(async () => {
  const html = await (await nativeFetch(base)).text();
  const dom = new JSDOM(html, {
    url: base, runScripts: 'dangerously', pretendToBeVisual: true,
    beforeParse(win) {
      win.fetch = (url, opts = {}) => nativeFetch(String(url), { ...opts, headers: { ...(opts.headers || {}), Origin: origin } });
      win.confirm = () => true;
      win.prompt = () => 'тест связи';
      win.HTMLElement.prototype.setPointerCapture = function () {};
    },
  });
  const w = dom.window, doc = w.document;
  const state = async () => (await nativeFetch(base + 'state')).json();
  try {
    await waitFor(() => doc.querySelectorAll('.node').length === 5, 'initial graph');
    // Текст от пользователя не должен становиться HTML-кодом.
    doc.getElementById('new-label').value = '<img src=x onerror=alert(1)>';
    doc.getElementById('add').click();
    await waitFor(async () => (await state()).model.nodes.length === 6, 'add node');
    if (doc.querySelector('.node img')) throw new Error('label injected as HTML');
    if (![...doc.querySelectorAll('.node .name')].some(n => n.textContent.includes('<img'))) throw new Error('label lost');

    let first = doc.querySelector('[data-id="N1"]');
    first.focus();
    const oldX = (await state()).model.nodes.find(n => n.id === 'N1').x;
    first.dispatchEvent(new w.KeyboardEvent('keydown', {key:'ArrowRight', bubbles:true}));
    await waitFor(async () => (await state()).model.nodes.find(n => n.id === 'N1').x === oldX + 1, 'keyboard move');
    if (!doc.activeElement.classList.contains('node') || doc.activeElement.dataset.id !== 'N1') throw new Error('focus lost after moving');

    // Создание связи только клавиатурой: C, фокус на второй узел, Enter.
    doc.activeElement.dispatchEvent(new w.KeyboardEvent('keydown', {key:'c', bubbles:true}));
    const second = doc.querySelector('[data-id="N2"]'); second.focus();
    const oldEdges = (await state()).model.edges.length;
    second.dispatchEvent(new w.KeyboardEvent('keydown', {key:'Enter', bubbles:true}));
    await waitFor(async () => (await state()).model.edges.length === oldEdges + 1, 'keyboard link');

    // Перетаскивание в jsdom: геометрию указателя моделируем явно.
    first = doc.querySelector('[data-id="N1"]');
    const old = (await state()).model.nodes.find(n => n.id === 'N1');
    const mouse = (name, x, y) => {
      const e = new w.MouseEvent(name, {bubbles:true, button:0, clientX:x, clientY:y});
      Object.defineProperty(e, 'pointerId', {value:1}); return e;
    };
    first.dispatchEvent(mouse('pointerdown', 100, 100));
    first.dispatchEvent(mouse('pointermove', 128, 130));
    first.dispatchEvent(mouse('pointerup', 128, 130));
    await waitFor(async () => {
      const n = (await state()).model.nodes.find(x => x.id === 'N1');
      return n.x === old.x + 2 && n.y === old.y + 1;
    }, 'pointer drag');
    await waitFor(() => doc.getElementById('status').textContent.includes('Блок перемещён'), 'drag response');
    doc.getElementById('undo').click();
    await waitFor(async () => {
      const n = (await state()).model.nodes.find(x => x.id === 'N1');
      return n.x === old.x && n.y === old.y;
    }, 'undo');
    await waitFor(() => doc.getElementById('status').textContent.includes('отменено'), 'undo response');
    doc.querySelector('[data-id="N1"]').dispatchEvent(new w.KeyboardEvent('keydown', {key:'Z', ctrlKey:true, shiftKey:true, bubbles:true}));
    await waitFor(async () => {
      const n = (await state()).model.nodes.find(x => x.id === 'N1');
      return n.x === old.x + 2 && n.y === old.y + 1;
    }, 'keyboard redo');
    await waitFor(() => doc.getElementById('status').textContent.includes('повторено'), 'redo response');
    if (!(await state()).modified) throw new Error('editing unexpectedly saved');
    doc.getElementById('save').click();
    await waitFor(async () => !(await state()).modified, 'explicit save');
    console.log('OK   браузер jsdom: мышь, клавиатура, связи, безопасная подпись и явное сохранение');
  } finally { w.close(); }
})().catch(e => { console.error(e.stack || e); process.exitCode = 1; });
