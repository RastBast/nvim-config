-- ========================================================================== --
--          📖 MARKDOWN: LIVE-ПРЕВЬЮ В БРАУЗЕРЕ (обновляется на лету)        --
-- ========================================================================== --
-- :MdPreview [файл]   — открыть превью текущего (или указанного) markdown
-- :MdPreviewStop      — закрыть превью (убить сервер)
-- <leader>mL          — переключить превью (вкл/выкл)
--
-- Как работает:
--   * Поднимается локальный python3-сервер (127.0.0.1:45771) из
--     stdpath("cache")/md_preview/server.py — без внешних зависимостей и без
--     интернета: рендер markdown в HTML живёт внутри сервера.
--   * Страница сама опрашивает /view каждые 400 мс и перерисовывает содержимое
--     — визуальный результат: текст на сайте меняется СРАЗУ, как только ты
--     печатаешь (не только после :w).
--   * Neovim на каждый TextChanged/TextChangedI/BufWritePost пишет ТЕКУЩЕЕ
--     содержимое буфера (даже несохранённое!) в файл-источник превью
--     (debounce 250 мс) — сервер читает его при каждом опросе страницы.
--   * Браузер открывается сам (macOS: open, Linux: xdg-open).
--
-- Диагностика: :MdPreviewStatus — живой ли сервер и какой файл смотрит.
local M = {}

local PORT = 45771
local state = {
  job = nil,
  buf = nil,       -- буфер-источник
  file = nil,      -- файл-экспорт в cache (то, что читает сервер)
  export_timer = nil,
  aucmd = nil,
}

local function cache_dir()
  local d = vim.fn.stdpath("cache") .. "/md_preview"
  vim.fn.mkdir(d, "p")
  return d
end

