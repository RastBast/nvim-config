#!/usr/bin/env python3
"""Модель интерактивной схемы: действия, границы и сохранность данных."""
import os
import shutil
import subprocess
import sys
import tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, 'tests', 'lua_stubs.lua'), encoding='utf-8') as f:
        rt.execute(f.read())
    rt.execute(r'''
      vim.islist = function(t)
        if type(t) ~= 'table' then return false end
        local n = 0; for k in pairs(t) do if type(k) ~= 'number' or k < 1 or k % 1 ~= 0 then return false end; n = n + 1 end
        return n == #t
      end
      vim.deepcopy = function(v)
        if type(v) ~= 'table' then return v end
        local r = {}; for k,x in pairs(v) do r[k] = vim.deepcopy(x) end; return r
      end
      M = require('config.architecture_model')
    ''')
    checks = []
    def check(title, expr):
        ok = bool(rt.eval(expr))
        checks.append(ok)
        print(('OK   ' if ok else 'FAIL ') + title)

    check('все пять шаблонов корректны', "(function() for _,t in ipairs(M.template_names) do if not M.validate(M.template(t.id)) then return false end end return true end)()")
    rt.execute("G=M.template('context'); G.custom={note='сохранить'}; N,ID=M.apply(G,{op='add',label='Auth <x>',kind='service',x=3,y=4})")
    check('добавление создаёт новый узел', "N and ID=='N4' and #N.nodes==4")
    check('исходная модель не изменена', '#G.nodes == 3')
    check('чужие поля не теряются', "N.custom.note=='сохранить'")
    rt.execute("LAYERS=M.template('layers'); PLACED=assert(M.apply(LAYERS,{op='add',label='Свободное место'}))")
    check('новый блок не перекрывает существующие', '''(function()
      local a=PLACED.nodes[5]
      for i=1,4 do local b=PLACED.nodes[i]
        if a.x < b.x+M.BOX_WIDTH and a.x+M.BOX_WIDTH > b.x
          and a.y < b.y+M.BOX_HEIGHT and a.y+M.BOX_HEIGHT > b.y then return false end
      end
      return true
    end)()''')
    rt.execute("BAD,ERR=M.apply(G,{op='add',label='  '})")
    check('пустое название отклонено', 'BAD == nil and ERR ~= nil and #G.nodes==3')
    rt.execute("BAD=M.apply(G,{op='add',label='bad\\nvalue'})")
    check('управляющие символы отклоняются', 'BAD == nil')
    rt.execute("BAD=M.template('layers'); BAD.nodes[1].label='Имя\\n'")
    check('перевод строки на краю подписи из файла тоже отклоняется', 'not M.validate(BAD)')
    rt.execute("X=M.apply(N,{op='move',id='N4',x=72,y=70}); BAD=M.apply(N,{op='move',id='N4',x=73,y=0})")
    check('перемещение в пределах сетки', 'X.nodes[4].x==72 and X.nodes[4].y==70 and N.nodes[4].x==3')
    check('перемещение за край отклоняется', 'BAD == nil')
    rt.execute("X=M.apply(N,{op='rename',id='N4',label='API'}); X=M.apply(X,{op='kind',id='N4',kind='storage'})")
    check('переименование и смена вида', "X.nodes[4].label=='API' and X.nodes[4].kind=='storage'")
    rt.execute("X,EID=M.apply(X,{op='link',from='N1',to='N4',label='HTTPS'}); BAD=M.apply(X,{op='link',from='N1',to='N1'})")
    check('добавляется направленная связь', "EID=='E3' and X.edges[3].from=='N1' and X.edges[3].to=='N4'")
    check('петля в текущем прототипе отклонена', 'BAD == nil')
    rt.execute("X=M.apply(X,{op='delete',id='N4'})")
    check('удаление узла удаляет связанные стрелки', '#X.nodes==3 and #X.edges==2')
    rt.execute("X=M.apply(X,{op='unlink',id='E1'})")
    check('связь можно удалить независимо', '#X.edges==1 and X.edges[1].id=="E2"')
    rt.execute("X=M.apply(X,{op='layout'})")
    check('авторасстановка остаётся внутри сетки', 'M.validate(X)')
    rt.execute("BAD=M.template('context'); BAD.nodes[2].id=BAD.nodes[1].id")
    check('повторные ID отклоняются', 'not M.validate(BAD)')
    rt.execute("BAD=M.template('context'); BAD.edges[1].to='N99'")
    check('стрелка на отсутствующий компонент отклоняется', 'not M.validate(BAD)')
    rt.execute("OPT=M.template('context'); OPT.edges[1].label=nil; OPT_RENDER=M.mermaid(OPT); BAD=M.template('context'); BAD.edges[1].label=false")
    check('необязательная подпись связи и её тип проверяются', "M.validate(OPT) and OPT_RENDER and not M.validate(BAD)")
    rt.execute("BAD=M.template('context'); BAD.nodes[1].x=0/0")
    check('NaN в координатах отклоняется', 'not M.validate(BAD)')
    rt.execute("G=M.template('empty'); for i=1,50 do G=assert(M.apply(G,{op='add',label='N'..i})) end; TOO=M.apply(G,{op='add',label='лишний'})")
    check('не более 50 компонентов', '#G.nodes==50 and TOO==nil')
    rt.execute("G=M.template('empty'); G=assert(M.apply(G,{op='add',label='a | \\\"<tag>\\\" #'})); G=assert(M.apply(G,{op='add',label='b'})); G=assert(M.apply(G,{op='link',from='N1',to='N2',label='x|y'})); OUT=table.concat(M.mermaid(G),'\\n')")
    check('экспорт Mermaid экранирует имена и связи', "OUT:find('#124;',1,true) and OUT:find('#60;',1,true) and OUT:find('#35;',1,true)")
    failed = len(checks) - sum(checks)
    print(f'\nпроверок: {len(checks)}, провалов: {failed}')
    if os.environ.get('MERMAID_JS') and shutil.which('node'):
        rt.execute(r'''
          T=M.template('empty')
          T=assert(M.apply(T,{op='add',label='Клиент "API" <тест> & #'}))
          T=assert(M.apply(T,{op='add',label='База | архив'}))
          T=assert(M.apply(T,{op='link',from='N1',to='N2',label='"edge" | # & <>'}))
          DIAGRAM=table.concat(M.mermaid(T),'\n')
        ''')
        markdown = rt.eval('DIAGRAM')
        block = markdown.split('```mermaid\n', 1)[1].split('\n```', 1)[0]
        with tempfile.TemporaryDirectory(prefix='arch-model-mermaid-') as tmp:
            path = os.path.join(tmp, 'model.mmd')
            with open(path, 'w', encoding='utf-8') as f:
                f.write(block)
            parser = os.path.join(_lua.ROOT, 'tests', 'architecture_mermaid_smoke.js')
            parsed = subprocess.run(['node', parser, path, 'Клиент', 'База'], capture_output=True, text=True, timeout=30)
            print((parsed.stdout + parsed.stderr).strip())
            if parsed.returncode:
                failed += 1
    else:
        print('SKIP: экспорт JSON-модели: реальный Mermaid (MERMAID_JS + jsdom)')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
