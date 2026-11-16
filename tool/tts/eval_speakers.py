"""캐릭터 목소리끼리 얼마나 구분되는지 잰다(화자 인식 모델 speechbrain/spkrec-ecapa-voxceleb).

묶음(group)마다 화자 임베딩 평균을 내고, 묶음끼리 코사인 유사도 표를 출력한다.
같은 사람 녹음끼리는 보통 0.6 이상, 서로 다른 사람은 0.5 아래로 나온다.

사용법: .tts/venv-eval/Scripts/python.exe tool/tts/eval_speakers.py <파일 목록 JSON> [묶음 ...]
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

import torch
from speechbrain.inference.speaker import EncoderClassifier
from speechbrain.utils.fetching import LocalStrategy

from eval_voices import SAVE, load16k


def main() -> None:
    items = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    only = sys.argv[2:]
    model = EncoderClassifier.from_hparams(
        source="speechbrain/spkrec-ecapa-voxceleb",
        savedir=str(SAVE / "spkrec-ecapa-voxceleb"),
        local_strategy=LocalStrategy.COPY,
    )
    embs = defaultdict(list)
    for it in items:
        if only and it["group"] not in only:
            continue
        e = model.encode_batch(load16k(it["file"]).unsqueeze(0))[0, 0]
        embs[it["group"]].append(torch.nn.functional.normalize(e, dim=0))
    groups = only or sorted(embs)
    mean = {g: torch.nn.functional.normalize(torch.stack(embs[g]).mean(0), dim=0) for g in groups}
    width = max(len(g) for g in groups)
    print(" " * width, " ".join(f"{i:>5}" for i in range(len(groups))))
    for i, a in enumerate(groups):
        row = " ".join(f"{float(mean[a] @ mean[b]):5.2f}" for b in groups)
        print(f"{a:<{width}} {row}  [{i}]")


if __name__ == "__main__":
    main()
