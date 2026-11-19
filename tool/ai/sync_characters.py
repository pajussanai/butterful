"""Edge Function이 쓰는 캐릭터 설정 복사본을 catalog.json에서 만든다(catalog.json은 읽기만 한다).

supabase/functions/_shared/characters.json ← assets/content/catalog.json의 characters(이름·성격·말투)와 languages
flutter test(test/intermediate_test.dart)가 두 파일이 어긋나지 않았는지 확인한다.
사용법: python tool/ai/sync_characters.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
catalog = json.loads((ROOT / "assets/content/catalog.json").read_text(encoding="utf-8"))
out = {
    "languages": {l["code"]: {"name": l["name"], "native": l["native"], "variant": l["variant"]} for l in catalog["languages"]},
    "characters": {
        c["id"]: {"names": c["names"], "personality": c["personality"], "style": c["style"]} for c in catalog["characters"]
    },
}
path = ROOT / "supabase/functions/_shared/characters.json"
path.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"wrote {path}")
