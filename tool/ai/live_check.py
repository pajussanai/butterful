"""배포된 중급 AI 회화 Edge Function을 실제로 불러 언어별로 확인한다(표준 라이브러리만 사용).

Gemini 무료 한도를 쓰므로 필요할 때만 실행한다(언어당 요청 3번: 맞는 발화·틀린 발화 음성, 구어체 입력).
입력 음성: voice_samples/ai_input/<언어>_ok.wav, <언어>_err.wav (로컬 TTS로 만든 테스트 발화, .gitignore)
사용법: python tool/ai/live_check.py https://<ref>.supabase.co/functions/v1 [언어 ...]
결과: voice_samples/ai_input/live_<언어>.json
"""

import base64
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "voice_samples" / "ai_input"
ORIGIN = "https://pajussanai.github.io"

# 맞는 구어체 문장: 고치면 안 된다(오교정 확인)
CASUAL = {
    "en": "Yeah, sounds good! Wanna grab lunch later?",
    "en_gb": "Cheers, that sounds brilliant. Fancy a cuppa later?",
    "ja": "うん、いいね！じゃあ、また後でね。",
    "ko": "응, 좋아! 그럼 이따 봐.",
    "zh": "好啊，没问题！那我们晚点见吧。",
    "fr": "Ouais, carrément ! On se voit plus tard ?",
    "es": "¡Vale, genial! ¿Quedamos luego?",
}


def call(base: str, body: dict) -> tuple[int, dict, float]:
    req = urllib.request.Request(
        f"{base}/intermediate-turn",
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json", "Origin": ORIGIN},
    )
    t = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return r.status, json.loads(r.read()), time.perf_counter() - t
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}"), time.perf_counter() - t


def main() -> None:
    base = sys.argv[1].rstrip("/")
    langs = sys.argv[2:] or list(CASUAL)
    texts = json.loads((INPUT / "texts.json").read_text(encoding="utf-8"))
    for lang in langs:
        rows = []
        history = [{"role": "character", "text": "What did you do recently?"}]
        cases = [("ok-audio", texts[lang][0], INPUT / f"{lang}_ok.wav"), ("err-audio", texts[lang][1], INPUT / f"{lang}_err.wav"), ("casual-text", CASUAL[lang], None)]
        for name, spoken, wav in cases:
            body = {"lang": lang, "character": "mia", "topic": "daily_life", "history": history}
            if wav:
                body |= {"audio_base64": base64.b64encode(wav.read_bytes()).decode(), "audio_mime": "audio/wav"}
            else:
                body["text"] = spoken
            status, res, sec = call(base, body)
            r = res.get("result", {})
            row = {"case": name, "said": spoken, "status": status, "sec": round(sec, 1), **({"error": res.get("error")} if status != 200 else {
                "recognized": r.get("recognized_text"),
                "correction_needed": r.get("correction_needed"),
                "corrected": r.get("corrected_text"),
                "natural": r.get("natural_expression"),
                "why": r.get("correction_explanation"),
                "reply": f"{r.get('character_response')} {r.get('next_question')}",
                "translation": r.get("response_translation"),
            })}
            rows.append(row)
            print(json.dumps(row, ensure_ascii=False), flush=True)
            time.sleep(9)  # 무료 등급 분당 한도를 넘지 않도록 천천히
        (INPUT / f"live_{lang}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
