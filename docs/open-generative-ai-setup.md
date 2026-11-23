# Как запустить Open Generative AI (Anil-matcha/Open-Generative-AI)

Заметка по итогам запуска в песочнице Arena, 2026-11-23.

- Источник: https://github.com/Anil-matcha/Open-Generative-AI (MIT, ~35k звёзд)
- Стек: Next.js 15 (App Router) + React + Tailwind; npm-workspaces: `studio`, `workflow-builder`, `ai-agent`, `design-agent`; Electron-обёртка для десктопа.
- Генерация: облачные модели — через API Muapi.ai (платный ключ, BYOK, хранится в `localStorage`); локальные модели (sd.cpp, Wan2GP) — только в десктопной Electron-сборке.

## Одна команда

```bash
./scripts/open-generative-ai.sh          # setup + dev, всё сразу
./scripts/open-generative-ai.sh setup    # клон, зависимости, сборка пакетов
./scripts/open-generative-ai.sh dev      # запуск dev-сервера
./scripts/open-generative-ai.sh patch    # только патчи для превью/iframe
```

Переменные: `DIR` (куда клонировать, по умолчанию `$HOME/Open-Generative-AI`), `PORT` (3000), `HOST` (0.0.0.0), `REPO`.

Приложение открывается на `http://localhost:3000/studio` (`/` редиректит туда же). Первая компиляция страницы — ~35 c, это нормально.

## Что скрипт делает неочевидного

1. `ELECTRON_SKIP_BINARY_DOWNLOAD=1` перед `npm install`. Postinstall Electron тянет бинарник с electronjs.org и падает с `unable to verify the first certificate`. Для веб-версии он не нужен; для десктопа ставить без этой переменной и с нормальным доступом в сеть.
2. `npm run build:packages` обязателен: `npm install` сам по себе не собирает workspace-пакеты, без этого `next dev` не стартует.
3. Патч `middleware.js`: убирает `X-Frame-Options: DENY` и добавляет `frame-ancestors *` в CSP — иначе приложение нельзя открыть в iframe (превью Arena).
4. Патч `next.config.mjs`: `allowedDevOrigins` для доменов превью-прокси (`*.e2b.app`, `*.arena.ai`), иначе Next.js будет ругаться на cross-origin запросы к `/_next/*`.

Все патчи идемпотентны — повторный прогон ничего не ломает. Оригиналы не коммитятся в этот репозиторий: скрипт правит только локальную копию проекта.

## Ключ API и деньги

- Ключ: https://muapi.ai/access-keys → вставить в приложении (модалка BYOK).
- Без ключа интерфейс работает, генерация — нет: «800+ моделей» = платные вызовы Muapi.ai (submit → poll).
- Полностью бесплатно/офлайн — только десктопная сборка и только image-модели через sd.cpp; видео — отдельный Wan2GP и NVIDIA/AMD GPU.

## Если нужен свой репозиторий с этим кодом

| Вариант | Как | Комментарий |
|---|---|---|
| Готовое приложение | `muapi.ai/open-generative-ai` либо установщик из Releases v2.0.0 | быстрее всего, но без правок кода |
| Fork в свой аккаунт | кнопка **Fork** на GitHub, затем новая сессия Arena на форке | форк из песочницы не проходит: GitHub-токен выдан только на `elvinOne/I-Am-Rich` (403 `Resource not accessible by integration`) |
| Влить исходники в `I-Am-Rich` | скопировать дерево без `.git`/`node_modules`, один коммит | репозиторий станет «своим», но обновления upstream придётся мержить вручную |
