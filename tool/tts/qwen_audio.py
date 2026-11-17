"""Qwen3-TTS 목소리 복제로 대화 음성을 만든다(engines.json에서 engine이 "qwen"인 언어, 지금은 중국어).

- 기준 목소리: tool/tts/voices/<언어>/<목소리>.wav (qwen_voices.py design으로 만든 것)
- 출력: assets/audio/<언어>/<캐릭터>/<시나리오>__<노드>.mp3, 모범 답변은 <언어>/guide/...
- 목록: manifest_util로 파일 하나 만들 때마다 assets/audio/manifest.json에 합친다.

캐릭터 대사를 먼저 모두 만들고, 모범 답변은 그 뒤에 만든다. 문장이 바뀌지 않은 파일은 다시 만들지 않는다.
로컬 CPU 전용, 외부 API 호출 없음.
사용법: .tts/venv-qwen/Scripts/python.exe tool/tts/qwen_audio.py [언어 ...]
"""

import hashlib
import json
import os
import sys
import time
from pathlib import Path

import soundfile as sf
import torch

import manifest_util

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "assets" / "content"
AUDIO = ROOT / "assets" / "audio"
VOICES = ROOT / "tool" / "tts" / "voices"
ENGINE = "qwen3-tts-0.6b-base"
# 길이 상한 계산용: 코덱은 초당 12토큰, 말하기 속도는 글자 수로 어림잡는다.
# (모델이 끝을 못 내고 계속 소리를 만드는 경우가 있어 상한을 두고, 넘치면 다시 만든다)
TOKENS_PER_SEC = 12
CHARS_PER_SEC = {"zh": 4, "en_gb": 14}


def text_hash(text: str, voice: str, ref: str) -> str:
    # 기준 목소리가 기본(<캐릭터>_0)이 아니면 해시에 넣어, 기준을 바꾸면 다시 만들게 한다.
    key = voice if ref == f"{voice}_0" else f"{voice}@{ref}"
    return hashlib.sha1(f"{ENGINE}|{key}|{text}".encode("utf-8")).hexdigest()[:12]


def main() -> None:
    from qwen_tts import Qwen3TTSModel

    langs = sys.argv[1:] or manifest_util.langs_for("qwen")
    catalog = json.loads((CONTENT / "catalog.json").read_text(encoding="utf-8"))
    files = manifest_util.read()

    npc_jobs, guide_jobs = [], []
    for lang in langs:
        spec = manifest_util.ENGINES[lang]
        language = next(l for l in catalog["languages"] if l["code"] == lang)
        for sid in language["content"]:
            scenario = json.loads((CONTENT / lang / f"{sid}.json").read_text(encoding="utf-8"))
            for node in scenario["nodes"]:
                for ch in spec["voices"]:
                    if ch != "guide":
                        npc_jobs.append((f"{lang}/{ch}/{sid}__{node['id']}.mp3", lang, node["text"], ch))
                for reply in node["replies"]:
                    guide_jobs.append((f"{lang}/guide/{sid}__{reply['id']}.mp3", lang, reply["text"], "guide"))
    # 초급 기초 단어(단어·예문)
    word_jobs = [(rel, lang, text, manifest_util.WORD_VOICE) for lang in langs for rel, text in manifest_util.word_jobs(lang)]
    jobs = [
        j
        for j in npc_jobs + guide_jobs + word_jobs
        if not (
            (prev := files.get(j[0]))
            and prev.get("hash") == text_hash(j[2], j[3], manifest_util.ENGINES[j[1]]["voices"][j[3]])
            and (AUDIO / j[0]).exists()
            and (AUDIO / j[0]).stat().st_size > 0
        )
    ]
    # QWEN_SHARD=i/n: 여러 프로세스가 작업을 나눠 만든다(목록 갱신은 manifest_util이 잠금으로 보호).
    shard = os.environ.get("QWEN_SHARD")
    if shard:
        i, n = (int(x) for x in shard.split("/"))
        jobs = jobs[i::n]
    print(f"to make: {len(jobs)} (skip {len(npc_jobs) + len(guide_jobs) + len(word_jobs) - len(jobs)})", flush=True)
    if not jobs:
        return

    torch.set_num_threads(int(os.environ.get("QWEN_THREADS", "12")))
    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(
        manifest_util.ENGINES[langs[0]]["model"], device_map="cpu", dtype=torch.float32, attn_implementation="sdpa"
    )
    print(f"model loaded: {time.perf_counter() - t0:.0f}s", flush=True)

    prompts: dict[tuple[str, str], object] = {}

    def prompt(lang: str, ch: str):
        ref = manifest_util.ENGINES[lang]["voices"][ch]
        if (lang, ref) not in prompts:
            meta = json.loads((VOICES / lang / "voices.json").read_text(encoding="utf-8"))
            prompts[(lang, ref)] = model.create_voice_clone_prompt(
                ref_audio=str(VOICES / lang / f"{ref}.wav"), ref_text=meta["ref_text"]
            )
        return prompts[(lang, ref)]

    failed = []
    started = time.perf_counter()
    for i, (rel, lang, text, ch) in enumerate(jobs, 1):
        spec = manifest_util.ENGINES[lang]
        expected = len(text) / CHARS_PER_SEC[lang]
        limit = expected * 2 + 2.5
        ok = False
        for attempt in range(1, 5):
            wavs, sr = model.generate_voice_clone(
                text=text,
                language=spec["language"],
                voice_clone_prompt=prompt(lang, ch),
                max_new_tokens=int(TOKENS_PER_SEC * limit),
            )
            seconds = len(wavs[0]) / sr
            if expected * 0.3 <= seconds < limit * 0.97:
                ok = True
                break
            print(f"  retry {attempt}: {rel} {seconds:.1f}s (expected {expected:.1f}s)", flush=True)
        if not ok:
            failed.append(rel)
            print(f"  FAILED: {rel}", flush=True)
            continue
        path = AUDIO / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(str(path), wavs[0], sr, format="MP3", compression_level=0.75)
        manifest_util.update(
            {
                rel: {
                    "hash": text_hash(text, ch, spec["voices"][ch]),
                    "sec": round(seconds, 2),
                    "voice": f"qwen:{lang}/{spec['voices'][ch]}",
                    "engine": ENGINE,
                }
            }
        )
        print(f"{i}/{len(jobs)} {rel} ({time.perf_counter() - started:.0f}s)", flush=True)

    print(f"done: made={len(jobs) - len(failed)}, failed={failed}, {time.perf_counter() - started:.0f}s", flush=True)


if __name__ == "__main__":
    main()
