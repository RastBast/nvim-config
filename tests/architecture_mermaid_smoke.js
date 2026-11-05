// Запускается architecture_nvim_smoke.py с Mermaid из markdown-preview.nvim.
const { JSDOM } = require('jsdom');
const fs = require('fs');
const dom = new JSDOM('<!DOCTYPE html>');
global.window = dom.window;
global.document = dom.window.document;
global.navigator = dom.window.navigator;
// jsdom не вычисляет геометрию SVG: подставляем размеры только для smoke-теста
// создания SVG. Это не заменяет визуальную проверку настоящим браузером.
const svg = dom.window.SVGElement.prototype;
svg.getBBox = () => ({ x: 0, y: 0, width: 120, height: 20 });
svg.getComputedTextLength = () => 100;
const mermaid = require(process.env.MERMAID_JS);
mermaid.initialize({ startOnLoad: false });
(async () => {
  const source = fs.readFileSync(process.argv[2], 'utf8');
  await mermaid.parse(source);
  const rendered = await mermaid.render('arch-smoke', source);
  const expected = process.argv.length > 3 ? process.argv.slice(3) : ['Клиент', 'Auth'];
  if (!rendered.svg.includes('<svg') || !expected.every(text => rendered.svg.includes(text))) {
    throw new Error('Mermaid не создал ожидаемую SVG-схему');
  }
  console.log('OK   Mermaid: разбор и SVG с экранированными подписями (jsdom)');
})().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
