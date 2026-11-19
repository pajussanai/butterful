"""BUTTERFUL TTS 서버: 중급 AI 회화의 캐릭터 응답을 기존 엔진 목소리로 읽는다.

POST /tts  {"language": "en", "character_id": "mia", "text": "..."}  → audio/mpeg
GET  /health → 이 서버가 맡은 엔진·언어, 엔진 준비 여부

- 이 서버는 Supabase Edge Function(tts)만 부른다. 헤더 X-Tts-Key가 TTS_SHARED_SECRET과 같아야 한다.
- TTS_ENGINES: 이 서버에서 켤 엔진(쉼표 구분). 예: "supertonic,kokoro" 또는 "qwen"
- 받은 문장과 만든 음성은 저장하지 않는다(메모리에서 만들어 바로 돌려준다). 로그에도 문장을 남기지 않는다.
"""

from __future__ import annotations

import hmac
import logging
import os
import threading
import time

from fastapi import FastAPI, Header, HTTPException, Response
from pydantic import BaseModel, Field

import tts_engines

log = logging.getLogger("butterful.tts")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

ENABLED = [e.strip() for e in os.environ.get("TTS_ENGINES", "supertonic,kokoro").split(",") if e.strip()]
SECRET = os.environ.get("TTS_SHARED_SECRET", "")

router = tts_engines.Router(ENABLED)
app = FastAPI(title="BUTTERFUL TTS", docs_url=None, redoc_url=None, openapi_url=None)
_ready: dict[str, float] = {}


def _warm() -> None:
    """서버가 켜지면 엔진을 미리 불러오고 짧은 문장을 한 번 만들어, 첫 사용자가 기다리지 않게 한다."""
    # Kokoro는 언어마다 발음 변환기를 따로 불러오므로 맡은 언어를 모두 한 번씩 만든다.
    for lang in router.languages():
        t = time.perf_counter()
        try:
            router.synthesize(lang, "mia", "OK.")
            _ready[lang] = round(time.perf_counter() - t, 1)
            log.info("ready: %s (%.1fs)", lang, _ready[lang])
        except Exception:  # noqa: BLE001 - 준비 실패는 /health로 드러낸다
            log.exception("warm-up failed: %s", lang)


threading.Thread(target=_warm, daemon=True).start()


class TtsRequest(BaseModel):
    language: str = Field(max_length=10)
    character_id: str = Field(max_length=20)
    text: str = Field(min_length=1, max_length=tts_engines.MAX_CHARS)


@app.get("/health")
def health() -> dict:
    return {"ok": True, "engines": ENABLED, "languages": router.languages(), "ready": _ready}


@app.post("/tts")
def tts(req: TtsRequest, x_tts_key: str = Header(default="")) -> Response:
    if not SECRET or not hmac.compare_digest(x_tts_key, SECRET):
        raise HTTPException(status_code=401, detail="unauthorized")
    t = time.perf_counter()
    try:
        wav, sr = router.synthesize(req.language, req.character_id, req.text)
    except tts_engines.TtsError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    audio = tts_engines.to_mp3(wav, sr)
    took = time.perf_counter() - t
    # 문장 내용은 남기지 않고 길이·시간만 남긴다.
    log.info("tts %s/%s chars=%d audio=%.1fs took=%.1fs", req.language, req.character_id, len(req.text), len(wav) / sr, took)
    return Response(content=audio, media_type="audio/mpeg", headers={"X-Gen-Seconds": f"{took:.2f}"})
