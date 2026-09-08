# Gemini из-под блокировки: ретранслятор на своём сервере

Коротко: **браузерный VPN тут не поможет в принципе**, а вот свой сервер — поможет.
Ниже — почему, как за 5 минут понять, что именно ломается, и два рабочих способа
(ретранслятор через nginx / HTTP-прокси через SSH-туннель).

> ⚠️ **Сначала выполни §1.** Чаще всего Gemini «не работает» не из-за сети:
> ключ, устаревшее имя модели или лимит бесплатного тарифа лечатся за минуту,
> а ретранслятор при этом вообще не нужен.
>
> И если ты уже успел «на всякий случай» прописать переменные из §2/§3 —
> сними их, иначе avante будет стучаться на несуществующий адрес:
> ```fish
> set -e GEMINI_ENDPOINT
> set -e GEMINI_PROXY
> set -e GEMINI_INSECURE
> ```

---

## 0. Почему «VPN прямо в браузере от Firefox» не вариант

Браузерный VPN (Firefox Private Network, встроенный VPN Firefox, расширения
типа Browsec/Planet VPN, VPN в Opera) проксирует **только те запросы, которые
делает сам браузер**. Это не системный VPN: он не создаёт сетевой интерфейс и
не меняет маршруты ОС.

avante.nvim браузера не использует вообще: он вызывает `curl` и ходит по HTTPS
напрямую (в исходниках: `lua/avante/providers/gemini.lua:327-336` — URL
собирается как `endpoint .. "/" .. model .. ":streamGenerateContent?alt=sse&key=<ключ>"`,
дальше `plenary.curl` → системный curl). То есть «прогнать трафик Gemini через
браузер» технически невозможно — нечего прогонять, браузер в цепочке не участвует.

> Заодно: бесплатное расширение Firefox Private Network Mozilla закрыла ещё
> 20.06.2023 (support.mozilla.org/en-US/kb/firefox-private-network-no-longer-available);
> сейчас в Firefox тестируется новый встроенный VPN — и он тоже browser-only.

**Что реально работает:** поставить на свой сервер маленький ретранслятор и
сказать avante, чтобы он ходил туда. Google тогда увидит IP сервера, а твой
провайдер/DPI — обычный HTTPS (или SSH) до твоего сервера.

---

## 1. Сначала диагностика: что именно «палит» Gemini

Три разные причины, три разных лечения. Выполни **без VPN** и **с включённым VPN**:

```fish
set -Ux GEMINI_API_KEY 'твой_ключ'

curl -sS -w '\n[HTTP %{http_code}] время: %{time_total}s\n' \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"ping"}]}]}' | head -c 500
```

| Что вернуло | Диагноз | Лечение |
|---|---|---|
| JSON с `"candidates"` | Всё работает, дело было в nvim-сессии (не подхватила переменную) | §4, «ключ не виден» |
| `Connection reset by peer`, `Empty reply`, висит и отваливается | **DPI режет** доступ к Google (без VPN) | способ A или B |
| `400 API_KEY_INVALID` / `"API key not valid"` | **Ключ**, а не сеть | §3 |
| `404` + «model … is no longer available to new users» | **Модель устарела**, сеть и ключ в порядке | `set -Ux GEMINI_MODEL "gemini-3.6-flash"` |
| `400 FAILED_PRECONDITION` + «**User location is not supported** for the API use» | Google видит **IP неподдерживаемой страны** (РФ). Ключ и модель в порядке | §1.5 — сначала тест через VPN |
| `400 FAILED_PRECONDITION` + «free tier is not available in your country» | Бесплатный тариф не доступен для региона **проекта/аккаунта** — смена IP не помогает | §1.5, последний пункт |
| `403 PERMISSION_DENIED` | Ключ без прав / не включён Generative Language API | §3 |
| `429 RESOURCE_EXHAUSTED` | Упёрся в бесплатный лимит (RPM/TPM) | подождать, лимит поминутный |

### 1.5. «User location is not supported for the API use» — что делать

Это геоблок по IP исходящего запроса: бесплатный Gemini API в РФ не отдаётся.
Ключ и модель при этом могут быть полностью рабочими (у тебя так и было:
с VPN пришла 404 про устаревшую модель — значит запрос до Google дошёл и
проверку региона прошёл).

