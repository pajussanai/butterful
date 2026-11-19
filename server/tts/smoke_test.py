"""TTS 서버를 HTTP로 불러 언어·캐릭터마다 음성이 나오는지 확인한다(표준 라이브러리만 사용).

사용법: python server/tts/smoke_test.py http://127.0.0.1:7860 <공유 키> [언어 ...]
결과 음성은 voice_samples/ai_tts/http_<언어>_<캐릭터>.mp3(.gitignore)에 둔다.
"""

import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

TEXT = {
    "en": "Nice to meet you! What do you usually do on weekends?",
    "en_gb": "Lovely to meet you! Fancy a cuppa while we chat?",
    "ja": "はじめまして！週末はいつも何をしていますか？",
    "ko": "만나서 반가워요! 주말에는 보통 뭐 해요?",
    "zh": "很高兴认识你！你周末一般做什么？",
    "fr": "Ravie de te rencontrer ! Tu fais quoi le week-end, d'habitude ?",
    "es": "¡Encantada de conocerte! ¿Qué sueles hacer los fines de semana?",
}
CHARS = ["mia", "leo", "hana", "theo", "ellie"]


def main() -> None:
    base, key, langs = sys.argv[1].rstrip("/"), sys.argv[2], sys.argv[3:] or list(TEXT)
    out = Path(__file__).resolve().parents[2] / "voice_samples" / "ai_tts"
    out.mkdir(parents=True, exist_ok=True)
    failed = 0
    for lang in langs:
        for ch in CHARS:
            body = json.dumps({"language": lang, "character_id": ch, "text": TEXT[lang]}).encode("utf-8")
            req = urllib.request.Request(
                f"{base}/tts", data=body, method="POST",
                headers={"Content-Type": "application/json", "X-Tts-Key": key},
            )
            t = time.perf_counter()
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    data = r.read()
                    (out / f"http_{lang}_{ch}.mp3").write_bytes(data)
                    print(f"{lang:5} {ch:5} {r.status} {len(data):6}B {time.perf_counter() - t:5.2f}s server={r.headers.get('X-Gen-Seconds')}s")
            except urllib.error.HTTPError as e:
                failed += 1
                print(f"{lang:5} {ch:5} {e.code} {e.read()[:120]!r}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
