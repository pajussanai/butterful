"""앱에 넣을 대화 음성을 미리 만든다(Supertonic 3, 로컬 CPU, 외부 API 호출 없음).

- 캐릭터 대사: assets/audio/<언어>/<캐릭터>/<시나리오>__<노드>.mp3
- 학습자 모범 답변: assets/audio/<언어>/guide/<시나리오>__<답변 ID>.mp3
- 목록: assets/audio/manifest.json (파일, 문장 해시, 길이). manifest_util로 자기 언어 항목만 갱신한다.
- 맡는 언어: tool/tts/engines.json에서 engine이 "supertonic"인 언어(en, ja, ko, fr, es)

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

import manifest_util

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "assets" / "content"
AUDIO = ROOT / "assets" / "audio"
ENGINE = "supertonic-3"


def text_hash(text: str, voice: str, speed: float) -> str:
    return hashlib.sha1(f"{ENGINE}|{voice}|{speed}|{text}".encode("utf-8")).hexdigest()[:12]


def main() -> None:
    catalog = json.loads((CONTENT / "catalog.json").read_text(encoding="utf-8"))
    # engines.json에서 Supertonic이 맡은 언어만 다룬다(다른 엔진의 항목은 건드리지 않음).
    langs = [l for l in (sys.argv[1:] or manifest_util.langs_for("supertonic"))]
    for lang in langs:
        if manifest_util.ENGINES[lang]["engine"] != "supertonic":
            raise SystemExit(f"{lang} is not a supertonic language (engines.json)")
    old_files = manifest_util.read()

    tts = TTS(auto_download=True)
    styles: dict[str, object] = {}

    def style(voice: str):
        if voice not in styles:
            styles[voice] = tts.get_voice_style(voice_name=voice)
        return styles[voice]

    jobs = []
    for language in catalog["languages"]:
        lang = language["code"]
        if lang not in langs:
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
        # 초급 기초 단어(단어·예문)는 정해 둔 캐릭터 목소리로 읽는다.
        word_voice = next(c for c in catalog["characters"] if c["id"] == manifest_util.WORD_VOICE)
        for rel, text in manifest_util.word_jobs(lang):
            jobs.append((rel, lang, text, word_voice["voice"], word_voice["speed"]))

    wanted = {j[0] for j in jobs}
    stale = {k for k in old_files if k.split("/")[0] in langs and k not in wanted}
    made = skipped = 0
    pending: dict[str, dict] = {}
    started = time.perf_counter()
    for i, (rel, lang, text, voice, speed) in enumerate(jobs, 1):
        h = text_hash(text, voice, speed)
        path = AUDIO / rel
        prev = old_files.get(rel)
        if prev and prev.get("hash") == h and path.exists() and path.stat().st_size > 0:
            skipped += 1
            continue
        wav, dur = tts.synthesize(text, voice_style=style(voice), lang=manifest_util.ENGINES[lang]["lang"], total_steps=10, speed=speed)
        path.parent.mkdir(parents=True, exist_ok=True)
        # 모노 MP3(VBR). 웹·모바일 브라우저 모두 재생 가능
        sf.write(str(path), wav.squeeze(), tts.sample_rate, format="MP3", compression_level=0.75)
        seconds = round(float(wav.squeeze().shape[-1]) / tts.sample_rate, 2)
        pending[rel] = {"hash": h, "sec": seconds, "voice": voice}
        made += 1
        if made % 20 == 0:
            manifest_util.update(pending)
            pending = {}
            print(f"{i}/{len(jobs)} made={made} ({time.perf_counter() - started:.0f}s)", flush=True)

    manifest_util.update(pending, remove=stale)
    print(f"done: made={made}, skipped={skipped}, removed={len(stale)}, {time.perf_counter() - started:.0f}s")


if __name__ == "__main__":
    main()
