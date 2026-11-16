"""스페인어 음성이 스페인 본토식(distinción: z·ce·ci를 θ로)인지 중남미식(seseo: s로)인지 잰다.

음소 인식 모델(facebook/wav2vec2-lv-60-espeak-cv-ft, IPA 출력)로 받아 적고,
문장 속 z·ce·ci 글자 수 대비 인식된 θ 개수를 센다. 스페인 본토식이면 1에 가깝고 중남미식이면 0에 가깝다.

사용법: .tts/venv-eval/Scripts/python.exe tool/tts/eval_theta.py <파일 목록 JSON> <결과 JSON>
  파일 목록 JSON: [{"file": 경로, "text": 원문, "group": 묶음 이름}, ...]
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import torch
from huggingface_hub import hf_hub_download
from transformers import Wav2Vec2FeatureExtractor, Wav2Vec2ForCTC

from eval_voices import load16k

MODEL = "facebook/wav2vec2-lv-60-espeak-cv-ft"


def theta_letters(text: str) -> int:
    t = text.lower()
    return len(re.findall(r"z", t)) + len(re.findall(r"c(?=[eiéí])", t))


def main() -> None:
    items = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    # 토크나이저(phonemizer 필요)는 쓰지 않고 vocab.json으로 CTC 결과를 직접 푼다.
    feat = Wav2Vec2FeatureExtractor.from_pretrained(MODEL)
    vocab = json.loads(Path(hf_hub_download(MODEL, "vocab.json")).read_text(encoding="utf-8"))
    id2tok = {v: k for k, v in vocab.items()}
    model = Wav2Vec2ForCTC.from_pretrained(MODEL).eval()
    groups = defaultdict(lambda: {"expected": 0, "theta": 0, "n": 0})
    rows = []
    for it in items:
        wav = load16k(it["file"])
        inputs = feat(wav.numpy(), sampling_rate=16000, return_tensors="pt")
        with torch.no_grad():
            ids = model(inputs.input_values).logits.argmax(-1)[0].tolist()
        toks, prev = [], None
        for i in ids:
            if i != prev and id2tok[i] not in ("<pad>", "<s>", "</s>", "<unk>"):
                toks.append(id2tok[i])
            prev = i
        ipa = " ".join(toks)
        expected, found = theta_letters(it["text"]), ipa.count("θ")
        g = groups[it["group"]]
        g["expected"] += expected
        g["theta"] += found
        g["n"] += 1
        rows.append({**it, "ipa": ipa, "theta_expected": expected, "theta_found": found})
        print(f"{it['group']:<28} θ {found}/{expected}  {ipa[:70]}", flush=True)
    summary = {
        k: {**v, "ratio": round(v["theta"] / v["expected"], 2) if v["expected"] else None} for k, v in groups.items()
    }
    Path(sys.argv[2]).write_text(json.dumps({"summary": summary, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    for k, v in sorted(summary.items(), key=lambda x: -(x[1]["ratio"] or 0)):
        print(f"{k:<28} θ ratio {v['ratio']}  ({v['theta']}/{v['expected']})")


if __name__ == "__main__":
    main()
