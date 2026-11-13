"""앱에 넣을 대화 음성을 미리 만든다(Supertonic 3, 로컬 CPU, 외부 API 호출 없음).

- 캐릭터 대사: assets/audio/<언어>/<캐릭터>/<시나리오>__<노드>.mp3
- 학습자 모범 답변: assets/audio/<언어>/guide/<시나리오>__<답변 ID>.mp3
- 목록: assets/audio/manifest.json (파일, 문장 해시, 길이)

문장이 바뀌지 않은 파일은 다시 만들지 않는다.

사용법(프로젝트 루트에서):
  .tts/venv-st/Scripts/python.exe tool/tts/generate_audio.py [언어 ...]
"""

import hashlib
import json
import sys
import time
from pathlib import Path

import soundfile as sf
from supertonic import TTS

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "assets" / "content"
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"
ENGINE = "supertonic-3"
# Supertonic이 지원하지 않아 qwen_audio.py로 만드는 언어(여기서는 건드리지 않는다)
QWEN_LANGS = {"en_gb", "zh"}


def text_hash(text: str, voice: str, speed: float) -> str:
    return hashlib.sha1(f"{ENGINE}|{voice}|{speed}|{text}".encode("utf-8")).hexdigest()[:12]


def main() -> None:
    catalog = json.loads((CONTENT / "catalog.json").read_text(encoding="utf-8"))
    only = set(sys.argv[1:])
    old = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    old_files = old.get("files", {})
    files: dict[str, dict] = {}
    # 이번에 고르지 않은 언어는 기존 목록을 그대로 둔다.
    for key, value in old_files.items():
        lang = key.split("/")[0]
        if lang in QWEN_LANGS or (only and lang not in only):
            files[key] = value

    tts = TTS(auto_download=True)
    styles: dict[str, object] = {}

    def style(voice: str):
        if voice not in styles:
            styles[voice] = tts.get_voice_style(voice_name=voice)
        return styles[voice]

    jobs = []
    for language in catalog["languages"]:
        lang = language["code"]
        if lang in QWEN_LANGS or (only and lang not in only):
            continue
        for scenario_id in language["content"]:
            scenario = json.loads((CONTENT / lang / f"{scenario_id}.json").read_text(encoding="utf-8"))
            for node in scenario["nodes"]:
                for ch in catalog["characters"]:
                    rel = f"{lang}/{ch['id']}/{scenario_id}__{node['id']}.mp3"
                    jobs.append((rel, lang, node["text"], ch["voice"], ch["speed"]))
                for reply in node["replies"]:
                    guide = catalog["guide"]
                    rel = f"{lang}/guide/{scenario_id}__{reply['id']}.mp3"
                    jobs.append((rel, lang, reply["text"], guide["voice"], guide["speed"]))

    made = skipped = 0
    started = time.perf_counter()
    for i, (rel, lang, text, voice, speed) in enumerate(jobs, 1):
        h = text_hash(text, voice, speed)
        path = AUDIO / rel
        prev = old_files.get(rel)
        if prev and prev.get("hash") == h and path.exists() and path.stat().st_size > 0:
            files[rel] = prev
            skipped += 1
            continue
        wav, dur = tts.synthesize(text, voice_style=style(voice), lang=lang, total_steps=10, speed=speed)
        path.parent.mkdir(parents=True, exist_ok=True)
        # 모노 MP3(VBR). 웹·모바일 브라우저 모두 재생 가능
        sf.write(str(path), wav.squeeze(), tts.sample_rate, format="MP3", compression_level=0.75)
        seconds = round(float(wav.squeeze().shape[-1]) / tts.sample_rate, 2)
        files[rel] = {"hash": h, "sec": seconds, "voice": voice}
        made += 1
        if made % 20 == 0:
            print(f"{i}/{len(jobs)} made={made} ({time.perf_counter() - started:.0f}s)", flush=True)

    manifest = {
        "engine": ENGINE,
        "license": "Supertonic 3 model: BigScience OpenRAIL-M; Qwen3-TTS (en_gb, zh): Apache-2.0 (machine-generated voice)",
        "files": dict(sorted(files.items())),
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"done: made={made}, skipped={skipped}, total={len(files)}, {time.perf_counter() - started:.0f}s")


if __name__ == "__main__":
    main()
