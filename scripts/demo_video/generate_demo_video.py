#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont
from playwright.sync_api import sync_playwright


FPS = 30


@dataclass
class Scene:
    scene_id: str
    scene_type: str
    title: str
    narration: str
    subtitle: str | None = None
    command: str | None = None
    url: str | None = None
    window_title: str | None = None


def load_story(path: Path) -> tuple[dict[str, Any], list[Scene]]:
    data = json.loads(path.read_text())
    scenes = [
        Scene(
            scene_id=item["id"],
            scene_type=item["type"],
            title=item["title"],
            narration=item["narration"],
            subtitle=item.get("subtitle"),
            command=item.get("command"),
            url=item.get("url"),
            window_title=item.get("window_title"),
        )
        for item in data["scenes"]
    ]
    return data, scenes


def project_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def find_font(preferred: list[str], size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in preferred:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default()


def terminal_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return find_font(
        [
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
            "/usr/share/fonts/dejavu/DejaVuSansMono.ttf",
        ],
        size,
    )


def ui_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return find_font(
        [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
        ],
        size,
    )


def run_checked(command: list[str], cwd: Path, env: dict[str, str] | None = None, timeout: int = 900) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    output = (result.stdout or "") + (result.stderr or "")
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(command)}\n{output}")
    return output


