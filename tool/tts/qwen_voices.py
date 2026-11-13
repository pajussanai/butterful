"""Qwen3-TTS로 캐릭터 기준 목소리를 설계하고(VoiceDesign 1.7B), 그 목소리를 복제해(Base 0.6B) 시험 문장을 만든다.

- 기준 목소리: tool/tts/voices/<언어>/<캐릭터>.wav + voices.json(설명, 기준 문장)
- 시험 문장: voice_samples/clone_<언어>_<캐릭터>_<n>.wav

로컬 CPU 전용, 외부 API 호출 없음.
사용법: .tts/venv-qwen/Scripts/python.exe tool/tts/qwen_voices.py design|clone <언어> [후보 수]
"""

import json
import sys
import time
from pathlib import Path

import soundfile as sf
import torch

ROOT = Path(__file__).resolve().parents[2]
VOICES = ROOT / "tool" / "tts" / "voices"
SAMPLES = ROOT / "voice_samples"

LANGUAGE = {"zh": "Chinese", "en_gb": "English"}

# 캐릭터 성격(앱과 같음): mia 밝고 다정, hana 꼼꼼하고 정중, ellie 느긋하고 상냥, leo 차분, theo 유쾌
DESIGN = {
    "en_gb": {
        "ref": "Good afternoon, and welcome. I'll be looking after you today, so just let me know if you need anything at all.",
        "mia": "A young British woman in her twenties with a standard Southern English, Received Pronunciation accent. Bright, warm and friendly voice, clear articulation, natural conversational pace.",
        "hana": "A British woman in her thirties with a polished Received Pronunciation accent. Polite, composed and precise, slightly formal, very clear diction.",
        "ellie": "A British woman in her late twenties with a soft Southern English accent. Gentle, relaxed and kind, unhurried and warm.",
        "leo": "A British man in his thirties with a standard Southern English, Received Pronunciation accent. Calm, mellow and reassuring low voice, unhurried.",
        "theo": "A young British man in his twenties with a standard Southern English accent. Cheerful, upbeat and energetic, lively intonation.",
        "guide": "A British man in his thirties with a neutral Received Pronunciation accent. Clear, steady and friendly, like a language teacher.",
    },
    "zh": {
        "ref": "您好，欢迎光临。今天由我为您服务，有什么需要请随时告诉我。",
        "mia": "二十多岁的年轻女性，标准普通话，声音明亮亲切，吐字清晰，语速自然。",
        "hana": "三十岁左右的女性，标准普通话，礼貌稳重，咬字清楚，略带正式感。",
        "ellie": "二十多岁的女性，标准普通话，声音温柔放松，语速稍慢，非常亲切。",
        "leo": "三十多岁的男性，标准普通话，声音低沉温和，沉稳从容。",
        "theo": "二十多岁的年轻男性，标准普通话，开朗活泼，充满活力。",
        "guide": "三十多岁的男性，标准普通话，清晰平稳，像语言老师一样亲切。",
    },
}

TESTS = {
    "en_gb": [
        "Could I see your passport, please? Your room is on the eighth floor, and the lift is just round the corner.",
        "Would you like a table by the window? I'll bring the bill whenever you're ready.",
    ],
    "zh": [
        "请问您几位？靠窗的位子和吧台的座位，您喜欢哪一个？",
        "这是您的房卡，房间在八楼。电梯就在拐角右边。",
    ],
}


def design(lang: str, candidates: int) -> None:
    from qwen_tts import Qwen3TTSModel

    torch.set_num_threads(12)
    model = Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign", device_map="cpu", dtype=torch.float32, attn_implementation="sdpa"
    )
    spec = DESIGN[lang]
    out = VOICES / lang
    out.mkdir(parents=True, exist_ok=True)
    meta = {"model": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign", "ref_text": spec["ref"], "voices": {}}
    for char, instruct in spec.items():
        if char == "ref":
            continue
        for n in range(candidates):
            t = time.perf_counter()
            wavs, sr = model.generate_voice_design(text=spec["ref"], instruct=instruct, language=LANGUAGE[lang])
            path = out / f"{char}_{n}.wav"
            sf.write(str(path), wavs[0], sr)
            print(f"{lang}/{path.name}: {len(wavs[0]) / sr:.1f}s audio, {time.perf_counter() - t:.0f}s", flush=True)
        meta["voices"][char] = {"instruct": instruct}
    (out / "voices.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")


def clone(lang: str, candidates: int) -> None:
    from qwen_tts import Qwen3TTSModel

    torch.set_num_threads(12)
    model = Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-0.6B-Base", device_map="cpu", dtype=torch.float32, attn_implementation="sdpa"
    )
    meta = json.loads((VOICES / lang / "voices.json").read_text(encoding="utf-8"))
    SAMPLES.mkdir(exist_ok=True)
    for char in meta["voices"]:
        for n in range(candidates):
            ref = VOICES / lang / f"{char}_{n}.wav"
            prompt = model.create_voice_clone_prompt(ref_audio=str(ref), ref_text=meta["ref_text"])
            for i, text in enumerate(TESTS[lang]):
                t = time.perf_counter()
                wavs, sr = model.generate_voice_clone(text=text, language=LANGUAGE[lang], voice_clone_prompt=prompt)
                path = SAMPLES / f"clone_{lang}_{char}_{n}_{i}.wav"
                sf.write(str(path), wavs[0], sr)
                print(f"{path.name}: {len(wavs[0]) / sr:.1f}s audio, {time.perf_counter() - t:.0f}s", flush=True)


if __name__ == "__main__":
    action, lang = sys.argv[1], sys.argv[2]
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    (design if action == "design" else clone)(lang, count)