**Шаг 1. Тот же curl, но с включённым VPN/туннелем** (AmneziaVPN, WARP — любой):

```fish
curl -sS -w '\n[HTTP %{http_code}] %{time_total}s\n' \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' -d '{"contents":[{"parts":[{"text":"ping"}]}]}' | head -c 300
```

* **JSON с `"candidates"`** → выход чистый. Оставляешь VPN включённым — и
  avante работает как есть, ничего больше не нужно (прокси/ретранслятор не
  требуются, `GEMINI_*` не трогай). Хочешь, чтобы через VPN ходил только
  Gemini, а не вся система — способ A/B ниже, только сервер должен быть
  **не в РФ**.
* **Снова `User location is not supported`** → выход VPN тоже в РФ или в
  неподдерживаемой стране. Нужен выход из ЕС/США/другой поддерживаемой
  страны: смена локации в AmneziaVPN, другой сервер, WARP.
* **`free tier is not available in your country`** даже с чистого IP →
  ограничение на **проекте/аккаунте** Google. Тогда либо включённый биллинг
  в AI Studio, либо новый Google-аккаунт, созданный через чистый выход,
  либо другой провайдер — см. «План B» в конце файла.

**Важно про способ A/B:** Google определяет страну по IP **сервера**, на
котором стоит ретранслятор. Сервер в РФ не поможет — нужен сервер за
рубежом (тот же, что ты используешь для VPN, если он не в РФ).

### Если Google отвечает ошибкой даже с VPS

Проверь, что видит Google с твоего сервера:

```fish
ssh user@ТВОЙ_СЕРВЕР 'curl -sS -w "\n[HTTP %{http_code}]\n" \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=КЛЮЧ" \
  -H "Content-Type: application/json" -d "{\"contents\":[{\"parts\":[{\"text\":\"ping\"}]}]}" | head -c 400'
```

* Ответил JSON → сервер «чистый», значит проблема в твоём канале → **способ A/B решают задачу**.
* Ошибка про страну/регион → Google смотрит на регион **проекта/аккаунта**, а не на IP.
  Тогда ретранслятор не поможет: нужен другой Google-аккаунт/проект, созданный
  через чистый выход, или включённый биллинг в AI Studio.

---

## 2. Способ A (рекомендую): nginx-ретранслятор на сервере

Смысл: nginx принимает твой запрос и **сам, своим соединением** идёт в Google.
DPI видит только HTTPS до твоего сервера (Google в цепочке с твоей стороны не
светится), Google видит IP сервера.

### A.1 На сервере

```bash
sudo apt update && sudo apt install -y nginx
SECRET=$(openssl rand -hex 16); echo "СЕКРЕТ: $SECRET"   # сохрани, пригодится

sudo tee /etc/nginx/sites-available/gemini >/dev/null <<EOF
server {
    listen 8443 ssl;
    server_name _;

    # доступ ТОЛЬКО по SSH-туннелю (см. A.2) — наружу порт не торчит
    allow 127.0.0.1;
    allow ::1;
    deny all;

    ssl_certificate     /etc/nginx/ssl/relay.crt;
    ssl_certificate_key /etc/nginx/ssl/relay.key;

    # секрет в пути = пароль: кто не знает SECRET, тот не пройдёт
    location ~ ^/S-$SECRET/(.*)\$ {
        rewrite ^/S-$SECRET/(.*)\$ /\$1 break;
        proxy_pass https://generativelanguage.googleapis.com;

        proxy_ssl_server_name on;                    # SNI — обязательно
        proxy_ssl_name generativelanguage.googleapis.com;
        proxy_set_header Host generativelanguage.googleapis.com;

        # стриминг ответов (SSE) без буферизации
        proxy_buffering off;
        proxy_cache off;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        chunked_transfer_encoding on;
    }
}
EOF

# самоподписанный сертификат (для туннеля хватит)
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout /etc/nginx/ssl/relay.key -out /etc/nginx/ssl/relay.crt \
  -subj "/CN=gemini-relay" 2>/dev/null

sudo nginx -t && sudo systemctl reload nginx
```

### A.2 На маке (туннель + переключение)

