"""중급 AI 회화의 캐릭터 음성을 기존 엔진으로 새로 만든다(초급 MP3 생성 스크립트와 같은 목소리 설정).

- 목소리 설정은 tool/tts/engines.json(언어별 엔진)과 assets/content/catalog.json(캐릭터 목소리·속도)을 그대로 읽는다.
  이 파일은 설정을 읽기만 하고 고치지 않는다.
- 엔진: Supertonic 3(en, ja, ko, fr), Kokoro-82M(en_gb, es), Qwen3-TTS 0.6B 목소리 복제(zh)
- 엔진마다 필요한 패키지가 달라(Kokoro와 Qwen은 transformers 버전이 다름) 쓰는 엔진만 불러온다.
"""

from __future__ import annotations

import io
import json
import os
import threading
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent


def _find(rel: str) -> Path:
    """배포(서버 폴더에 복사본)와 저장소(원본) 어느 쪽에서 실행해도 설정 파일을 찾는다."""
    for base in (HERE / "data", HERE.parents[1]):
        p = base / rel
        if p.exists():
            return p
    raise FileNotFoundError(rel)


ENGINES: dict = json.loads(_find("tool/tts/engines.json").read_text(encoding="utf-8"))
CATALOG: dict = json.loads(_find("assets/content/catalog.json").read_text(encoding="utf-8"))
CHARACTERS: dict = {c["id"]: c for c in CATALOG["characters"]}
THREADS = int(os.environ.get("TTS_THREADS", "2"))

# 한 응답의 최대 글자 수(Edge Function도 같은 상한으로 자른다)
MAX_CHARS = 400


class TtsError(Exception):
    pass


def engine_of(lang: str) -> str:
    spec = ENGINES.get(lang)
    if not isinstance(spec, dict):
        raise TtsError(f"unsupported language: {lang}")
    return spec["engine"]


class SupertonicEngine:
    """Supertonic 3. 캐릭터 목소리는 catalog.json의 voice(F1, M1 …)와 speed, 단계 수는 초급과 같은 10."""

    name = "supertonic"

    def __init__(self) -> None:
        from supertonic import TTS

        self.tts = TTS(auto_download=True, intra_op_num_threads=THREADS, inter_op_num_threads=1)
        self.sample_rate = self.tts.sample_rate
        self._styles: dict = {}

    def synthesize(self, lang: str, character: str, text: str) -> np.ndarray:
        ch = CHARACTERS[character]
        voice = ch["voice"]
        if voice not in self._styles:
            self._styles[voice] = self.tts.get_voice_style(voice_name=voice)
        wav, _ = self.tts.synthesize(
            text, voice_style=self._styles[voice], lang=ENGINES[lang]["lang"], total_steps=10, speed=ch["speed"]
        )
        return np.asarray(wav, dtype=np.float32).squeeze()


class KokoroEngine:
    """Kokoro-82M. 목소리는 engines.json의 voices(혼합 목소리 포함), 속도는 catalog.json."""

    name = "kokoro"
    sample_rate = 24000

    def __init__(self) -> None:
        import torch

        torch.set_num_threads(THREADS)
        self._pipes: dict = {}
        self._voices: dict = {}

    def _pipe(self, lang: str):
        from kokoro import KPipeline

        spec = ENGINES[lang]
        if lang not in self._pipes:
            self._pipes[lang] = KPipeline(lang_code=spec["lang_code"], repo_id=spec["model"])
        return self._pipes[lang]

    def _voice(self, lang: str, character: str):
        spec = ENGINES[lang]["voices"][character]
        key = (lang, spec)
        if key not in self._voices:
            pipe = self._pipe(lang)
            if "+" not in spec and ":" not in spec:
                self._voices[key] = spec
            else:
                # tool/tts/kokoro_audio.py의 voice_tensor와 같은 방식(비율을 둔 혼합)
                names, weights = [], []
                for part in spec.split("+"):
                    n, _, w = part.partition(":")
                    names.append(n)
                    weights.append(float(w or 1))
                total = sum(weights)
                self._voices[key] = sum(pipe.load_single_voice(n) * (w / total) for n, w in zip(names, weights))
        return self._voices[key]

    def synthesize(self, lang: str, character: str, text: str) -> np.ndarray:
        pipe = self._pipe(lang)
        chunks = [
            a.numpy()
            for _, _, a in pipe(text, voice=self._voice(lang, character), speed=CHARACTERS[character]["speed"])
            if a is not None
        ]
        if not chunks:
            raise TtsError("kokoro produced no audio")
        return np.concatenate(chunks).astype(np.float32)