-- ---------------------------------------------------------------- сервер ---
-- Python без зависимостей: ThreadingHTTPServer + мини-рендер markdown.
local SERVER_PY = [==[
import html, json, os, re, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MD_PATH, PORT = sys.argv[1], int(sys.argv[2])
rev = 0
last_mtime = 0.0
lock = threading.Lock()

def esc(s):
    return html.escape(s, quote=False)

def inline(s):
    s = esc(s)
    s = re.sub(r'`([^`]+)`', lambda m: '<code>%s</code>' % m.group(1), s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'__([^_]+)__', r'<strong>\1</strong>', s)
    s = re.sub(r'(?<![\w*])\*([^*]+)\*(?![\w*])', r'<em>\1</em>', s)
    s = re.sub(r'(?<![\w_])_([^_]+)_(?![\w_])', r'<em>\1</em>', s)
    s = re.sub(r'~~([^~]+)~~', r'<del>\1</del>', s)
    s = re.sub(r'!\[([^\]]*)\]\(([^)\s]+)\)', r'<span class="img" title="\2">[img: \1]</span>', s)
    s = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)', r'<a href="\2" target="_blank" rel="noopener">\1</a>', s)
    return s

def render(text):
    lines = text.split('\n')
    out, i, n = [], 0, len(lines)
    def is_sep(l):
        return bool(re.match(r'^\s*\|?\s*:?-{2,}.*\|', l)) or bool(re.match(r'^\s*\|?[\s:|-]*-{2,}[\s:|-]*$', l)) and '-' in l
    while i < n:
        l = lines[i]
        s = l.strip()
        if not s:
            i += 1
            continue
        m = re.match(r'^```+(\w*)\s*$', s)
        if m:
            lang = m.group(1) or ''
            buf = []
            i += 1
            while i < n and not re.match(r'^```+\s*$', lines[i].strip()):
                buf.append(lines[i]); i += 1
            i += 1
            cls = (' class="lang-%s"' % esc(lang)) if lang else ''
            out.append('<pre%s><code>%s</code></pre>' % (cls, esc('\n'.join(buf))))
            continue
        m = re.match(r'^(#{1,6})\s+(.*)$', s)
        if m:
            lv = len(m.group(1))
            out.append('<h%d>%s</h%d>' % (lv, inline(m.group(2)), lv))
            i += 1
            continue
        if re.match(r'^(-{3,}|\*{3,}|_{3,})$', s):
            out.append('<hr/>'); i += 1; continue
        if s.startswith('>'):
            buf = []
            while i < n and lines[i].strip().startswith('>'):
                buf.append(re.sub(r'^\s*>\s?', '', lines[i])); i += 1
            out.append('<blockquote>%s</blockquote>' % render('\n'.join(buf)))
            continue
        if '|' in s and i + 1 < n and is_sep(lines[i + 1]):
            head = [c.strip() for c in s.strip('|').split('|')]
            i += 2
            rows = []
            while i < n and '|' in lines[i] and lines[i].strip():
                rows.append([c.strip() for c in lines[i].strip().strip('|').split('|')]); i += 1
            th = ''.join('<th>%s</th>' % inline(c) for c in head)
            tr = ''.join('<tr>%s</tr>' % ''.join('<td>%s</td>' % inline(c) for c in r) for r in rows)
            out.append('<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>' % (th, tr))
            continue
        m = re.match(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$', l)
        if m:
            items = []
            while i < n:
                mm = re.match(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$', lines[i])
                if not mm:
                    break
                indent = len(mm.group(1).expandtabs(4))
                body = mm.group(3)
                level = min(indent // 2, 3)
                cb = re.match(r'^\[([ xX])\]\s+(.*)$', body)
                if cb:
                    done = cb.group(1) != ' '
                    body = '<span class="cb %s">%s</span> %s' % ('done' if done else '', '[x]' if done else '[ ]', inline(cb.group(2)))
                else:
                    body = inline(body)
                items.append((level, '<li>%s</li>' % body))
                i += 1
            html_out, stack = [], []
            for level, li in items:
                while len(stack) > level + 1:
                    html_out.append('</ul>'); stack.pop()
                while len(stack) < level + 1:
                    html_out.append('<ul>'); stack.append(1)
                html_out.append(li)
            while stack:
                html_out.append('</ul>'); stack.pop()
            out.append(''.join(html_out))
            continue
        buf = [s]
        i += 1
        while i < n and lines[i].strip() and not re.match(r'^(#{1,6}\s|```|>|\s*([-*+]|\d+[.)])\s|\|)', lines[i]):
            buf.append(lines[i].strip()); i += 1
        out.append('<p>%s</p>' % inline(' '.join(buf)))
    return '\n'.join(out)

PAGE = """<!doctype html><html lang="ru"><head><meta charset="utf-8">
<title>Markdown live-preview</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
 :root { color-scheme: dark; }
 body { background:#0d0d0d; color:#e6e6e6; font:16px/1.6 -apple-system,'Segoe UI',Roboto,sans-serif;
        margin:0; padding:48px 16px; }
 #md { max-width:860px; margin:0 auto; }
 h1,h2,h3 { color:#ff9500; border-bottom:1px solid #222; padding-bottom:.2em; }
 h1 { font-size:2em; } h2 { font-size:1.5em; } h3 { font-size:1.2em; }
 a { color:#00eeff; } code { background:#1a1a2e; color:#7dff5c; padding:.1em .35em; border-radius:4px; }
 pre { background:#111122; border:1px solid #0d00ff55; border-radius:8px; padding:12px; overflow:auto; }
 pre code { background:none; padding:0; color:#c9d1d9; }
 blockquote { border-left:4px solid #6902de; margin:.6em 0; padding:.2em 1em; color:#aaa; background:#141414; }
 table { border-collapse:collapse; margin:.8em 0; } th,td { border:1px solid #333; padding:.4em .8em; }
 th { background:#1a1a2e; color:#ff9500; } tr:nth-child(even) { background:#141414; }
 hr { border:none; border-top:1px solid #333; }
 .cb { font-family:monospace; color:#6902de; } .cb.done { color:#2bff00; text-decoration:line-through; }
 .img { color:#888; font-style:italic; }
 #badge { position:fixed; right:12px; bottom:10px; font:12px monospace; color:#555; }
</style></head><body>
<div id="md"></div><div id="badge">live-preview · nvim</div>
<script>
let cur = -1;
async function poll() {
  try {
    const r = await fetch('/view', { cache: 'no-store' });
    const d = await r.json();
    if (d.rev !== cur) { cur = d.rev; document.getElementById('md').innerHTML = d.html; }
  } catch (e) { /* сервер перезапускается — просто ждём следующего тика */ }
}
setInterval(poll, 400); poll();
</script></body></html>
"""

class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *a):
        pass
    def _send(self, code, body, ctype):
        data = body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        global rev, last_mtime
        if self.path.startswith('/view'):
            try:
                mt = os.path.getmtime(MD_PATH)
            except OSError:
                mt = 0.0
            with lock:
                if mt != last_mtime:
                    last_mtime = mt
                    rev += 1
                try:
                    with open(MD_PATH, encoding='utf-8') as f:
                        text = f.read()
                except OSError:
                    text = ''
                payload = json.dumps({ 'rev': rev, 'html': render(text) })
            self._send(200, payload, 'application/json; charset=utf-8')
        else:
            self._send(200, PAGE, 'text/html; charset=utf-8')

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
]==]

local function url()
  return ("http://127.0.0.1:%d/"):format(PORT)
end

local function export_now()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.file) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local f = io.open(state.file, "w")
  if f then
    f:write(table.concat(lines, "\n"))
    f:close()
  end
end