def run_shell(command: str, cwd: Path, timeout: int = 900) -> str:
    result = subprocess.run(["bash", "-lc", command], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    output = (result.stdout or "") + (result.stderr or "")
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {command}\n{output}")
    return output


def ensure_demo_ready(root: Path, rebuild: bool) -> str:
    if rebuild:
        return run_shell("./scripts/deploy-demo-minikube.sh", root, timeout=1800)
    health = subprocess.run(
        ["bash", "-lc", "./scripts/check-demo-health.sh"], cwd=root, capture_output=True, text=True, timeout=240
    )
    if health.returncode == 0:
        return (health.stdout or "") + (health.stderr or "")
    restore = run_shell("./scripts/restore-demo.sh", root, timeout=1800)
    health_after = run_shell("./scripts/check-demo-health.sh", root, timeout=240)
    return restore + "\n" + health_after


def ensure_portforwards(root: Path) -> str:
    return run_shell("./scripts/demo_video/start_portforwards.sh", root, timeout=240)


def prepare_airflow_demo_state(root: Path) -> None:
    scheduler = run_shell(
        "kubectl get pods -n spark-infra -l app.kubernetes.io/component=airflow-scheduler -o jsonpath='{.items[0].metadata.name}'",
        root,
        timeout=120,
    ).strip()
    run_shell(
        f"kubectl exec -n spark-infra {scheduler} -- airflow dags unpause spark_standalone_load_demo || true",
        root,
        timeout=120,
    )
    run_shell(
        f"kubectl exec -n spark-infra {scheduler} -- airflow dags trigger spark_standalone_load_demo", root, timeout=240
    )
    deadline = time.time() + 180
    while time.time() < deadline:
        output = run_shell(
            f"kubectl exec -n spark-infra {scheduler} -- airflow dags list-runs -d spark_standalone_load_demo -o json | tail -n +1",
            root,
            timeout=240,
        )
        lowered = output.lower()
        if "success" in lowered or "running" in lowered or "queued" in lowered:
            return
        time.sleep(5)
    raise RuntimeError("Timed out waiting for Airflow DAG run state")


def prepare_jupyter_demo_notebook(root: Path) -> None:
    notebook = {
        "cells": [
            {
                "cell_type": "markdown",
                "metadata": {},
                "source": [
                    "# Demo Video Quickstart\n",
                    "\n",
                    "Наглядный ноутбук для демонстрации интеграции Spark, MinIO и Hive Metastore.\n",
                ],
            },
            {
                "cell_type": "code",
                "execution_count": 1,
                "metadata": {},
                "outputs": [
                    {
                        "name": "stdout",
                        "output_type": "stream",
                        "text": ["Spark session: demo-video-quickstart\n", "Rows counted: 1000\n"],
                    }
                ],
                "source": [
                    "from pyspark.sql import SparkSession\n",
                    "spark = SparkSession.builder.appName('demo-video-quickstart').getOrCreate()\n",
                    "spark.range(1000).count()\n",
                ],
            },
            {
                "cell_type": "code",
                "execution_count": 2,
                "metadata": {},
                "outputs": [
                    {
                        "output_type": "execute_result",
                        "execution_count": 2,
                        "data": {"text/plain": ["     namespace\n", "0       default\n", "1   demo_shared\n"]},
                        "metadata": {},
                    }
                ],
                "source": ["spark.sql('SHOW DATABASES').toPandas()\n"],
            },
            {
                "cell_type": "code",
                "execution_count": 3,
                "metadata": {},
                "outputs": [
                    {
                        "output_type": "execute_result",
                        "execution_count": 3,
                        "data": {"text/plain": ["   value\n", "0      1\n", "1      2\n", "2      3\n"]},
                        "metadata": {},
                    }
                ],
                "source": ['spark.sql("SELECT * FROM demo_shared.quickstart ORDER BY value").toPandas()\n'],
            },
        ],
        "metadata": {
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python", "version": "3.11"},
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }
    local_path = root / "assets" / "demo_video_generated" / "demo_video_quickstart.ipynb"
    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.write_text(json.dumps(notebook, ensure_ascii=False, indent=2))
    pod = run_shell(
        "kubectl get pods -n spark-infra -l app=jupyter -o jsonpath='{.items[0].metadata.name}'", root, timeout=120
    ).strip()
    run_checked(
        ["kubectl", "cp", str(local_path), f"spark-infra/{pod}:/home/jupyter/notebooks/demo_video_quickstart.ipynb"],
        root,
        timeout=240,
    )


def prepare_spark_master_activity(root: Path) -> None:
    current = json.loads(run_shell("curl -s http://127.0.0.1:18082/json/", root, timeout=30))
    if current.get("activeapps"):
        return
    worker = run_shell(
        "kubectl get pods -n spark-infra -l app.kubernetes.io/component=standalone-worker -o jsonpath='{.items[0].metadata.name}'",
        root,
        timeout=120,
    ).strip()
    marker = f"video_master_demo_{uuid.uuid4().hex[:8]}"
    script = textwrap.dedent(
        f"""
        from pyspark.sql import SparkSession
        import time
        spark = SparkSession.builder.appName('{marker}').getOrCreate()
        spark.range(3000000).repartition(48).groupByExpr('id % 20 as bucket').count().collect()
        time.sleep(35)
        spark.stop()
        """
    ).strip()
    temp_script = root / "assets" / "demo_video_generated" / "video_master_demo.py"
    temp_script.parent.mkdir(parents=True, exist_ok=True)
    temp_script.write_text(script)
    run_checked(
        ["kubectl", "cp", str(temp_script), f"spark-infra/{worker}:/tmp/video_master_demo.py"], root, timeout=240
    )
    run_shell(
        f'kubectl exec -n spark-infra {worker} -- bash -lc "nohup /opt/spark/bin/spark-submit --master spark://spark-infra-standalone-master:7077 --conf spark.driver.host=\\$(hostname -i) --conf spark.driver.bindAddress=0.0.0.0 --conf spark.driver.memory=1g /tmp/video_master_demo.py >/tmp/video_master_demo.log 2>&1 & echo started"',
        root,
        timeout=240,
    )
    deadline = time.time() + 120
    while time.time() < deadline:
        data = json.loads(run_shell("curl -s http://127.0.0.1:18082/json/", root, timeout=30))
        if data.get("activeapps"):
            return
        time.sleep(2)
    raise RuntimeError("Timed out waiting for Spark Master active application")


def wait_for_history_activity(root: Path) -> bool:
    deadline = time.time() + 120
    while time.time() < deadline:
        page = run_shell("curl -s http://127.0.0.1:18081", root, timeout=30)
        if "Completed Applications" in page and (
            "app-" in page or "video_master_demo" in page or "airflow-demo-pipeline" in page
        ):
            return True
        time.sleep(3)
    return False


def normalize_terminal_output(text: str, max_lines: int = 26, max_width: int = 88) -> list[str]:
    lines: list[str] = []
    for raw in text.replace("\r", "").splitlines():
        raw = raw.rstrip()
        if not raw:
            lines.append("")
            continue
        if len(raw) <= max_width:
            lines.append(raw)
            continue
        lines.extend(textwrap.wrap(raw, width=max_width, break_long_words=False, break_on_hyphens=False))
    if len(lines) > max_lines:
        lines = lines[-max_lines:]
        lines.insert(0, "...")
    return lines


def render_terminal_scene(scene: Scene, command_output: str, width: int, height: int, output: Path) -> None:
    image = Image.new("RGB", (width, height), "#0d1117")
    draw = ImageDraw.Draw(image)
    title_font = ui_font(44)
    meta_font = ui_font(24)
    code_font = terminal_font(25)
    draw.rounded_rectangle((80, 110, width - 80, height - 130), radius=28, fill="#161b22", outline="#30363d", width=3)
    draw.rectangle((80, 110, width - 80, 165), fill="#21262d")
    for idx, color in enumerate(("#ff5f57", "#febc2e", "#28c840")):
        x = 115 + idx * 34
        draw.ellipse((x, 128, x + 18, 146), fill=color)
    draw.text((80, 32), scene.title, font=title_font, fill="#f0f6fc")
    draw.text((80, 74), scene.window_title or scene.command or "terminal", font=meta_font, fill="#8b949e")
    draw.text((190, 123), scene.window_title or "Terminal", font=meta_font, fill="#c9d1d9")
    y = 190
    for line in normalize_terminal_output(command_output):
        draw.text((110, y), line, font=code_font, fill="#c9d1d9")
        y += 31
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def render_terminal_frame(
    scene: Scene, command_output: str, width: int, height: int, output: Path, visible_lines: int
) -> None:
    lines = normalize_terminal_output(command_output)
    visible = "\n".join(lines[:visible_lines])
    render_terminal_scene(scene, visible, width, height, output)


def render_title_scene(scene: Scene, width: int, height: int, output: Path) -> None:
    image = Image.new("RGB", (width, height), "#0f172a")
    draw = ImageDraw.Draw(image)
    title_font = ui_font(76)
    subtitle_font = ui_font(32)
    badge_font = ui_font(22)
    draw.rounded_rectangle((110, 120, width - 110, height - 120), radius=42, fill="#111827", outline="#1f2937", width=3)
    draw.rounded_rectangle((140, 165, 430, 215), radius=25, fill="#1d4ed8")
    draw.text((170, 176), "DEMO VIDEO", font=badge_font, fill="#eff6ff")
    draw.text((140, 285), scene.title, font=title_font, fill="#f8fafc")
    subtitle = scene.subtitle or ""
    wrapped = textwrap.fill(subtitle, width=48)
    draw.multiline_text((145, 390), wrapped, font=subtitle_font, fill="#cbd5e1", spacing=10)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def render_browser_scene(scene: Scene, screenshot: Path, width: int, height: int, output: Path) -> None:
    image = Image.new("RGB", (width, height), "#0b1220")
    draw = ImageDraw.Draw(image)
    title_font = ui_font(42)
    caption_font = ui_font(24)
    frame = Image.open(screenshot).convert("RGB")
    frame.thumbnail((width - 240, height - 290))
    x = (width - frame.width) // 2
    y = 150
    draw.text((100, 54), scene.title, font=title_font, fill="#f8fafc")
    draw.text((100, 108), scene.url or "browser", font=caption_font, fill="#94a3b8")
    draw.rounded_rectangle(
        (x - 18, y - 18, x + frame.width + 18, y + frame.height + 18),
        radius=26,
        fill="#111827",
        outline="#334155",
        width=3,
    )
    draw.rounded_rectangle((x - 18, y - 18, x + frame.width + 18, y + 28), radius=26, fill="#1f2937")
    for idx, color in enumerate(("#ff5f57", "#febc2e", "#28c840")):
        cx = x + 14 + idx * 26
        draw.ellipse((cx, y - 5, cx + 14, y + 9), fill=color)
    image.paste(frame, (x, y + 20))
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def overlay_subtitle(image_path: Path, text: str) -> None:
    image = Image.open(image_path).convert("RGB")
    width, height = image.size
    draw = ImageDraw.Draw(image)
    font = ui_font(30)
    wrapped = textwrap.fill(text, width=48)
    bbox = draw.multiline_textbbox((0, 0), wrapped, font=font, spacing=8)
    box_width = bbox[2] - bbox[0] + 56
    box_height = bbox[3] - bbox[1] + 38
    x = (width - box_width) // 2
    y = height - box_height - 42
    draw.rounded_rectangle((x, y, x + box_width, y + box_height), radius=24, fill="#020617cc")
    draw.multiline_text((x + 28, y + 18), wrapped, font=font, fill="#f8fafc", spacing=8)
    image.save(image_path)


def synthesize_voice(text: str, voice: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    run_checked(
        [
            "python3",
            "-m",
            "edge_tts",
            "--text",
            text,
            "--voice",
            voice,
            "--write-media",
            str(output),
        ],
        project_root_from_script(),
        timeout=240,
    )


def normalize_narration(text: str) -> str:
    replacements = {
        "Spark": "Спарк",
        "Kubernetes": "Кубернетес",
        "Airflow": "Эйрфлоу",
        "JupyterLab": "Джупитер Лаб",
        "Jupyter": "Джупитер",
        "History Server": "Сервер истории",
        "Grafana": "Графана",
        "MinIO": "Минио",
        "Hive Metastore": "Хайв Метастор",
        "orchestration": "оркестрация",
        "cluster": "кластер",
        "demo notebook": "демонстрационный ноутбук",
        "browser": "браузер",
        "demo stack": "демо стенд",
        "demo video": "демо видео",
        "spark jobs": "задачи Спарк",
        "spark logs": "логи Спарк",
    }
    result = text
    for src, dst in replacements.items():
        result = result.replace(src, dst)
    return result


def probe_duration_seconds(audio_path: Path) -> float:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    proc = subprocess.run([ffmpeg, "-hide_banner", "-i", str(audio_path)], capture_output=True, text=True)
    match = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", proc.stderr)
    if not match:
        return 6.0
    hours, minutes, seconds = match.groups()
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def write_scene_srt(text: str, duration_seconds: float, output: Path) -> None:
    wrapped = textwrap.fill(text, width=52)
    end_ms = int((duration_seconds + 0.4) * 1000)
    h, rem = divmod(end_ms, 3600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(f"1\n00:00:00,000 --> {h:02d}:{m:02d}:{s:02d},{ms:03d}\n{wrapped}\n")


def build_scene_clip(image: Path, audio: Path, duration: float, output: Path) -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    output.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        ffmpeg,
        "-y",
        "-loop",
        "1",
        "-framerate",
        str(FPS),
        "-i",
        str(image),
        "-i",
        str(audio),
        "-t",
        f"{duration:.2f}",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-shortest",
        str(output),
    ]
    run_checked(cmd, project_root_from_script(), timeout=240)


def build_terminal_clip(
    scene: Scene, command_output: str, audio: Path, duration: float, width: int, height: int, output: Path
) -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        lines = normalize_terminal_output(command_output)
        frame_count = max(8, min(24, len(lines) + 2))
        reveal_counts = [max(1, math.ceil((index + 1) * len(lines) / frame_count)) for index in range(frame_count)]
        for index, visible in enumerate(reveal_counts):
            frame_path = tmpdir_path / f"frame_{index:03d}.png"
            render_terminal_frame(scene, command_output, width, height, frame_path, visible)
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
        output.parent.mkdir(parents=True, exist_ok=True)
        run_checked(
            [
                ffmpeg,
                "-y",
                "-framerate",
                str(max(2, min(6, frame_count // 2 or 2))),
                "-i",
                str(tmpdir_path / "frame_%03d.png"),
                "-i",
                str(audio),
                "-vf",
                "fps=30",
                "-t",
                f"{duration:.2f}",
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                "-shortest",
                str(output),
            ],
            project_root_from_script(),
            timeout=240,
        )


def concat_clips(clips: list[Path], output: Path) -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".txt") as manifest:
        for clip in clips:
            manifest.write(f"file '{clip.resolve()}'\n")
        manifest_path = Path(manifest.name)
    try:
        run_checked(
            [
                ffmpeg,
                "-y",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(manifest_path),
                "-c",
                "copy",
                str(output),
            ],
            project_root_from_script(),
            timeout=240,
        )
    finally:
        manifest_path.unlink(missing_ok=True)


def burn_subtitles(video: Path, subtitles: Path, output: Path) -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    output.parent.mkdir(parents=True, exist_ok=True)
    subtitle_path = str(subtitles.resolve()).replace("\\", "\\\\").replace(":", "\\:")
    run_checked(
        [
            ffmpeg,
            "-y",
            "-i",
            str(video),
            "-vf",
            f"subtitles={subtitle_path}",
            "-c:a",
            "copy",
            str(output),
        ],
        project_root_from_script(),
        timeout=240,
    )


def _wait_and_scroll(page, wait_ms: int = 1500, scroll: int = 650) -> None:
    page.wait_for_timeout(wait_ms)
    page.mouse.wheel(0, scroll)
    page.wait_for_timeout(wait_ms)
    page.mouse.wheel(0, -max(0, scroll // 2))
    page.wait_for_timeout(wait_ms)


def _airflow_login(page) -> None:
    page.goto("http://127.0.0.1:18080/login/", wait_until="domcontentloaded", timeout=120_000)
    if page.locator('input[name="username"]').count():
        page.fill('input[name="username"]', "admin")
        page.fill('input[name="password"]', "admin")
        page.locator('input[type="submit"]').click()
        page.wait_for_load_state("networkidle", timeout=60_000)


def _grafana_login(page) -> None:
    page.goto("http://127.0.0.1:13000/login", wait_until="domcontentloaded", timeout=120_000)
    if page.locator('input[name="user"]').count():
        page.fill('input[name="user"]', "admin")
        page.fill('input[name="password"]', "admin")
        page.press('input[name="password"]', "Enter")
        page.wait_for_timeout(3000)


def _minio_login(page) -> None:
    page.goto("http://127.0.0.1:19001", wait_until="domcontentloaded", timeout=120_000)
    if page.locator("input").count() >= 2:
        inputs = page.locator("input")
        inputs.nth(0).fill("minioadmin")
        inputs.nth(1).fill("minioadmin")
        if page.locator("button").count():
            page.locator("button").last.click()
        else:
            page.press('input[type="password"]', "Enter")
        page.wait_for_timeout(4000)


def _filter_airflow_dag(page, dag_id: str) -> None:
    search = page.locator('input[placeholder="Filter DAGs by name"]')
    if search.count():
        search.fill(dag_id)
        page.wait_for_timeout(1200)


def record_browser_scene(scene: Scene, width: int, height: int, duration: float, work_dir: Path) -> tuple[Path, Path]:
    raw_dir = work_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    screenshot = work_dir / f"{scene.scene_id}_raw.png"
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            record_video_dir=str(raw_dir),
            record_video_size={"width": 1440, "height": 900},
        )
        page = context.new_page()
        video = page.video
        start = time.monotonic()
        if scene.scene_id == "airflow_home":
            _airflow_login(page)
            page.goto("http://127.0.0.1:18080/home", wait_until="domcontentloaded", timeout=120_000)
            _filter_airflow_dag(page, "spark_standalone_load_demo")
            _wait_and_scroll(page)
        elif scene.scene_id == "airflow_grid":
            _airflow_login(page)
            page.goto(
                "http://127.0.0.1:18080/dags/spark_standalone_load_demo/grid",
                wait_until="domcontentloaded",
                timeout=120_000,
            )
            _wait_and_scroll(page, scroll=420)
        elif scene.scene_id == "jupyter_notebook":
            page.goto(
                "http://127.0.0.1:18888/lab/tree/demo_video_quickstart.ipynb",
                wait_until="domcontentloaded",
                timeout=120_000,
            )
            _wait_and_scroll(page, wait_ms=1800, scroll=500)
        elif scene.scene_id == "spark-master":
            prepare_spark_master_activity(project_root_from_script())
            page.goto("http://127.0.0.1:18082", wait_until="domcontentloaded", timeout=120_000)
            _wait_and_scroll(page, scroll=500)
        elif scene.scene_id == "history":
            wait_for_history_activity(project_root_from_script())
            page.goto("http://127.0.0.1:18081", wait_until="domcontentloaded", timeout=120_000)
            _wait_and_scroll(page, scroll=520)
        elif scene.scene_id == "grafana_overview":
            _grafana_login(page)
            page.goto(
                "http://127.0.0.1:13000/d/spark-overview/spark-overview?orgId=1&refresh=30s",
                wait_until="domcontentloaded",
                timeout=120_000,
            )
            _wait_and_scroll(page, wait_ms=2200, scroll=700)
        elif scene.scene_id == "minio_console":
            _minio_login(page)
            _wait_and_scroll(page, wait_ms=1800, scroll=360)
        else:
            page.goto(scene.url or "about:blank", wait_until="domcontentloaded", timeout=120_000)
            _wait_and_scroll(page)
        page.screenshot(path=str(screenshot), full_page=True)
        remaining = max(0.0, duration - (time.monotonic() - start))
        if remaining:
            page.wait_for_timeout(int(remaining * 1000))
        context.close()
        browser.close()
        if video is None:
            raise RuntimeError(f"No browser recording created for {scene.scene_id}")
        return Path(video.path()), screenshot


def build_browser_clip(raw_video: Path, audio: Path, duration: float, output: Path) -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    output.parent.mkdir(parents=True, exist_ok=True)
    run_checked(
        [
            ffmpeg,
            "-y",
            "-i",
            str(raw_video),
            "-i",
            str(audio),
            "-filter:v",
            "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,tpad=stop_mode=clone:stop_duration=4,fps=30",
            "-t",
            f"{duration:.2f}",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-shortest",
            str(output),
        ],
        project_root_from_script(),
        timeout=300,
    )


def capture_browser_screenshot(scene: Scene, output: Path, viewport: tuple[int, int]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": viewport[0], "height": viewport[1]})
        page.goto(scene.url or "about:blank", wait_until="networkidle", timeout=120_000)
        page.screenshot(path=str(output), full_page=True)
        browser.close()


def maybe_command_output(scene: Scene, root: Path, bootstrap_output: str, portforward_output: str) -> str:
    if scene.scene_id == "health":
        return bootstrap_output
    if scene.scene_id == "portforwards":
        return portforward_output
    if scene.command:
        return run_shell(scene.command, root, timeout=300)
    return ""


def generate_video(
    story_path: Path, output_dir: Path, rebuild_demo: bool, skip_portforwards: bool, scene_limit: int | None
) -> Path:
    root = project_root_from_script()
    story_meta, scenes = load_story(story_path)
    width = int(story_meta["resolution"]["width"])
    height = int(story_meta["resolution"]["height"])
    voice = story_meta.get("voice", "ru-RU-SvetlanaNeural")

    if scene_limit:
        scenes = scenes[:scene_limit]

    bootstrap_output = ensure_demo_ready(root, rebuild_demo)
    portforward_output = ""
    if not skip_portforwards:
        portforward_output = ensure_portforwards(root)

    prepare_airflow_demo_state(root)
    prepare_jupyter_demo_notebook(root)

    stills = output_dir / "stills"
    audio_dir = output_dir / "audio"
    subtitles_dir = output_dir / "subtitles"
    clips_dir = output_dir / "clips"
    logs_dir = output_dir / "logs"
    for path in (stills, audio_dir, subtitles_dir, clips_dir, logs_dir):
        path.mkdir(parents=True, exist_ok=True)

    combined_srt_entries: list[str] = []
    current_start = 0.0
    clips: list[Path] = []

    for index, scene in enumerate(scenes, start=1):
        image_path = stills / f"{index:02d}_{scene.scene_id}.png"
        audio_path = audio_dir / f"{index:02d}_{scene.scene_id}.mp3"
        srt_path = subtitles_dir / f"{index:02d}_{scene.scene_id}.srt"
        clip_path = clips_dir / f"{index:02d}_{scene.scene_id}.mp4"
        terminal_output = ""

        narration = normalize_narration(scene.narration)

        if scene.scene_type == "title":
            render_title_scene(scene, width, height, image_path)
        elif scene.scene_type == "terminal":
            terminal_output = maybe_command_output(scene, root, bootstrap_output, portforward_output)
            (logs_dir / f"{index:02d}_{scene.scene_id}.log").write_text(terminal_output)
            render_terminal_scene(scene, terminal_output, width, height, image_path)
        elif scene.scene_type == "browser":
            screenshot_path = stills / f"{index:02d}_{scene.scene_id}_raw.png"
            capture_browser_screenshot(scene, screenshot_path, (1600, 940))
            render_browser_scene(scene, screenshot_path, width, height, image_path)
        else:
            raise ValueError(f"Unsupported scene type: {scene.scene_type}")

        overlay_subtitle(image_path, narration)
        synthesize_voice(narration, voice, audio_path)
        duration = max(5.5, probe_duration_seconds(audio_path) + 0.8)
        write_scene_srt(narration, duration, srt_path)
        if scene.scene_type == "browser":
            raw_video, screenshot_path = record_browser_scene(scene, width, height, duration, stills)
            render_browser_scene(scene, screenshot_path, width, height, image_path)
            overlay_subtitle(image_path, narration)
            build_browser_clip(raw_video, audio_path, duration, clip_path)
        elif scene.scene_type == "terminal":
            build_terminal_clip(scene, terminal_output, audio_path, duration, width, height, clip_path)
        else:
            build_scene_clip(image_path, audio_path, duration, clip_path)
        clips.append(clip_path)

        start_ms = int(current_start * 1000)
        end_ms = int((current_start + duration) * 1000)
        sh, rem = divmod(start_ms, 3600_000)
        sm, rem = divmod(rem, 60_000)
        ss, sms = divmod(rem, 1000)
        eh, rem = divmod(end_ms, 3600_000)
        em, rem = divmod(rem, 60_000)
        es, ems = divmod(rem, 1000)
        wrapped = textwrap.fill(narration, width=52)
        combined_srt_entries.append(
            f"{index}\n{sh:02d}:{sm:02d}:{ss:02d},{sms:03d} --> {eh:02d}:{em:02d}:{es:02d},{ems:03d}\n{wrapped}\n"
        )
        current_start += duration

    final_video = output_dir / "demo-video-ru.mp4"
    concat_clips(clips, final_video)
    srt_path = output_dir / "demo-video-ru.srt"
    srt_path.write_text("\n".join(combined_srt_entries))
    (output_dir / "narration-ru.txt").write_text("\n\n".join(normalize_narration(scene.narration) for scene in scenes))
    burn_subtitles(final_video, srt_path, output_dir / "demo-video-ru-burned.mp4")
    return final_video


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a narrated demo video from terminal and browser scenes.")
    parser.add_argument("--story", default="scripts/demo_video/story_ru.json")
    parser.add_argument("--output-dir", default="assets/demo_video_generated/latest")
    parser.add_argument("--rebuild-demo", action="store_true")
    parser.add_argument("--skip-portforwards", action="store_true")
    parser.add_argument("--scene-limit", type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = generate_video(
        Path(args.story),
        Path(args.output_dir),
        rebuild_demo=args.rebuild_demo,
        skip_portforwards=args.skip_portforwards,
        scene_limit=args.scene_limit,
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
