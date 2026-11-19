# BUTTERFUL TTS 서버(Hugging Face Spaces, Docker SDK, 무료 CPU basic: 2 vCPU · 16GB)
#   기본: Supertonic 3 + Kokoro-82M (en, ja, ko, fr, en_gb, es)
#   중국어(Qwen3-TTS)는 무료 CPU에서 한 문장에 약 40초가 걸려 기본으로 켜지 않는다(docs/intermediate-ai.md).
# 이미지를 만들 때 모델을 미리 내려받아, 서버가 깨어날 때 다시 받지 않게 한다.
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends espeak-ng && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user PATH=/home/user/.local/bin:$PATH PYTHONUNBUFFERED=1 \
    TTS_ENGINES=supertonic,kokoro TTS_THREADS=2
WORKDIR /home/user/app

COPY --chown=user requirements-main.txt .
RUN pip install --no-cache-dir --user -r requirements-main.txt \
 && pip install --no-cache-dir --user "en_core_web_sm @ https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"

COPY --chown=user . .
RUN python -c "from supertonic import TTS; TTS(auto_download=True)" \
 && python -c "from kokoro import KPipeline; [KPipeline(lang_code=c, repo_id='hexgrad/Kokoro-82M') for c in 'be']" \
 && python -c "import tts_engines as t; r=t.Router(['supertonic','kokoro']); [r.synthesize(l,c,'OK.') for l in r.languages() for c in t.CHARACTERS]"

EXPOSE 7860
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]
