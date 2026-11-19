# 중급 AI 회화: 구현·검증 기록

작성일: 2026-11-19 · 대상: 이 저장소를 이어서 개발·운영할 사람

## 1. 지금 상태

| 기능 | 상태 |
|---|---|
| 중급 화면(언어 7개, 기존 캐릭터 5명, 주제 9개 + 직접 입력, 대화, 교정, 끝내기·새 대화, 주제 바꾸기) | 구현, 위젯 테스트 통과 |
| Gemini 음성 이해 + 교정 + 캐릭터 응답(한 번의 요청) | **배포·실측 완료**(Supabase `butterful`, 7개 언어) |
| 캐릭터 음성(기존 엔진) | 서버 구현·로컬 실측 완료, **무료로 둘 곳이 없어 아직 배포하지 않음** |
| 기기(브라우저) 기본 음성 | 캐릭터 음성 서버가 없는 동안 AI 응답을 읽음(Web Speech API, 무료). 화면에 "캐릭터 목소리가 아니에요" 표시. 영국 영어·스페인 본토는 그 지역 목소리가 있을 때만 쓰고, 없으면 글로만. 캐릭터 음성이 실패해도 이것으로 대신 읽음 |
| 중국어 캐릭터 음성(Qwen3-TTS) | 무료 CPU에서 한 문장 38–46초 → 실시간 불가, 대안은 §6 |
| 고급 | 범위 밖(준비 중 그대로) |

## 2. 구조

```
Flutter Web(GitHub Pages)
  중급 설정 → 대화 화면 ─ 마이크(16kHz 모노 WAV, 최대 30초, 메모리에서만)
     │  POST /intermediate-turn  {lang, character, topic, history(최근 8줄), summary, audio | text}
     │  POST /tts               {language, character_id, text}
Supabase Edge Functions(프로젝트 butterful, verify_jwt=false, 허용 출처만)
  intermediate-turn: 요청 검증·사용자별 제한 → Gemini Interactions API(음성+프롬프트+JSON Schema) → 검증된 JSON
  tts: 언어 → 엔진 서버 고르기(TTS Router) → MP3 전달. 서버가 없으면 tts_unavailable
TTS 서버(server/tts, FastAPI): Supertonic 3(en·ja·ko·fr) + Kokoro-82M(en_gb·es), 같은 /tts 인터페이스
```

- 캐릭터 설정은 `catalog.json`을 읽기만 한다. Edge Function용 복사본 `supabase/functions/_shared/characters.json`은 `python tool/ai/sync_characters.py`로 만들고, `flutter test`가 두 파일이 같은지 확인한다.
- 프롬프트는 서버에만 있다. 앱은 ID만 보내므로 서버를 범용 챗봇으로 쓸 수 없다. 직접 입력한 주제는 "주제로만 다루라"고 표시해 넘긴다.
- 대화 기록·음성은 브라우저 메모리에만 있고 화면을 나가면 사라진다. 서버 로그에는 언어·상태·시간·토큰 수만 남는다.

## 3. Gemini

- API: Interactions API(`POST /v1beta/interactions`, 공식 문서가 권장). `GEMINI_API_STYLE=generate_content`로 기존 generateContent도 쓸 수 있다.
- 모델: **`gemini-3.1-flash-lite`**(기본값, 비밀값 `GEMINI_MODEL`로 바꿈), `thinking_level=minimal`.
- 응답 형식(JSON Schema): `recognized_text, is_understandable, correction_needed, corrected_text, natural_expression, correction_explanation, character_response, next_question, response_translation, conversation_summary`. 파싱 실패·항목 누락은 서버(`parseTurn`)와 앱(`TurnResult.fromJson`) 양쪽에서 기본값으로 처리하고, 형식이 깨지면 한 번만 다시 묻는다.

### 실측(배포된 함수, 2026-11-19)