local function export_soon()
  if state.export_timer then
    state.export_timer:stop()
  else
    state.export_timer = vim.loop.new_timer()
  end
  state.export_timer:start(250, 0, vim.schedule_wrap(function()
    export_now()
  end))
end

local function open_browser()
  if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
    vim.fn.jobstart({ "open", url() }, { detach = true })
  elseif vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", url() }, { detach = true })
  else
    vim.notify(" Превью: " .. url(), vim.log.levels.INFO)
  end
end

local function watch_buffer()
  if state.aucmd then
    pcall(vim.api.nvim_del_augroup_by_id, state.aucmd)
  end
  state.aucmd = vim.api.nvim_create_augroup("MdPreview", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = state.aucmd,
    buffer = state.buf,
    callback = export_soon,
  })
  -- закрыл буфер — превью останавливается, сервер не висит сиротой
  vim.api.nvim_create_autocmd("BufUnload", {
    group = state.aucmd,
    buffer = state.buf,
    callback = function()
      M.stop()
    end,
  })
end

function M.start(file)
  if vim.fn.executable("python3") ~= 1 then
    vim.notify("📖 MdPreview нужен python3 (его нет в PATH)", vim.log.levels.ERROR)
    return false
  end

  local buf = vim.api.nvim_get_current_buf()
  if file and file ~= "" then
    local target = vim.fn.fnamemodify(file, ":p")
    local found = vim.fn.bufnr(target)
    if found ~= -1 then
      buf = found
    else
      buf = vim.fn.bufadd(target)
      vim.fn.bufload(buf)
    end
  end
  if vim.bo[buf].filetype ~= "markdown" then
    -- не страшно: превью честно покажет текст как markdown
  end

  -- уже работает с этим же буфером — просто ещё раз открыть браузер
  if state.job and state.buf == buf then
    open_browser()
    return true
  end
  if state.job then
    M.stop()
  end

  state.buf = buf
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
  if name == "" then
    name = "buffer.md"
  end
  state.file = cache_dir() .. "/preview-" .. name .. ".md"
  export_now()

  local py = cache_dir() .. "/server.py"
  local f = io.open(py, "w")
  if not f then
    vim.notify("📖 Не удалось записать server.py в " .. cache_dir(), vim.log.levels.ERROR)
    return false
  end
  f:write(SERVER_PY)
  f:close()

  state.job = vim.fn.jobstart({ "python3", py, state.file, tostring(PORT) }, {
    detach = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if state.job then
          state.job = nil
          if code ~= 0 then
            vim.notify("📖 MdPreview: сервер упал (код " .. code .. "). Порт " .. PORT .. " занят?", vim.log.levels.ERROR)
          end
        end
      end)
    end,
  })

  watch_buffer()
  -- даём серверу подняться и открываем браузер
  vim.defer_fn(open_browser, 400)
  vim.notify("📖 Markdown live-превью: " .. url() .. " (обновляется при наборе; стоп — :MdPreviewStop)", vim.log.levels.INFO)
  return true
end

function M.stop()
  if state.job then
    pcall(vim.fn.jobstop, state.job)
    state.job = nil
  end
  if state.aucmd then
    pcall(vim.api.nvim_del_augroup_by_id, state.aucmd)
    state.aucmd = nil
  end
  if state.export_timer then
    pcall(function() state.export_timer:stop() end)
    state.export_timer = nil
  end
  state.buf, state.file = nil, nil
end

function M.toggle(file)
  if state.job then
    M.stop()
    vim.notify("📖 Markdown live-превью выключено", vim.log.levels.INFO)
  else
    M.start(file)
  end
end

function M.status()
  if state.job then
    vim.notify(("📖 MdPreview жив: %s → %s"):format(state.file or "?", url()), vim.log.levels.INFO)
  else
    vim.notify("📖 MdPreview не запущен. Вкл: :MdPreview или <leader>mL", vim.log.levels.INFO)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("MdPreview", function(opts)
    M.start(opts.args)
  end, {
    nargs = "?",
    complete = "file",
    desc = "📖 Markdown live-превью в браузере (обновляется при наборе)",
  })
  vim.api.nvim_create_user_command("MdPreviewStop", function()
    M.stop()
    vim.notify("📖 Markdown live-превью выключено", vim.log.levels.INFO)
  end, { desc = "📖 Остановить live-превью markdown" })
  vim.api.nvim_create_user_command("MdPreviewStatus", M.status, { desc = "📖 Жив ли сервер live-превью" })

  vim.keymap.set("n", "<leader>mL", function()
    M.toggle()
  end, { desc = "📖 Markdown: live-превью в браузере (вкл/выкл)" })

  -- на выходе из nvim сервер не должен остаться сиротой
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.stop()
    end,
  })
end

return M
