"""음성 파일의 억양과 발음 정확도를 기계로 평가한다(로컬 CPU).

- 억양: CommonAccent 억양 분류기(speechbrain)
    en: Jzuluaga/accent-id-commonaccent_ecapa (england, us, ... 16개)
    es: Jzuluaga/accent-id-commonaccent_xlsr-es-spanish (스페인 본토·중남미 지역)
- 발음 정확도: faster-whisper로 받아 적은 글과 원문의 단어 오류율(WER), 자동 언어 판별 결과

사용법:
  .tts/venv-eval/Scripts/python.exe tool/tts/eval_voices.py <언어> <파일 목록 JSON> <결과 JSON>
  파일 목록 JSON: [{"file": 경로, "text": 원문, "group": 묶음 이름}, ...]
"""

import json
import os
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

ROOT = Path(__file__).resolve().parents[2]
SAVE = ROOT / ".tts" / "models"
ACCENT = {
    "en": ("Jzuluaga/accent-id-commonaccent_ecapa", "ecapa"),
    "es": ("Jzuluaga/accent-id-commonaccent_xlsr-es-spanish", "xlsr"),
}


def load16k(path: str) -> torch.Tensor:
    wav, sr = sf.read(path, dtype="float32", always_2d=True)
    wav = wav.mean(axis=1)
    if sr != 16000:
        n = int(len(wav) * 16000 / sr)
        wav = np.interp(np.linspace(0, len(wav) - 1, n), np.arange(len(wav)), wav).astype("float32")
    return torch.from_numpy(wav)


def words(text: str) -> list[str]:
    # 강세 부호(sí/si, sólo/solo)와 대소문자 차이는 발음 오류가 아니므로 지운다.
    text = unicodedata.normalize("NFKD", text).lower().replace("’", "'")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r"[^\w'\s-]", " ", text)
    if os.environ.get("EVAL_CHARS"):  # 중국어처럼 띄어쓰기가 없는 언어는 글자 단위(CER)
        return [c for c in text if not c.isspace() and c not in "-'"]
    return [w for w in re.split(r"[\s-]+", text) if w]


def wer(ref: str, hyp: str) -> float:
    r, h = words(ref), words(hyp)
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            cur = min(d[j] + 1, d[j - 1] + 1, prev + (r[i - 1] != h[j - 1]))
            prev, d[j] = d[j], cur
    return d[len(h)] / max(1, len(r))


def accent_model(lang: str):
    if lang not in ACCENT:
        return None
    from speechbrain.utils.fetching import LocalStrategy

    global COPY
    COPY = LocalStrategy.COPY  # 윈도우에서 심볼릭 링크 권한이 없어 복사한다
    source, kind = ACCENT[lang]
    if kind == "ecapa":
        from speechbrain.inference.classifiers import EncoderClassifier

        return EncoderClassifier.from_hparams(
            source=source, savedir=str(SAVE / source.split("/")[1]), local_strategy=COPY
        )
    # 저장소의 custom_interface.py(원격 코드)는 실행하지 않고, 같은 계산을 여기서 직접 한다:
    # wav2vec2 → 평균 풀링 → 선형층 → softmax. 설정(yaml)과 가중치만 불러온다.
    from speechbrain.inference.interfaces import Pretrained

    class Wav2vec2AccentClassifier(Pretrained):
        MODULES_NEEDED = ["wav2vec2", "avg_pool", "output_mlp"]

        def classify_batch(self, wavs, wav_lens=None):
            if wav_lens is None:
                wav_lens = torch.ones(wavs.shape[0])
            out = self.mods.wav2vec2(wavs.float())
            out = self.mods.avg_pool(out, wav_lens).view(wavs.shape[0], -1)
            prob = self.hparams.softmax(self.mods.output_mlp(out))
            score, index = torch.max(prob, dim=-1)
            return prob, score, index, self.hparams.label_encoder.decode_torch(index)

    # 저장소 설정은 옛 speechbrain 클래스 경로를 써서, 로컬 폴더에 경로만 고친 설정과 가중치를 둔다.
    from huggingface_hub import hf_hub_download

    local = SAVE / (source.split("/")[1] + "-local")
    local.mkdir(parents=True, exist_ok=True)
    for f in ["hyperparams.yaml", "label_encoder.txt", "model.ckpt", "normalizer_input.ckpt", "wav2vec2.ckpt"]:
        src = Path(hf_hub_download(source, f))
        if f == "hyperparams.yaml":
            text = src.read_text(encoding="utf-8")
            text = text.replace(
                "speechbrain.lobes.models.huggingface_wav2vec.HuggingFaceWav2Vec2",
                "speechbrain.lobes.models.huggingface_transformers.wav2vec2.Wav2Vec2",
            ).replace(f"pretrained_path: {source}", f"pretrained_path: {local.as_posix()}")
            text = text.replace("save_path: wav2vec2_checkpoints", f"save_path: {(SAVE / 'wav2vec2_checkpoints').as_posix()}")
            (local / f).write_text(text, encoding="utf-8")
        elif not (local / f).exists():
            (local / f).write_bytes(src.read_bytes())
    return Wav2vec2AccentClassifier.from_hparams(source=str(local), savedir=str(local), local_strategy=COPY)


