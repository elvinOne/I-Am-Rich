# I-Am-Rich

Рабочий репозиторий для экспериментов и self-hosted сервисов.

## Что здесь есть

| Что | Как запустить | Описание |
|---|---|---|
| Open Generative AI | `./scripts/open-generative-ai.sh` | AI-студия (image/video/lip-sync) на Next.js; ставится и запускается одной командой. Инструкция: [docs/open-generative-ai-setup.md](docs/open-generative-ai-setup.md) |
| Кино-тизер «Неоновый дождь» | `./scripts/build-cinematic-teaser.sh` | 16-секундный кинематографический тизер: 4 AI-кадра → Ken Burns, dip-to-black, 2.39:1, зерно, теal/orange-грейдинг, синтезированный саундтрек. Файл: [assets/cinematic-teaser/neon-rain-teaser.mp4](assets/cinematic-teaser/neon-rain-teaser.mp4) |

## Кино-тизер: что внутри

- 1920×1080, 24 fps, активная картинка 2.39:1 (чёрные поля), 16 секунд, H.264 + AAC.
- 4 кадра, сгенерированные по единому визуальному брифу (неоновый дождь, teal/orange, 35 мм).
- Движение камеры: `zoompan` (push in / pull out разной скорости), переходы — двойное затемнение в чёрное.
- «Плёнка»: `noise` + `vignette` + `unsharp`, грейдинг `eq` + `colorbalance`.
- Звук синтезирован из `anoisesrc` (дождь), двух синусов (дрон 55 и 82.5 Гц) и затухающего удара 45 Гц на 13.8 с.
- Титры — `drawtext` с DejaVu (кириллица), с плавным появлением/уходом по `alpha`-выражению.

Пересобрать: `FFMPEG=/path/to/ffmpeg ./scripts/build-cinematic-teaser.sh` (нужен ffmpeg с `zoompan`, `drawtext`, `noise`, `vignette`, `colorbalance`).
