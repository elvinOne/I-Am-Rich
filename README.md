# I-Am-Rich

Рабочий репозиторий для экспериментов и self-hosted сервисов.

## Что здесь есть

| Что | Как запустить | Описание |
|---|---|---|
| Кино-тизер «Неоновый дождь» | `python3 scripts/serve-video.py` → открыть `/player.html` | 16-секундный тизер: 4 AI-кадра → Ken Burns, dip-to-black, 2.39:1, зерно, teal/orange-грейдинг, синтезированный саундтрек |
| Пересборка тизера | `FFMPEG=/path/to/ffmpeg ./scripts/build-cinematic-teaser.sh` | ffmpeg-пайплайн сборки видео из кадров |
| Open Generative AI | `./scripts/open-generative-ai.sh` | AI-студия (image/video/lip-sync) на Next.js; ставится и запускается одной командой. Инструкция: [docs/open-generative-ai-setup.md](docs/open-generative-ai-setup.md) |

## Видео: файлы и форматы

Все файлы — в `assets/cinematic-teaser/`:

| Файл | Что это | Размер |
|---|---|---|
| `player.html` | страница-плеер: видео, кнопки скачивания, раскадровка | — |
| `neon-rain-teaser.mp4` | мастер: 1920×1080, 24 fps, H.264 High, AAC 160k, `+faststart` | ~12 МБ |
| `neon-rain-teaser-540p.mp4` | облегчённая версия 960×540, Main profile, стерео AAC — играет везде | ~0.9 МБ |
| `neon-rain-teaser.webm` | VP9 + Opus 1280×720 | ~1.7 МБ |
| `preview.gif` | GIF-превью 480 px, 10 fps | ~8 МБ |
| `contact-sheet.jpg` | раскадровка 2×2 | 0.4 МБ |
| `poster.jpg` | постер-кадр для плеера | 0.2 МБ |
| `shot1–4.png` | исходные AI-кадры 1600×672 | ~11 МБ |

Плеер: `python3 scripts/serve-video.py --port 8080 --dir assets/cinematic-teaser`.
Сервер поддерживает HTTP Range (206) — видео перематывается и играет без полной загрузки;
`python3 -m http.server` для этого не подходит, он Range не умеет.

## Кино-тизер: как сделан

- 4 кадра по единому брифу (неоновый дождь, teal/orange, 35 мм), 1600×672.
- Движение камеры: `zoompan` (push in / pull out разной скорости), переходы — двойное затемнение в чёрное.
- «Плёнка»: `noise` + `vignette` + `unsharp`, грейдинг `eq` + `colorbalance`, активная картинка 2.39:1 в кадре 1920×1080.
- Звук синтезирован: `anoisesrc` (дождь) + синусы 55 и 82.5 Гц (дрон) + затухающий удар 45 Гц на 13.8 с; пик −1.9 дБ.
- Титры — `drawtext` + DejaVu (кириллица), появление/уход по `alpha`-выражению.