```fish
# туннель: локальный 8443 -> серверный 8443 (заодно шифрует всё до сервера)
ssh -N -L 8443:127.0.0.1:8443 user@ТВОЙ_СЕРВЕР

# в другом окне/табе fish:
set -Ux GEMINI_ENDPOINT "https://127.0.0.1:8443/S-ТВОЙ_СЕКРЕТ/v1beta/models"

# проверить, что ретранслятор живой:
curl -sSk -w '\n[HTTP %{http_code}]\n' \
  "$GEMINI_ENDPOINT/gemini-3.6-flash:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"ping"}]}]}' | head -c 300
```

`GEMINI_ENDPOINT` подхватывается конфигом автоматически — править Lua не нужно
(`lua/plugins/avante.lua`: `endpoint = vim.env.GEMINI_ENDPOINT or "https://generativelanguage..."`).

Чтобы туннель жил сам и переподключался:

```fish
brew install autossh
autossh -M 0 -f -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -L 8443:127.0.0.1:8443 user@ТВОЙ_СЕРВЕР
```

---

## 3. Способ B: HTTP-прокси + `proxy` (проще, без nginx)

avante умеет слать запросы через HTTP-прокси: поле `proxy` у любого провайдера
(`lua/avante/types.lua:256`) уходит в `curl -x`
(`lua/avante/providers/gemini.lua:331` → `llm.lua:590`).

### B.1 На сервере (3proxy, слушает только localhost)

> 3proxy в стандартных репозиториях Debian/Ubuntu обычно **нет** —
> проверь `apt-cache policy 3proxy`. Если пусто, собирай из исходников
> (второй блок) — это одна минута.

```bash
# вариант 1: если пакет есть в репозитории
sudo apt update && sudo apt install -y 3proxy

# вариант 2: сборка из исходников (работает везде)
sudo apt update && sudo apt install -y build-essential git
git clone --depth 1 https://github.com/z3APA3A/3proxy /tmp/3proxy
cd /tmp/3proxy && make -f Makefile.Linux && sudo cp src/3proxy /usr/local/bin/
```

Конфиг (лежит там, где 3proxy его ищет: `/etc/3proxy/3proxy.cfg` для пакета
или `/usr/local/etc/3proxy/3proxy.cfg` для сборки):

```bash
sudo mkdir -p /etc/3proxy
sudo tee /etc/3proxy/3proxy.cfg >/dev/null <<'EOF'
nscache 65536
auth strong
users gem:CL:СЛОЖНЫЙ_ПАРОЛЬ
allow gem
proxy -n -a -p3128 -i127.0.0.1
EOF

# запуск (для пакета — systemctl restart 3proxy; для сборки — вручную/юнитом)
sudo 3proxy /etc/3proxy/3proxy.cfg
sudo ss -lntp | grep 3128    # убедиться, что слушает 127.0.0.1:3128
```

> Совсем без стороннего софта: `ssh -D 1080` сам по себе уже SOCKS5-прокси
> (см. B.2) — 3proxy нужен только если хочется именно HTTP-прокси с паролем.

### B.2 На маке

```fish
# SOCKS5-туннель до сервера (DPI видит только SSH)
ssh -N -D 1080 user@ТВОЙ_СЕРВЕР

set -Ux GEMINI_PROXY "socks5h://127.0.0.1:1080"
```

`GEMINI_PROXY` подхватывается как `providers.gemini.proxy`. Запросы к Gemini
пойдут через сервер, весь остальной трафик системы — как шёл.

> Хочешь именно HTTP-прокси вместо SOCKS — подними 3proxy/gost **на самом
> сервере** и пробрось его порт (`ssh -N -L 3128:127.0.0.1:3128 …`),
> тогда `set -Ux GEMINI_PROXY "http://gem:СЛОЖНЫЙ_ПАРОЛЬ@127.0.0.1:3128"`.

---

## 4. Важные мелочи

* **Сертификат.** Самоподписанный сертификат ретранслятора curl по умолчанию не
  примет — запрос упадёт с `SSL certificate problem`. Два варианта:
  * быстро: `set -Ux GEMINI_INSECURE 1` (конфиг подхватит и включит
    `allow_insecure` — для трафика, который всё равно идёт по SSH-туннелю, приемлемо);
  * правильно: добавить сертификат в доверенные macOS и переменную не ставить:
    ```fish
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain relay.crt
    ```
