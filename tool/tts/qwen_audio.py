"""Supertonic이 지원하지 않는 언어(영국 영어, 중국어)의 대화 음성을 Qwen3-TTS 목소리 복제로 만든다.

- 기준 목소리: tool/tts/voices/<언어>/<목소리>_0.wav (qwen_voices.py design으로 만든 것)
- 출력: assets/audio/<언어>/<캐릭터>/<시나리오>__<노드>.mp3, 모범 답변은 <언어>/guide/...
- 목록: assets/audio/manifest.json에 파일마다 engine을 적어 합친다(파일 하나 만들 때마다 저장).

캐릭터 대사를 먼저 모두 만들고, 모범 답변은 그 뒤에 만든다.
로컬 CPU 전용, 외부 API 호출 없음.
사용법: .tts/venv-qwen/Scripts/python.exe tool/tts/qwen_audio.py
"""

import hashlib
import json
import time
from pathlib import Path

import soundfile as sf
import torch

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "assets" / "content"
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"
VOICES = ROOT / "tool" / "tts" / "voices"
ENGINE = "qwen3-tts-0.6b-base"
MODEL = "Qwen/Qwen3-TTS-12Hz-0.6B-Base"

# 언어마다 캐릭터 한 명(이 목록이 앱 카탈로그의 characters와 맞아야 한다)
LANGS = {
    "en_gb": {"language": "English", "character": "mia"},
    "zh": {"language": "Chinese", "character": "leo"},
}
SCENARIOS = ["restaurant", "hotel"]
# 길이 상한 계산용: 코덱은 초당 12토큰, 말하기 속도는 글자 수로 어림잡는다.
TOKENS_PER_SEC = 12
CHARS_PER_SEC = {"en_gb": 14, "zh": 4}


def text_hash(text: str, voice: str) -> str:
    return hashlib.sha1(f"{ENGINE}|{voice}|{text}".encode("utf-8")).hexdigest()[:12]


def main() -> None:
    from qwen_tts import Qwen3TTSModel

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    files = manifest["files"]

    npc_jobs, guide_jobs = [], []
    for lang, spec in LANGS.items():
        for sid in SCENARIOS:
            scenario = json.loads((CONTENT / lang / f"{sid}.json").read_text(encoding="utf-8"))
            for node in scenario["nodes"]:
                ch = spec["character"]
                npc_jobs.append((f"{lang}/{ch}/{sid}__{node['id']}.mp3", lang, node["text"], ch))
                for reply in node["replies"]:
                    guide_jobs.append((f"{lang}/guide/{sid}__{reply['id']}.mp3", lang, reply["text"], "guide"))
    jobs = npc_jobs + guide_jobs

    torch.set_num_threads(12)
    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(MODEL, device_map="cpu", dtype=torch.float32, attn_implementation="sdpa")
    print(f"model loaded: {time.perf_counter() - t0:.0f}s", flush=True)

    prompts: dict[tuple[str, str], object] = {}

    def prompt(lang: str, voice: str):
        if (lang, voice) not in prompts:
            meta = json.loads((VOICES / lang / "voices.json").read_text(encoding="utf-8"))
            prompts[(lang, voice)] = model.create_voice_clone_prompt(
                ref_audio=str(VOICES / lang / f"{voice}_0.wav"), ref_text=meta["ref_text"]
            )
        return prompts[(lang, voice)]

    made = skipped = 0
    started = time.perf_counter()
    for i, (rel, lang, text, voice) in enumerate(jobs, 1):
        h = text_hash(text, voice)
        path = AUDIO / rel
        prev = files.get(rel)
        if prev and prev.get("hash") == h and path.exists() and path.stat().st_size > 0:
            skipped += 1
            continue
        # 모델이 끝을 못 내고 계속 소리를 만드는 경우가 있어, 문장 길이로 예상 길이를 잡고 넘치면 다시 만든다.
        expected = len(text) / CHARS_PER_SEC[lang]
        limit = expected * 2 + 2
        for attempt in range(1, 5):
            wavs, sr = model.generate_voice_clone(
                text=text,
                language=LANGS[lang]["language"],
                voice_clone_prompt=prompt(lang, voice),
                max_new_tokens=int(TOKENS_PER_SEC * limit),
            )
            seconds = len(wavs[0]) / sr
            if expected * 0.3 <= seconds < limit * 0.97:
                break
            print(f"  retry {attempt}: {rel} {seconds:.1f}s (expected {expected:.1f}s)", flush=True)
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(str(path), wavs[0], sr, format="MP3", compression_level=0.75)
        files[rel] = {"hash": h, "sec": round(seconds, 2), "voice": f"qwen:{lang}/{voice}_0", "engine": ENGINE}
        manifest["files"] = dict(sorted(files.items()))
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
        made += 1
        print(f"{i}/{len(jobs)} {rel} ({time.perf_counter() - started:.0f}s)", flush=True)

    print(f"done: made={made}, skipped={skipped}, {time.perf_counter() - started:.0f}s", flush=True)


if __name__ == "__main__":
    main()
