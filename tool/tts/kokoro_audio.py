"""Kokoro-82M으로 대화 음성을 만든다(engines.json에서 engine이 "kokoro"인 언어, 지금은 영국 영어).

Kokoro는 영국 영어(lang_code "b")에 영국식 발음 사전·G2P(misaki en-GB)와 영국인 화자 목소리를 쓴다.
- 출력: assets/audio/<언어>/<캐릭터>/<시나리오>__<노드>.mp3, 모범 답변은 <언어>/guide/...
- 목록: manifest_util로 자기 언어 항목만 갱신한다. 문장·목소리·속도가 그대로면 다시 만들지 않는다.

로컬 CPU 전용, 외부 API 호출 없음.
사용법: .tts/venv-kokoro/Scripts/python.exe tool/tts/kokoro_audio.py [언어 ...]
"""

import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from kokoro import KPipeline

import manifest_util

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "assets" / "content"
AUDIO = ROOT / "assets" / "audio"
ENGINE = "kokoro-82m"
SR = 24000


def voice_tensor(pipe: KPipeline, spec: str):
    """목소리 지정: "ef_dora" 하나, 또는 "if_sara:0.4+ef_dora:0.6"처럼 비율을 둔 혼합."""
    if "+" not in spec and ":" not in spec:
        return spec
    names, weights = [], []
    for part in spec.split("+"):
        name, _, weight = part.partition(":")
        names.append(name)
        weights.append(float(weight or 1))
    total = sum(weights)
    return sum(pipe.load_single_voice(n) * (w / total) for n, w in zip(names, weights))


def text_hash(text: str, voice: str, speed: float) -> str:
    return hashlib.sha1(f"{ENGINE}|{voice}|{speed}|{text}".encode("utf-8")).hexdigest()[:12]


def main() -> None:
    langs = sys.argv[1:] or manifest_util.langs_for("kokoro")
    catalog = json.loads((CONTENT / "catalog.json").read_text(encoding="utf-8"))
    speeds = {c["id"]: c["speed"] for c in catalog["characters"]} | {"guide": catalog["guide"]["speed"]}
    old_files = manifest_util.read()

    for lang in langs:
        spec = manifest_util.ENGINES[lang]
        if spec["engine"] != "kokoro":
            raise SystemExit(f"{lang} is not a kokoro language (engines.json)")
        language = next(l for l in catalog["languages"] if l["code"] == lang)
        jobs = []
        for sid in language["content"]:
            scenario = json.loads((CONTENT / lang / f"{sid}.json").read_text(encoding="utf-8"))
            for node in scenario["nodes"]:
                for ch in spec["voices"]:
                    if ch != "guide":
                        jobs.append((f"{lang}/{ch}/{sid}__{node['id']}.mp3", node["text"], ch))
                for reply in node["replies"]:
                    jobs.append((f"{lang}/guide/{sid}__{reply['id']}.mp3", reply["text"], "guide"))

        wanted = {j[0] for j in jobs}
        stale = {k for k in old_files if k.split("/")[0] == lang and k not in wanted}
        pipe = KPipeline(lang_code=spec["lang_code"], repo_id=spec["model"])
        pending, made, skipped = {}, 0, 0
        started = time.perf_counter()
        for i, (rel, text, ch) in enumerate(jobs, 1):
            voice, speed = spec["voices"][ch], speeds[ch]
            h = text_hash(text, voice, speed)
            path = AUDIO / rel
            prev = old_files.get(rel)
            if prev and prev.get("hash") == h and path.exists() and path.stat().st_size > 0:
                skipped += 1
                continue
            chunks = [a.numpy() for _, _, a in pipe(text, voice=voice_tensor(pipe, voice), speed=speed) if a is not None]
            wav = np.concatenate(chunks)
            path.parent.mkdir(parents=True, exist_ok=True)
            sf.write(str(path), wav, SR, format="MP3", compression_level=0.75)
            pending[rel] = {"hash": h, "sec": round(len(wav) / SR, 2), "voice": f"kokoro:{voice}", "engine": ENGINE}
            made += 1
            if made % 25 == 0:
                manifest_util.update(pending)
                pending = {}
                print(f"{lang} {i}/{len(jobs)} made={made} ({time.perf_counter() - started:.0f}s)", flush=True)
        manifest_util.update(pending, remove=stale)
        print(f"{lang} done: made={made}, skipped={skipped}, removed={len(stale)}, {time.perf_counter() - started:.0f}s")


if __name__ == "__main__":
    main()
