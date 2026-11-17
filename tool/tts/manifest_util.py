"""assets/audio/manifest.json을 여러 생성 스크립트가 동시에 고쳐도 안전하게 갱신한다.

엔진마다 맡은 언어가 다르다(engines.json). 각 스크립트는 자기 파일 항목만 넣거나 지우고,
쓰기 직전에 잠금 파일을 잡은 뒤 최신 목록을 다시 읽어 합친다.
"""

import json
import os
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"
LOCK = AUDIO / ".manifest.lock"
ENGINES = json.loads((Path(__file__).parent / "engines.json").read_text(encoding="utf-8"))

HEADER = {
    "engine": "supertonic-3",
    "license": (
        "Supertonic 3 model: BigScience OpenRAIL-M (en, ja, ko, fr, es); "
        "Kokoro-82M: Apache-2.0 (en_gb); Qwen3-TTS: Apache-2.0 (zh) — machine-generated voice"
    ),
}


def read() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]


def update(add: dict | None = None, remove: set | None = None) -> None:
    """add 항목을 넣고(같은 경로는 덮어씀) remove 경로를 지운다."""
    for _ in range(600):
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except FileExistsError:
            time.sleep(0.05)
    else:
        raise TimeoutError(f"manifest lock busy: {LOCK}")
    try:
        files = read()
        for key in remove or ():
            files.pop(key, None)
        files.update(add or {})
        manifest = {**HEADER, "files": dict(sorted(files.items()))}
        tmp = MANIFEST.with_suffix(".tmp")
        tmp.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
        # 윈도우에서는 다른 프로세스가 목록을 읽는 순간 바꿔치기가 거부될 수 있어 잠시 뒤 다시 시도한다.
        for attempt in range(100):
            try:
                os.replace(tmp, MANIFEST)
                break
            except PermissionError:
                if attempt == 99:
                    raise
                time.sleep(0.1)
    finally:
        os.close(fd)
        os.remove(LOCK)


def langs_for(engine: str) -> list[str]:
    return [lang for lang, spec in ENGINES.items() if spec["engine"] == engine]


# 초급 기초 단어는 언어마다 이 캐릭터의 목소리로 읽는다(단어·예문 모두).
WORD_VOICE = "mia"


def word_jobs(lang: str) -> list[tuple[str, str]]:
    """assets/content/<언어>/words.json의 (음성 경로, 읽을 글) 목록. 파일이 없으면 빈 목록."""
    path = ROOT / "assets" / "content" / lang / "words.json"
    if not path.exists():
        return []
    book = json.loads(path.read_text(encoding="utf-8"))
    jobs = []
    for cat in book["categories"]:
        for w in cat["items"]:
            jobs.append((f"{lang}/words/{cat['id']}__{w['id']}.mp3", w["text"]))
            jobs.append((f"{lang}/words/{cat['id']}__{w['id']}__ex.mp3", w["example"]))
    return jobs
