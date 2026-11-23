#!/usr/bin/env bash
# Установка и запуск Open Generative AI (https://github.com/Anil-matcha/Open-Generative-AI)
# в режиме веб-версии: клон с сабмодулями, npm install, сборка workspace-пакетов, next dev.
#
# Использование:
#   ./scripts/open-generative-ai.sh all      # поставить (если нужно) и запустить dev-сервер
#   ./scripts/open-generative-ai.sh setup    # только установка/обновление
#   ./scripts/open-generative-ai.sh dev      # только запуск (после setup)
#   ./scripts/open-generative-ai.sh patch    # только применить патчи для iframe/превью
#
# Переменные окружения:
#   DIR   — куда клонировать (по умолчанию $HOME/Open-Generative-AI)
#   PORT  — порт dev-сервера (по умолчанию 3000)
#   HOST  — адрес привязки (по умолчанию 0.0.0.0, чтобы работало превью в песочнице)
#   REPO  — URL репозитория
set -euo pipefail

REPO="${REPO:-https://github.com/Anil-matcha/Open-Generative-AI.git}"
DIR="${DIR:-$HOME/Open-Generative-AI}"
PORT="${PORT:-3000}"
HOST="${HOST:-0.0.0.0}"
CMD="${1:-all}"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

need_node() {
  command -v node >/dev/null || { echo "Нужен Node.js 18+"; exit 1; }
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 18 ] || { echo "Нужен Node.js 18+, сейчас $(node -v)"; exit 1; }
}

# Хакерский, но идемпотентный патч: приложение по умолчанию отдаёт
# X-Frame-Options: DENY и не содержит привязку к домену превью,
# из-за чего его нельзя открыть в iframe (превью Arena).
patch_preview() {
  [ -f "$DIR/middleware.js" ] || { echo "Нет $DIR/middleware.js — сначала setup"; exit 1; }
  python3 - "$DIR/middleware.js" "$DIR/next.config.mjs" <<'PY'
import sys
mid, cfg = sys.argv[1], sys.argv[2]

s = open(mid).read(); orig = s
s = s.replace(
    "    response.headers.set('X-Frame-Options', 'DENY');",
    "    // [preview patch] X-Frame-Options убран, чтобы приложение открывалось в iframe",
)
if "frame-ancestors" not in s:
    s = s.replace('"default-src \'self\';', '"frame-ancestors *; default-src \'self\';')
if s != orig:
    open(mid, "w").write(s)
    print("patched middleware.js")

c = open(cfg).read(); orig = c
if "allowedDevOrigins" not in c:
    c = c.replace(
        "const nextConfig = {",
        "const nextConfig = {\n  // [preview patch] разрешаем dev-запросы с доменов превью-прокси\n  allowedDevOrigins: ['*.e2b.app', '*.arena.ai', '*.localhost'],",
        1,
    )
if c != orig:
    open(cfg, "w").write(c)
    print("patched next.config.mjs")
PY
}

setup() {
  need_node
  if [ ! -d "$DIR/.git" ]; then
    log "Клонирую в $DIR"
    git clone --recurse-submodules "$REPO" "$DIR"
  else
    log "Репозиторий уже есть — обновляю"
    git -C "$DIR" pull --ff-only || true
    git -C "$DIR" submodule update --init --recursive
  fi
  patch_preview
  log "Ставлю зависимости (Electron-бинарник пропускаю: для веба он не нужен)"
  ( cd "$DIR" && ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm install --no-audit --no-fund )
  log "Собираю workspace-пакеты (обязательный шаг)"
  ( cd "$DIR" && npm run build:packages )
  log "Готово. Запуск: DIR=$DIR $0 dev"
}

dev() {
  need_node
  [ -d "$DIR/node_modules" ] || { echo "Сначала: $0 setup"; exit 1; }
  [ -d "$DIR/packages/studio/dist" ] || { echo "Пакеты не собраны: $0 setup"; exit 1; }
  log "Dev-сервер на http://$HOST:$PORT/studio"
  cd "$DIR" && exec npx next dev -H "$HOST" -p "$PORT"
}

case "$CMD" in
  setup) setup ;;
  dev) dev ;;
  patch) patch_preview ;;
  all) setup; dev ;;
  *) echo "Неизвестная команда: $CMD (setup|dev|patch|all)"; exit 1 ;;
esac