테스트 발화는 로컬 TTS로 만든 음성이다(학습자 억양이 아님). 언어마다 맞는 문장·틀린 문장 음성과 구어체 입력을 썼다. 스크립트는 `tool/ai/live_check.py`.

| 모델 | 틀린 문장을 고치지 않고 받아 적음 | 교정 | 맞는 문장 오교정 | 응답 시간 |
|---|---|---|---|---|
| gemini-3.5-flash-lite | 5/7 (en_gb·fr의 실수를 받아쓰기에서 고쳐 버림, en_gb "month"를 "week"로) | 5/7 | 1/14(한국어 반말) | 4–10초 |
| **gemini-3.1-flash-lite** | **21/21**(언어별 3회) + 최종 7/7 | **7/7** | **0/14** | **중앙값 3.7초**, 1.2–5.4초(한 번 20.8초) |
| gemini-3.8-flash | 호출 실패(503, 원인 미확인) | — | — | — |

고친 것: 받아쓰기는 들은 그대로(예시 포함), 반말·タメ口는 오류가 아님, 설명·번역은 한국어(한국어 과정은 영어) — 스키마 항목 설명과 매 턴 알림으로 강제. 받아쓰기 전용 1단계(`GEMINI_TRANSCRIBE_FIRST=1`)도 만들었지만 요청이 두 배가 되고 9–16초가 걸려 꺼 두었다.

남은 한계: 실제 학습자 억양·잡음 녹음으로는 시험하지 못했다. Gemini 출력은 매번 조금씩 달라, 드물게 받아쓰기가 실수를 고쳐 적을 수 있다.

## 4. 캐릭터 음성(TTS) 실측

무료 서버와 같은 조건으로 CPU 스레드 2개(`TTS_THREADS=2`), `server/tts/bench.py`.

| 엔진(언어) | 불러오기 | 한 문장(60–140자) | 실시간 대비 | 최대 메모리 |
|---|---|---|---|---|
| Supertonic 3(en, ja, ko, fr) | 1.2–1.4초 | 1.4–3.9초 | 0.26–0.49배 | 505MB |
| Kokoro-82M(en_gb, es) | 1.4초(언어별 첫 사용 +6초) | 2.1–4.6초 | 0.7–1.0배 | 1.9GB |
| Qwen3-TTS 0.6B(zh) | 10.7초 | **38–46초** | 7.4–9.2배 | 5.7GB |
| (참고) Kokoro 중국어 | 2.3초 | 5.5–8.1초 | 1.0–1.2배 | — |

- 6개 언어 × 5명 = 30개 조합을 HTTP 서버(`server/tts/app.py`)로 모두 생성했다(`smoke_test.py`).
- 음색 유지: 화자 인식 모델(ECAPA)로 새 음성을 초급 MP3와 비교해 **30/30이 같은 캐릭터로 판정**(유사도 0.69–0.93, 같은 사람 기준 0.6 이상).
- 동시 요청: CPU 2개에서는 동시에 만들면 모두 느려지므로 서버가 한 번에 한 문장씩 만든다(줄 세움).
- 직접 소리를 들어 확인한 것은 아니다(기계 측정만).

### 둘 곳(2026-11-19 확인)

| 후보 | 결과 |
|---|---|
| Supabase Edge Functions | 불가: TypeScript(Deno)만, 메모리 약 256MB·요청당 CPU 약 2초 |
| Hugging Face Spaces 무료 | **불가**: Docker·Gradio Space 생성에 PRO($9/월) 필요. 무료는 ZeroGPU Gradio 2개뿐 |
| Modal Starter | 월 $30 크레딧, 초과 시 과금(카드 필요 여부 미확인) |
| Cloud Run 무료 등급 | 결제 계정 필요 |
| 브라우저 안 Supertonic | 기기마다 모델 약 400MB 내려받기 → 휴대폰에 무리 |

## 5. 무료 운영과 제한

