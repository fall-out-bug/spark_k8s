# Генератор demo video

Скрипт собирает demo video из двух типов сцен:
- terminal scenes — запуск health check и browser port-forward
- browser scenes — Airflow, Jupyter, Spark Master, History Server, Grafana и MinIO

Pipeline делает:
1. проверку demo stack через canonical scripts
2. запуск локальных port-forward
3. browser screenshots через Playwright
4. русскую voiceover дорожку через `edge-tts`
5. subtitles (`.srt`)
6. финальную склейку MP4 через bundled `imageio-ffmpeg`

## Запуск

```bash
./scripts/generate-demo-video.sh
```

Выходные артефакты по умолчанию появляются в:

```bash
assets/demo_video_generated/latest/
```

Ключевые файлы:
- `demo-video-ru.mp4`
- `demo-video-ru.srt`
- `narration-ru.txt`

## Полезные флаги

```bash
./scripts/generate-demo-video.sh --scene-limit 3
./scripts/generate-demo-video.sh --skip-portforwards
./scripts/generate-demo-video.sh --rebuild-demo
./scripts/generate-demo-video.sh --output-dir assets/demo_video_generated/full-run
```

## Без sudo

Pipeline рассчитан на user-space зависимости:
- `python3 -m pip install --user edge-tts imageio imageio-ffmpeg pillow playwright`
- `python3 -m playwright install chromium`

## Что показывается

Сценарий берется из `scripts/demo_video/story_ru.json`.

По умолчанию используются URL:
- Airflow: `http://127.0.0.1:18080`
- Jupyter: `http://127.0.0.1:18888/lab`
- History: `http://127.0.0.1:18081`
- Spark Master: `http://127.0.0.1:18082`
- Grafana: `http://127.0.0.1:13000/login`
- MinIO Console: `http://127.0.0.1:19001`

## Ограничения

- Grafana и MinIO по умолчанию снимаются как browser endpoints без интерактивного логина.
- Если нужен полностью живой walkthrough с кликами, поверх этого pipeline можно добавить Playwright actions в `generate_demo_video.py`.
- `--rebuild-demo` может занять заметно больше времени, потому что включает bootstrap/recovery demo stack.
