"""TTS 엔진 실행 시간·메모리를 잰다(무료 서버와 비슷하게 CPU 스레드를 TTS_THREADS로 제한).

사용법(엔진마다 해당 가상 환경으로):
  TTS_THREADS=2 .tts/venv-st/Scripts/python.exe server/tts/bench.py supertonic en ja ko fr
  TTS_THREADS=2 .tts/venv-kokoro/Scripts/python.exe server/tts/bench.py kokoro en_gb es
  TTS_THREADS=2 .tts/venv-qwen/Scripts/python.exe server/tts/bench.py qwen zh
결과는 JSON 한 줄로 출력하고, 만든 음성은 저장소 밖 voice_samples/ai_tts/에 둔다(.gitignore).
"""

import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import tts_engines  # noqa: E402

# 중급 대화에서 캐릭터가 말할 만한 길이(약 60–140자)
SAMPLES = {
    "en": ["Oh nice, that sounds like a fun weekend! Did you go there with friends, or was it just you?",
           "Good question. I usually take the subway to work, but on sunny days I like to walk. How about you?"],
    "en_gb": ["Oh lovely, that sounds like a brilliant weekend! Did you go with your mates, or on your own?",
              "Fair enough. I normally get the tube to work, but when it's sunny I walk. What about you?"],
    "ja": ["へえ、楽しそうな週末ですね！お友達と一緒に行ったんですか？",
           "そうですね。普段は電車で通勤していますが、天気がいい日は歩くこともあります。あなたはどうですか？"],
    "ko": ["와, 정말 즐거운 주말이었겠네요! 친구들이랑 같이 갔어요, 아니면 혼자 갔어요?",
           "좋은 질문이에요. 저는 보통 지하철로 출근하는데, 날씨가 좋은 날에는 걸어가요. 당신은요?"],
    "zh": ["哇，听起来是个很开心的周末！你是和朋友一起去的吗？",
           "好问题。我平时坐地铁上班，不过天气好的时候我会走路去。你呢？"],
    "fr": ["Oh super, ça a l'air d'un week-end génial ! Tu y es allé avec des amis ou tout seul ?",
           "Bonne question. D'habitude, je prends le métro pour aller au travail, mais quand il fait beau, je marche. Et toi ?"],
    "es": ["¡Qué bien, parece un fin de semana genial! ¿Fuiste con amigos o tú solo?",
           "Buena pregunta. Normalmente voy al trabajo en metro, pero cuando hace sol voy andando. ¿Y tú?"],
}
CHARS = ["mia", "leo", "hana", "theo", "ellie"]
OUT = Path(__file__).resolve().parents[2] / "voice_samples" / "ai_tts"


def peak_mb() -> float:
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes

        class PMC(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                        ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                        ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]

        pmc = PMC()
        pmc.cb = ctypes.sizeof(PMC)
        k32 = ctypes.WinDLL("kernel32")
        k32.GetCurrentProcess.restype = wintypes.HANDLE
        k32.K32GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(PMC), wintypes.DWORD]
        k32.K32GetProcessMemoryInfo(k32.GetCurrentProcess(), ctypes.byref(pmc), pmc.cb)
        return pmc.PeakWorkingSetSize / 2**20
    import resource

    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024


def main() -> None:
    engine, langs = sys.argv[1], sys.argv[2:]
    OUT.mkdir(parents=True, exist_ok=True)
    router = tts_engines.Router([engine])
    t0 = time.perf_counter()
    router.engine(engine)
    load = time.perf_counter() - t0
    rows = []
    for lang in langs:
        for i, ch in enumerate(CHARS):
            text = SAMPLES[lang][i % 2]
            t = time.perf_counter()
            wav, sr = router.synthesize(lang, ch, text)
            took = time.perf_counter() - t
            dur = len(wav) / sr
            (OUT / f"{lang}_{ch}.mp3").write_bytes(tts_engines.to_mp3(wav, sr))
            rows.append({"lang": lang, "ch": ch, "chars": len(text), "gen_s": round(took, 2), "audio_s": round(dur, 2), "rtf": round(took / dur, 2)})
            print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
    print(json.dumps({"engine": engine, "threads": tts_engines.THREADS, "load_s": round(load, 1), "peak_mb": round(peak_mb())}))


if __name__ == "__main__":
    main()
