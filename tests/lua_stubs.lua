-- Заглушка API Neovim для тестов под LuaJIT (без запуска nvim).
-- Записывает вызовы, чтобы тесты могли проверить результат: подсветку,
-- клавиши, уведомления, содержимое буферов и таймеры.

HL = {}          -- nvim_set_hl: группа -> опции
KEYS = {}        -- vim.keymap.set: список {mode, lhs, rhs, opts}
CMDS = {}        -- nvim_create_user_command: имя -> функция
NOTES = {}       -- vim.notify: список {msg, lvl, opts}
BUF_LINES = {}   -- nvim_buf_set_lines: buf -> последние строки
WINS = {}        -- nvim_open_win: список {buf, cfg}
WIN_VALID = {}   -- id окна -> false, если закрыто
TIMERS = {}      -- созданные таймеры (uv.new_timer)
LAST_CFG = nil   -- последний nvim_win_set_config
SET_COUNT = 0    -- сколько раз писали в буфер
local next_buf = 0

-- Универсальный прокси: любое vim.xxx.yyy() не падает.
local function proxy(path)
  return setmetatable({}, {
    __index = function(_, k) return proxy(path .. "." .. tostring(k)) end,
    __call = function(_, ...) return proxy(path .. "()") end,
  })
end

vim = proxy("vim")
vim.o = { columns = 120, lines = 40 }
vim.bo = setmetatable({}, { __index = function(t, k) local v = {}; rawset(t, k, v); return v end })
vim.wo = setmetatable({}, { __index = function(t, k) local v = {}; rawset(t, k, v); return v end })
vim.g = {}
vim.env = {}
vim.fn = setmetatable({}, { __index = function() return function() return "" end end })
vim.log = { levels = { TRACE = 0, DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 } }

vim.api = {
  nvim_create_namespace = function() return 1 end,
  nvim_set_hl = function(_, group, opts) HL[group] = opts end,
  nvim_create_buf = function() next_buf = next_buf + 1; return next_buf end,
  nvim_open_win = function(buf, _, cfg)
    WINS[#WINS + 1] = { buf = buf, cfg = cfg }
    local id = 1000 + #WINS
    WIN_VALID[id] = true
    return id
  end,
  nvim_buf_set_lines = function(buf, _, _, _, lines)
    BUF_LINES[buf] = lines
    SET_COUNT = SET_COUNT + 1
  end,
  nvim_buf_is_valid = function() return true end,
  nvim_win_is_valid = function(w) return WIN_VALID[w] ~= false end,
  nvim_win_close = function(w) WIN_VALID[w] = false end,
  nvim_win_set_config = function(_, cfg) LAST_CFG = cfg end,
  nvim_get_current_win = function() return 1 end,
  nvim_win_get_width = function() return 120 end,
  nvim_create_user_command = function(name, fn) CMDS[name] = fn end,
  nvim_replace_termcodes = function(s) return s end,
}

vim.keymap = {
  set = function(mode, lhs, rhs, opts)
    KEYS[#KEYS + 1] = { mode = mode, lhs = lhs, rhs = rhs, opts = opts }
  end,
}

vim.uv = {
  new_timer = function()
    local t = {}
    function t.start(self, _, _, cb) self.cb = cb; TIMERS[#TIMERS + 1] = self end
    function t.stop() end
    function t.close() end
    function t.is_closing() return false end
    return t
  end,
}
vim.schedule_wrap = function(fn) return fn end
vim.schedule = function(fn) fn() end
vim.notify = function(msg, lvl, opts) NOTES[#NOTES + 1] = { msg = msg, lvl = lvl, opts = opts } end
vim.deepcopy = function(t) return t end
vim.tbl_contains = function(t, v)
  for _, x in ipairs(t) do if x == v then return true end end
  return false
end

package.path = ROOT_PATH .. "/lua/?.lua;" .. ROOT_PATH .. "/lua/?/init.lua;" .. package.path