def main() -> None:
    lang, items_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    items = json.loads(Path(items_path).read_text(encoding="utf-8"))
    from faster_whisper import WhisperModel

    threads = int(os.environ.get("EVAL_THREADS", "0"))  # 생성 작업과 함께 돌릴 때 CPU를 덜 쓰도록
    if threads:
        torch.set_num_threads(threads)
    asr = WhisperModel(
        "small", device="cpu", compute_type="int8", cpu_threads=threads, download_root=str(SAVE / "whisper")
    )
    clf = None if os.environ.get("NO_ACCENT") else accent_model(lang)
    labels = None
    rows = []
    for it in items:
        row = dict(it)
        wav = load16k(it["file"])
        row["sec"] = round(len(wav) / 16000, 2)
        if clf is not None:
            probs, _, _, lab = clf.classify_batch(wav.unsqueeze(0))
            if labels is None:
                enc = clf.hparams.label_encoder
                labels = [enc.ind2lab[i] for i in range(len(enc.ind2lab))]
            p = torch.softmax(probs[0], dim=-1) if probs[0].min() < 0 else probs[0]
            p = p / p.sum()
            row["accent_top"] = lab[0]
            row["accent_probs"] = {labels[i]: round(float(p[i]), 3) for i in torch.argsort(p, descending=True)[:4]}
        segs, info = asr.transcribe(wav.numpy(), language=lang.split("_")[0], beam_size=5)
        hyp = " ".join(s.text.strip() for s in segs)
        _, det = asr.transcribe(wav.numpy(), beam_size=1)
        row["asr"] = hyp
        row["wer"] = round(wer(it["text"], hyp), 3)
        row["detected_lang"] = f"{det.language}:{det.language_probability:.2f}"
        # 목표 언어로 들릴 확률(외국 억양이 강하면 낮아진다)
        target = lang.split("_")[0]
        row["target_lang_prob"] = round(dict(det.all_language_probs or []).get(target, 0.0), 3)
        rows.append(row)
        print(f"{it['group']:<22} {row.get('accent_top', '-'):<28} wer={row['wer']:.2f} {Path(it['file']).name}", flush=True)

    summary = defaultdict(lambda: {"n": 0, "wer": 0.0, "lp": 0.0, "top": defaultdict(int), "mean": defaultdict(float)})
    for r in rows:
        s = summary[r["group"]]
        s["n"] += 1
        s["wer"] += r["wer"]
        s["lp"] += r["target_lang_prob"]
        if "accent_top" in r:
            s["top"][r["accent_top"]] += 1
            for k, v in r["accent_probs"].items():
                s["mean"][k] += v
    final = {}
    for g, s in summary.items():
        final[g] = {
            "n": s["n"],
            "mean_wer": round(s["wer"] / s["n"], 3),
            "mean_target_lang_prob": round(s["lp"] / s["n"], 3),
            "accent_top_counts": dict(s["top"]),
            "accent_mean_prob": {k: round(v / s["n"], 3) for k, v in sorted(s["mean"].items(), key=lambda x: -x[1])[:4]},
        }
    Path(out_path).write_text(json.dumps({"summary": final, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(final, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
