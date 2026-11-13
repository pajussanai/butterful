"""Supertonic 3 음성 비교 샘플을 만든다(로컬 CPU 전용, 외부 API 호출 없음).

사용법: .tts/venv-st/Scripts/python.exe tool/tts/supertonic_samples.py <출력 폴더>
"""

import json
import sys
import time
from pathlib import Path

import numpy as np
from supertonic import TTS

SAMPLES = {
    "ko": "어서 오세요! 몇 분이세요? 창가 자리랑 바 자리 중에 어디가 좋으세요?",
    "en": "Hi, welcome in! How many people are with you today? Would you like a table by the window?",
    "ja": "いらっしゃいませ。何名様ですか？窓際のテーブルとカウンター席、どちらがよろしいですか？",
}
VOICES = ["F1", "F2", "F3", "F4", "F5", "M1", "M2", "M3", "M4", "M5"]


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    t0 = time.perf_counter()
    tts = TTS(auto_download=True)
    report = {"engine": "supertonic-3", "load_sec": round(time.perf_counter() - t0, 2), "items": []}
    for lang, text in SAMPLES.items():
        for voice in VOICES:
            style = tts.get_voice_style(voice_name=voice)
            t = time.perf_counter()
            wav, dur = tts.synthesize(text, voice_style=style, lang=lang, total_steps=8, speed=1.0)
            gen = time.perf_counter() - t
            path = out / f"supertonic_{lang}_{voice}.wav"
            tts.save_audio(wav, str(path))
            seconds = float(np.asarray(dur).reshape(-1)[0])
            report["items"].append(
                {"file": path.name, "lang": lang, "voice": voice, "audio_sec": round(seconds, 2), "gen_sec": round(gen, 2)}
            )
            print(f"{path.name}: audio {seconds:.2f}s, gen {gen:.2f}s", flush=True)
    (out / "supertonic_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
