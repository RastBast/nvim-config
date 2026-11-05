// Необязательный реальный Chromium + живой Neovim; никакой внешней сети.
// ARCH_BROWSER_BIN=/path/to/chromium NODE_PATH=/path/to/puppeteer-core ...
const puppeteer = require('puppeteer-core');
const base = process.argv[2];

(async () => {
  const browser = await puppeteer.launch({
    executablePath: process.env.ARCH_BROWSER_BIN,
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
    defaultViewport: {width: 1360, height: 900},
  });
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('dialog', dialog => dialog.accept('браузерная связь'));
    await page.goto(base, {waitUntil: 'domcontentloaded'});
    await page.waitForSelector('[data-id="N1"]');
    const getState = () => page.evaluate(async () => (await fetch(new URL('state', location.href), {cache:'no-store'})).json());
    const waitNode = (id, x, y) => page.waitForFunction(async (id, x, y) => {
      const state = await (await fetch(new URL('state', location.href), {cache:'no-store'})).json();
      const n = state.model.nodes.find(item => item.id === id);
      return n && n.x === x && n.y === y;
    }, {timeout: 8000}, id, x, y);

    const initial = await getState();
    await page.type('#new-label', 'Компонент из Chromium');
    await page.select('#new-kind', 'queue');
    await page.click('#add');
    await page.waitForFunction(count => document.querySelectorAll('.node').length === count, {timeout: 8000}, initial.model.nodes.length + 1);
    let state = await getState();
    const added = state.model.nodes.find(n => n.label === 'Компонент из Chromium' && n.kind === 'queue');
    if (!state.modified || !added) throw new Error('новый блок не добавлен в буфер');
    for (const node of initial.model.nodes) {
      if (added.x < node.x + 16 && added.x + 16 > node.x && added.y < node.y + 3 && added.y + 3 > node.y) {
        throw new Error('новый блок перекрывает существующий: ' + node.label);
      }
    }

    // Настоящая геометрия и pointer events: захват блока и перенос на 2×1 ячейки.
    const old = state.model.nodes.find(n => n.id === 'N1');
    const box = await (await page.$('[data-id="N1"]')).boundingBox();
    if (!box || Math.abs(box.width - 196) > 1 || Math.abs(box.height - 72) > 1) throw new Error('неверная геометрия блока');
    await page.mouse.move(box.x + 40, box.y + 30);
    await page.mouse.down();
    await page.mouse.move(box.x + 68, box.y + 60, {steps: 4});
    await page.mouse.up();
    await waitNode('N1', old.x + 2, old.y + 1);
    await page.waitForFunction(() => document.querySelector('#status').textContent.includes('Блок перемещён'));
    await page.click('#undo');
    await waitNode('N1', old.x, old.y);
    await page.waitForFunction(() => document.querySelector('#status').textContent.includes('отменено'));
    await page.click('#redo');
    await waitNode('N1', old.x + 2, old.y + 1);
    await page.waitForFunction(() => document.querySelector('#status').textContent.includes('повторено'));

    // Кнопка связи + настоящие события мыши и диалог подписи.
    const count = (await getState()).model.edges.length;
    await page.click('[data-id="N1"]');
    await page.click('#connect');
    await page.click('[data-id="N2"]');
    await page.waitForFunction(async count => {
      const s = await (await fetch(new URL('state', location.href))).json();
      return s.model.edges.length === count + 1 && s.model.edges.some(e => e.label === 'браузерная связь');
    }, {timeout:8000}, count);
    await page.waitForFunction(() => document.querySelector('#status').textContent.includes('Связь добавлена'));
    await page.click('#save');
    await page.waitForFunction(async () => !(await (await fetch(new URL('state', location.href))).json()).modified, {timeout:8000});
    if (process.env.ARCH_BROWSER_SCREENSHOT) await page.screenshot({path:process.env.ARCH_BROWSER_SCREENSHOT});
    if (errors.length) throw new Error('ошибки страницы: ' + errors.join('; '));
    console.log('OK   реальный Chromium: геометрия, мышь, связи, undo/redo и явное сохранение');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
