"""Kokoro-82M으로 비교용 음성을 만든다(로컬 CPU, 외부 API 호출 없음).

사용법: .tts/venv-kokoro/Scripts/python.exe tool/tts/kokoro_samples.py <문장 JSON> <출력 폴더> <언어 코드> <목소리> [목소리 ...]
- 목소리: af_bella 처럼 하나, ef_dora,if_sara 처럼 쉼표로 이어 평균, 또는 if_sara:0.4+ef_dora:0.6 처럼 비율 혼합
- 언어 코드: b(영국 영어), a(미국 영어), f(프랑스어), e(스페인어)
- 문장 JSON: [{"key": ..., "text": ...}, ...]
"""

import json
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from kokoro import KPipeline

from kokoro_audio import voice_tensor

SR = 24000


def main() -> None:
    sentences = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out = Path(sys.argv[2])
    lang = sys.argv[3]
    voices = sys.argv[4:]
    out.mkdir(parents=True, exist_ok=True)
    pipe = KPipeline(lang_code=lang, repo_id="hexgrad/Kokoro-82M")
    for voice in voices:
        t = time.perf_counter()
        for s in sentences:
            chunks = [audio.numpy() for _, _, audio in pipe(s["text"], voice=voice_tensor(pipe, voice)) if audio is not None]
            sf.write(str(out / f"kokoro_{voice.replace(',', '+').replace(':', '')}__{s['key']}.wav"), np.concatenate(chunks), SR)
        print(f"{voice}: {len(sentences)} files, {time.perf_counter() - t:.1f}s", flush=True)


if __name__ == "__main__":
    main()
