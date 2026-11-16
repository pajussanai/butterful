"""앱 음성 목록(manifest)에서 한 언어의 모든 음성 파일을 평가용 목록으로 만든다(캐릭터별 묶음).

사용법: python tool/tts/make_items.py <언어> <출력 JSON>
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    lang, out = sys.argv[1], sys.argv[2]
    texts = {}
    for sid in ["restaurant", "hotel"]:
        s = json.loads((ROOT / "assets" / "content" / lang / f"{sid}.json").read_text(encoding="utf-8"))
        for n in s["nodes"]:
            texts[(sid, n["id"])] = n["text"]
            for r in n["replies"]:
                texts[(sid, r["id"])] = r["text"]
    files = json.loads((ROOT / "assets" / "audio" / "manifest.json").read_text(encoding="utf-8"))["files"]
    items = []
    for rel in sorted(files):
        l, ch, name = rel.split("/")
        if l != lang:
            continue
        sid, key = name[:-4].split("__")
        items.append({"file": str(ROOT / "assets" / "audio" / rel), "text": texts[(sid, key)], "group": ch, "rel": rel})
    Path(out).write_text(json.dumps(items, ensure_ascii=False), encoding="utf-8")
    print(lang, len(items))


if __name__ == "__main__":
    main()
