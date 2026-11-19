"""Hugging Face Space(Docker)에 올릴 TTS 서버 폴더를 만든다: build/tts_space/

서버 코드 + 목소리 설정(catalog.json, engines.json 복사본)만 담는다. 음성 파일·콘텐츠는 담지 않는다.
사용법: python server/tts/prepare_space.py
그다음 build/tts_space/ 내용을 Space 저장소에 올린다(README의 '배포' 참고).
"""

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent
OUT = ROOT / "build" / "tts_space"

README = """---
title: BUTTERFUL TTS
emoji: 🧈
colorFrom: yellow
colorTo: red
sdk: docker
app_port: 7860
pinned: false
license: other
---

BUTTERFUL 중급 AI 회화용 캐릭터 음성 서버(Supertonic 3, Kokoro-82M).
BUTTERFUL Edge Function만 호출할 수 있다(X-Tts-Key). 받은 문장과 음성은 저장하지 않는다.
모델 라이선스: Supertonic 3 — BigScience OpenRAIL-M, Kokoro-82M — Apache-2.0.
"""


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "data" / "assets" / "content").mkdir(parents=True)
    (OUT / "data" / "tool" / "tts").mkdir(parents=True)
    for name in ["app.py", "tts_engines.py", "requirements-main.txt", "Dockerfile"]:
        shutil.copy2(SRC / name, OUT / name)
    shutil.copy2(ROOT / "assets" / "content" / "catalog.json", OUT / "data" / "assets" / "content" / "catalog.json")
    shutil.copy2(ROOT / "tool" / "tts" / "engines.json", OUT / "data" / "tool" / "tts" / "engines.json")
    (OUT / "README.md").write_text(README, encoding="utf-8")
    print(f"ready: {OUT}")


if __name__ == "__main__":
    main()
