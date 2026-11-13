"""Qwen3-TTS 음성 비교 샘플을 만든다(로컬 CPU, 외부 API 호출 없음).

사용법: .tts/venv-qwen/Scripts/python.exe tool/tts/qwen_samples.py <출력 폴더> [모델 ID]
"""

import json
import sys
import time
from pathlib import Path

import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

SAMPLES = {
    "ko": ("Korean", "어서 오세요! 몇 분이세요? 창가 자리랑 바 자리 중에 어디가 좋으세요?"),
    "en": ("English", "Hi, welcome in! How many people are with you today? Would you like a table by the window?"),
    "ja": ("Japanese", "いらっしゃいませ。何名様ですか？窓際のテーブルとカウンター席、どちらがよろしいですか？"),
}
# 언어마다 그 언어가 모국어인 기본 화자 + 다른 언어 화자 하나(캐릭터 일관성 확인용)
SPEAKERS = {"ko": ["Sohee", "Ryan"], "en": ["Ryan", "Aiden", "Sohee"], "ja": ["Ono_Anna", "Ryan"]}


def main() -> None:
    out = Path(sys.argv[1])
    model_id = sys.argv[2] if len(sys.argv) > 2 else "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
    out.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(12)
    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(model_id, device_map="cpu", dtype=torch.float32, attn_implementation="sdpa")
    report = {"engine": model_id, "load_sec": round(time.perf_counter() - t0, 2), "items": []}
    print("loaded", report["load_sec"], flush=True)
    for lang, (language, text) in SAMPLES.items():
        for speaker in SPEAKERS[lang]:
            t = time.perf_counter()
            wavs, sr = model.generate_custom_voice(text=text, language=language, speaker=speaker)
            gen = time.perf_counter() - t
            path = out / f"qwen_{lang}_{speaker}.wav"
            sf.write(str(path), wavs[0], sr)
            seconds = len(wavs[0]) / sr
            report["items"].append(
                {"file": path.name, "lang": lang, "voice": speaker, "audio_sec": round(seconds, 2), "gen_sec": round(gen, 2)}
            )
            print(f"{path.name}: audio {seconds:.2f}s, gen {gen:.2f}s", flush=True)
    (out / "qwen_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