* **Ключ в URL = ключ в логах.** Gemini ходит с `?key=...`, поэтому
  `access_log` nginx его запишет. В конфиге выше логи не включены — не включай.
* **Не выставляй ретранслятор в интернет.** `allow 127.0.0.1; deny all;` +
  SSH-туннель + секрет в пути. Открытый прокси к Gemini = чужие люди на твоём
  бесплатном лимите.
* **Ключ не виден nvim (macOS).** `set -Ux` в fish виден только процессам,
  запущенным из fish. Если nvim открыт из GUI (иконка/Spotlight) — переменной
  там нет. Лечится запуском из терминала, либо `launchctl setenv GEMINI_API_KEY '…'`.
* **Проверить, что nvim видит ключ:** `:lua print(vim.env.GEMINI_API_KEY)` и
  `:lua print(vim.env.GEMINI_ENDPOINT)`.
* **Для способа B `GEMINI_INSECURE` не нужен**: при CONNECT-прокси TLS
  устанавливается напрямую между curl и Google, сертификат настоящий.
  `insecure` нужен только в способе A (где TLS терминируется на nginx).

* **Про AmneziaVPN.** Сам протокол AmneziaWG устойчивее обычного WireGuard,
  а в AmneziaVPN на сервере можно включить VLESS/Reality или Cloak — если
  «палит» именно туннель, смена протокола в настройках сервера часто решает
  дело. Но если Google отвечает ошибкой **про страну/тариф** — никакой туннель
  не поможет, это про аккаунт (§1, последний абзац).

* **Вернуть всё назад:** `set -e GEMINI_ENDPOINT; set -e GEMINI_PROXY;
  set -e GEMINI_INSECURE` — и avante снова ходит в Google напрямую.

---

## 5. План B: другой провайдер, если Google так и не пускает

Если чистого выхода нет, а работать надо — avante умеет ходить к любому
OpenAI-совместимому провайдеру. В конфиг уже встроен OpenRouter
(`lua/plugins/avante.lua`, провайдер `openrouter-free`; штатный
`openrouter` в avante: `lua/avante/config.lua:547-553`).

```fish
set -Ux OPENROUTER_API_KEY "sk-or-..."        # ключ: https://openrouter.ai/keys
set -Ux AVANTE_PROVIDER "openrouter-free"     # чат/агент
set -Ux AVANTE_SUGGEST_PROVIDER "openrouter-free"   # inline-подсказки
# модель по желанию (список: https://openrouter.ai/models, бесплатные — ":free")
set -Ux OPENROUTER_MODEL "openrouter/auto"
```

Затем в nvim: `:AvanteRefresh` (или перезапуск). Вернуться к Gemini:
`set -e AVANTE_PROVIDER AVANTE_SUGGEST_PROVIDER`.

Переключить провайдер можно и без переменных — командой `:AvanteSwitchProvider`.

### Проверить ключ OpenRouter, не тратя токены

```fish
curl -sS -w '\n[HTTP %{http_code}] %{time_total}s\n' https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -o /dev/null
# 200 — ключ принимается; 401 — ключ не тот

# найти живые бесплатные модели:
curl -sS https://openrouter.ai/api/v1/models | python3 -c "
import json,sys
d = json.load(sys.stdin)['data']
for m in d:
    p = m.get('pricing') or {}
    if p.get('prompt') == '0' and p.get('completion') == '0':
        print(m['id'])" | head -20
```

`openrouter/auto` роутит на лучшую доступную модель — на аккаунте **без
кредитов** она может оказаться платной и вернуть 402. Тогда поставь
конкретную бесплатную из списка выше:

```fish
set -Ux OPENROUTER_MODEL "автор/модель:free"
```

Бесплатные модели OpenRouter имеют жёсткие лимиты (десятки запросов в день).
Inline-подсказки улетают на каждый останов ввода и быстрее всего упрутся в
429 — если начнёт сыпать ошибками, выключи только подсказки:

```fish
set -Ux AVANTE_SUGGESTIONS 0
```

Чат и агент при этом продолжают работать. Вернуть: `set -e AVANTE_SUGGESTIONS`.

**Не забудь:** `set -Ux` действует только на НОВЫЕ процессы — nvim надо
перезапустить, иначе он не увидит переменные. Проверка внутри nvim:
`:lua print(vim.env.AVANTE_PROVIDER)`.