- Gemini 키는 **결제 계정을 연결하지 않은 무료 키**다. 한도를 넘으면 Gemini가 429로 거절하고, 서버는 `quota_exceeded`를 돌려주며 앱은 "무료 사용량이 끝났어요, 요금은 청구되지 않아요"를 보여 주고 마이크를 막는다. 유료로 넘어가는 코드는 없다.
- 무료 등급 한도(RPM·RPD)는 공식 문서에 모델별 숫자가 없고 AI Studio 로그인 화면에만 있다. 실측 중(약 150회 요청) 한도에 걸리지 않았다.
- 우리 서버의 사용자별 제한(IP 기준, 인스턴스 메모리, 최선의 노력): 분당 8턴, 시간당 80턴, 하루 200턴, TTS 분당 12·하루 300. 비밀값 `TURN_PER_*`, `TTS_PER_*`, `GLOBAL_TURNS_PER_MINUTE`로 바꾼다. 정확한 사용자별 상한이 필요하면 최소한의 표(날짜·익명 키·횟수) 하나를 두는 방법을 제안한다(아직 DB 없음).
- Gemini API 약관(무료 등급): 입력을 Google 제품 개선에 쓸 수 있고 사람이 검토할 수 있음, 민감 정보 금지, **만 18세 이상**, **EEA·영국·스위스 사용자에게는 무료 등급 금지**. 앱은 첫 대화 전에 이 내용을 알리고 동의를 받는다(`AiConsent`, 기존 학습 설정과 다른 키).

## 6. 중국어 음성 대안

| 대안 | 비용 | 목소리 | 비고 |
|---|---|---|---|
| 글로만(현재) | 0 | — | 정직하게 "음성 준비 중" |
| Kokoro 중국어(CPU) | 서버 필요(위 표의 호스팅 문제와 같음) | 초급과 다름. 4개 목소리 정확(받아쓰기 기준 한 글자 안팎 차이), zf_xiaoni는 부정확 | 2코어에서 5.5–8초 |
| Qwen3-TTS를 GPU에서 | HF PRO $9/월(ZeroGPU, 할당량·속도 미확인) 또는 서버리스 GPU 약 $0.8/시간(미확인) | 초급과 같음 | 대기 후 첫 응답 지연 |
| Alibaba Qwen3-TTS 목소리 복제 API | 1만 자당 약 $0.10–0.13(미확인), 90일 1만 자 무료 | 기존 기준 음성으로 복제하면 비슷 | 음성 데이터가 Alibaba Cloud로 감, 결제 등록 필요 |
| 브라우저 기본 음성 | 0 | 기기 목소리 | 7개 언어 모두 가능 |

## 7. 운영 방법

```
# Edge Functions 배포(도커 없이)
supabase functions deploy intermediate-turn tts --project-ref rtnmjulqeuoccatlrhzb --use-api
# 비밀값(키는 저장소에 두지 않는다. 예시는 supabase/.env.example)
supabase secrets set GEMINI_MODEL=gemini-3.1-flash-lite --project-ref rtnmjulqeuoccatlrhzb
# 캐릭터 음성 서버를 연결할 때
supabase secrets set TTS_URL=https://... TTS_SHARED_SECRET=... --project-ref rtnmjulqeuoccatlrhzb
# TTS 서버 이미지 폴더 만들기(Hugging Face Space 등에 올림)
python server/tts/prepare_space.py
# 확인
.tts/deno/deno.exe test --allow-read supabase/functions/_shared/prompt_test.ts
python tool/ai/live_check.py https://rtnmjulqeuoccatlrhzb.supabase.co/functions/v1   # Gemini 무료 한도를 씀
```

앱의 서버 주소는 `lib/ai/intermediate_api.dart`의 기본값(공개 주소)이며 `--dart-define=AI_API_BASE=`로 바꿀 수 있다. GitHub Actions 배포 설정은 바꾸지 않았다.