class QwenEngine:
    """Qwen3-TTS 0.6B Base 목소리 복제. 기준 음성은 tool/tts/voices/<언어>/<목소리>.wav(초급과 같음)."""

    name = "qwen"
    TOKENS_PER_SEC = 12
    CHARS_PER_SEC = {"zh": 4}

    def __init__(self) -> None:
        import torch
        from qwen_tts import Qwen3TTSModel

        torch.set_num_threads(THREADS)
        model_id = next(s["model"] for s in ENGINES.values() if isinstance(s, dict) and s.get("engine") == "qwen")
        self.model = Qwen3TTSModel.from_pretrained(
            model_id, device_map="cpu", dtype=torch.float32, attn_implementation="sdpa"
        )
        self._prompts: dict = {}
        self.sample_rate = None

    def _prompt(self, lang: str, character: str):
        ref = ENGINES[lang]["voices"][character]
        if (lang, ref) not in self._prompts:
            vdir = _find(f"tool/tts/voices/{lang}")
            meta = json.loads((vdir / "voices.json").read_text(encoding="utf-8"))
            self._prompts[(lang, ref)] = self.model.create_voice_clone_prompt(
                ref_audio=str(vdir / f"{ref}.wav"), ref_text=meta["ref_text"]
            )
        return self._prompts[(lang, ref)]

    def synthesize(self, lang: str, character: str, text: str) -> np.ndarray:
        # Qwen은 가끔 끝을 내지 못하고 소리를 계속 만든다(VOICES.md). 길이 상한을 두고 넘치면 한 번 더 만든다.
        expected = len(text) / self.CHARS_PER_SEC.get(lang, 12)
        limit = expected * 2 + 2.5
        for _ in range(2):
            wavs, sr = self.model.generate_voice_clone(
                text=text,
                language=ENGINES[lang]["language"],
                voice_clone_prompt=self._prompt(lang, character),
                max_new_tokens=int(self.TOKENS_PER_SEC * limit),
            )
            self.sample_rate = sr
            seconds = len(wavs[0]) / sr
            if expected * 0.3 <= seconds < limit * 0.97:
                return np.asarray(wavs[0], dtype=np.float32)
        raise TtsError("qwen output length out of range")


_ENGINE_CLASSES = {"supertonic": SupertonicEngine, "kokoro": KokoroEngine, "qwen": QwenEngine}


class Router:
    """언어 → 엔진을 고르는 공통 진입점. 엔진은 처음 쓸 때 한 번만 불러온다."""

    def __init__(self, enabled: list[str] | None = None) -> None:
        self.enabled = set(enabled or _ENGINE_CLASSES)
        self._engines: dict = {}
        self._lock = threading.Lock()
        # CPU가 적은 무료 서버에서 동시에 여러 문장을 만들면 모두 느려지므로 한 번에 하나씩 만든다.
        self._gen_lock = threading.Lock()

    def languages(self) -> list[str]:
        return [k for k, v in ENGINES.items() if isinstance(v, dict) and v["engine"] in self.enabled]

    def engine(self, name: str):
        with self._lock:
            if name not in self._engines:
                self._engines[name] = _ENGINE_CLASSES[name]()
            return self._engines[name]

    def synthesize(self, lang: str, character: str, text: str) -> tuple[np.ndarray, int]:
        name = engine_of(lang)
        if name not in self.enabled:
            raise TtsError(f"engine not enabled here: {name}")
        if character not in CHARACTERS:
            raise TtsError(f"unknown character: {character}")
        text = " ".join(text.split())[:MAX_CHARS]
        if not text:
            raise TtsError("empty text")
        eng = self.engine(name)
        with self._gen_lock:
            wav = eng.synthesize(lang, character, text)
        return wav, int(eng.sample_rate)


def to_mp3(wav: np.ndarray, sr: int) -> bytes:
    buf = io.BytesIO()
    sf.write(buf, wav, sr, format="MP3", compression_level=0.75)
    return buf.getvalue()
