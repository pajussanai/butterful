"""voice_samples/의 엔진 비교 WAV를 MP3로 바꿔 web/voice-samples/에 비교 페이지를 만든다.

사용법: .tts/venv-st/Scripts/python.exe tool/tts/make_sample_page.py
"""

import html
import json
from pathlib import Path

import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "voice_samples"
OUT = ROOT / "web" / "voice-samples"

TEXT = {
    "ko": "어서 오세요! 몇 분이세요? 창가 자리랑 바 자리 중에 어디가 좋으세요?",
    "en": "Hi, welcome in! How many people are with you today? Would you like a table by the window?",
    "ja": "いらっしゃいませ。何名様ですか？窓際のテーブルとカウンター席、どちらがよろしいですか？",
}
LANG = {"ko": "한국어", "en": "영어(미국식)", "ja": "일본어(도쿄 표준어)"}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rows = {lang: [] for lang in TEXT}
    for report_name, engine in [("supertonic_report.json", "Supertonic 3"), ("qwen_report.json", "Qwen3-TTS 0.6B")]:
        report = json.loads((SRC / report_name).read_text(encoding="utf-8"))
        for item in report["items"]:
            wav, sr = sf.read(str(SRC / item["file"]))
            mp3 = item["file"].replace(".wav", ".mp3")
            sf.write(str(OUT / mp3), wav, sr, format="MP3", compression_level=0.6)
            rtf = item["gen_sec"] / item["audio_sec"] if item["audio_sec"] else 0
            rows[item["lang"]].append((engine, item["voice"], mp3, item["audio_sec"], item["gen_sec"], rtf))

    parts = []
    for lang, items in rows.items():
        parts.append(f"<h2>{LANG[lang]}</h2><p class='t'>{html.escape(TEXT[lang])}</p><table>")
        parts.append("<tr><th>엔진</th><th>목소리</th><th>듣기</th><th>음성 길이</th><th>생성 시간(CPU)</th></tr>")
        for engine, voice, mp3, audio, gen, rtf in items:
            parts.append(
                f"<tr><td>{engine}</td><td>{voice}</td>"
                f"<td><audio controls preload='none' src='{mp3}'></audio></td>"
                f"<td>{audio:.1f}초</td><td>{gen:.1f}초 (×{rtf:.1f})</td></tr>"
            )
        parts.append("</table>")

    page = f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BUTTERFUL 음성 엔진 비교</title>
<link rel="icon" type="image/svg+xml" href="../favicon.svg">
<style>
body{{font-family:-apple-system,"Segoe UI",Roboto,"Noto Sans KR",sans-serif;background:#FFF9EE;color:#2A2420;margin:0;padding:24px 16px 60px}}
main{{max-width:880px;margin:0 auto}} h1{{font-size:24px}} h2{{margin-top:36px;font-size:19px}}
.t{{background:#fff;border:1px solid #EFE4D3;border-radius:14px;padding:12px 14px}}
table{{width:100%;border-collapse:collapse;background:#fff;border-radius:14px;overflow:hidden;font-size:14px}}
th,td{{padding:8px 10px;border-bottom:1px solid #EFE4D3;text-align:left}} th{{background:#FFF0BF}}
audio{{width:220px;height:36px}} .note{{color:#6E5A4B;line-height:1.7;font-size:14px}}
a{{color:#E46F3A}}
</style></head><body><main>
<h1>BUTTERFUL 음성 엔진 비교 샘플</h1>
<p class="note">같은 문장을 두 오픈소스 음성 엔진으로 이 개발 PC(Intel Core Ultra 7 265U, GPU 없음, CPU만 사용)에서 만들었습니다.
생성 시간 옆 ×값은 음성 1초를 만드는 데 걸린 시간(초)입니다. 모두 AI로 만든 음성입니다.<br>
앱에는 Supertonic 3을 썼습니다(F1=Mia, M1=Leo, F2=Hana, M2=Theo, F3=Ellie, M4=모범 답변).
<a href="../">← 앱으로 돌아가기</a></p>
{''.join(parts)}
</main></body></html>
"""
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print("written", OUT / "index.html", sum(len(v) for v in rows.values()), "samples")


if __name__ == "__main__":
    main()
