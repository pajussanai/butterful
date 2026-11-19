# BUTTERFUL 버터풀

원어민 목소리를 듣고, 소리 내어 따라 말하고, 내 대답을 골라 대화를 이어 가는 **대화형 외국어 회화 학습 앱**입니다.
주변에 외국인이 없어도 혼자서 실제 상황 대화를 연습할 수 있습니다.

- 웹: https://pajussanai.github.io/butterful/
- 음성 엔진 비교 샘플: https://pajussanai.github.io/butterful/voice-samples/

## 학습 방식

**언어 선택 → 학습 단계(초급·중급·고급) 선택 → 학습.** 단계는 고르기 위한 구분일 뿐, 잠금·승급·평가·진행률은 없습니다.

- **초급**
  - 기초 단어: 10개 주제(인사, 숫자와 시간, 사람과 가족, 음식과 음료, 장소와 방향, 교통, 쇼핑과 돈, 일상 동사, 기본 형용사, 질문 표현) × 10단어. 단어마다 뜻, 발음 표기, 예문, 예문 번역이 있고 단어와 예문을 각각 원어민 음성으로 들을 수 있습니다(느리게 0.75배, 3회 반복).
  - 상황별 대화: 상황(여행, 식당·카페 …)과 대화 상대 캐릭터를 고르면 캐릭터가 원어민 음성으로 말합니다. 다시 듣기, 느리게, 따라 말할 틈을 둔 3회 반복, 원문·발음·번역 보이기를 쓸 수 있고, 고른 대답에 따라 다음 대사가 달라집니다. 대답도 원어민 음성으로 들어 볼 수 있습니다.
- **중급 AI 회화**: 언어·캐릭터(기존 5명)·주제(9개 또는 직접 입력)를 고르고, 마이크로 내 문장을 말하면 Google Gemini가 알아듣고 틀리거나 어색한 표현을 고쳐 주며 캐릭터로서 대화를 이어 갑니다. 교정은 숨길 수 있고, 점수·진도는 없습니다. 캐릭터 음성 서버는 아직 연결 전이라 AI 응답은 글(번역 포함)과 기기(브라우저) 기본 목소리로 들려줍니다(캐릭터 목소리 아님, 화면에 표시). 자세한 내용: [docs/intermediate-ai.md](docs/intermediate-ai.md)
- **고급**(대본 없는 자유 대화): 준비 중이며, 무엇을 하게 될지 안내만 합니다.

캐릭터 이름은 언어마다 그 나라에서 쓰는 이름으로 보입니다(예: 스페인어 Lucía, 일본어 結衣). 캐릭터 ID와 목소리는 모든 언어에서 같습니다.

초급은 내 목소리를 녹음·분석하지 않습니다. 중급 AI 회화는 말한 음성을 Google Gemini API(무료 등급)로 보내 분석하며, 버터풀은 음성과 대화를 저장하지 않습니다(처음 시작할 때 안내·동의, 만 18세 이상).
기기에는 마지막으로 고른 언어와 대화 상대, AI 회화 안내 동의 여부만 저장합니다.
로그인, DB, 결제, 광고가 없습니다. 서버는 중급 AI 회화용 Supabase Edge Functions만 씁니다(API 키는 서버 비밀값).

## 지원 현황

| 언어 | 발음 기준 | 상태 | 음성 엔진 |
|---|---|---|---|
| 영어 | 미국식 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Supertonic 3 |
| 영어 | 영국식 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Kokoro-82M (영국식 발음 사전·영국인 화자) |
| 일본어 | 도쿄 표준어 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Supertonic 3 |
| 한국어 | 서울 표준어 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Supertonic 3 |
| 중국어 | 표준 보통화 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Qwen3-TTS (목소리 설계·복제) |
| 프랑스어 | 프랑스 본토 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Supertonic 3 |
| 스페인어 | 스페인 본토 | 기초 단어 100개, 상황별 대화 9개(식당·호텔·쇼핑 2·일상 2·직장 3), 캐릭터 5명 음성 | Kokoro-82M (카스티야식 발음기호) |

상황별 대화: 여행(호텔 체크인), 식당·카페(식당에서 주문하기), 쇼핑(옷 가게에서 쇼핑하기, 교환·환불하기), 일상생활(새로운 친구와 인사하기, 약속 바꾸고 만나러 가기), 직장·업무(회의 일정 잡고 의견 말하기, 진행 상황 보고와 마감 조율, 거래처와 업무 전화).

## 음성

- 대화 음성은 개발 PC에서 미리 만든 MP3입니다. 앱은 실행 중에 TTS API를 호출하지 않습니다.
- 언어별 엔진과 캐릭터 목소리는 [tool/tts/engines.json](tool/tts/engines.json)에, 엔진을 고른 근거와 평가 결과는 [tool/tts/VOICES.md](tool/tts/VOICES.md)에 있습니다.
- 생성 스크립트(문장이 바뀐 파일만 다시 만듦, 목록은 `manifest_util.py`로 안전하게 합침):
  - Supertonic 3 (en, ja, ko, fr): `.tts/venv-st/Scripts/python.exe tool/tts/generate_audio.py [언어]`
  - Kokoro-82M (en_gb, es): `.tts/venv-kokoro/Scripts/python.exe tool/tts/kokoro_audio.py [언어]`
  - Qwen3-TTS (zh): `.tts/venv-qwen/Scripts/python.exe tool/tts/qwen_audio.py [언어]` (목소리 설계: `qwen_voices.py design zh`)
- 평가 스크립트: `eval_voices.py`(억양 분류·받아쓰기 정확도), `eval_speakers.py`(캐릭터 목소리 구분), `eval_theta.py`(스페인어 θ 발음)
- 라이선스 고지는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 보세요.

## 구조

```
assets/content/catalog.json        언어·상황·시나리오·캐릭터 목록
assets/content/<언어>/<시나리오>.json  분기형 대화(언어마다 같은 대사 ID·분기 구조)
assets/content/<언어>/words.json   초급 기초 단어(공통 개념 목록: tool/content/word_concepts.json)
assets/audio/<언어>/words/<주제>__<단어ID>.mp3, ..._ex.mp3  단어·예문 음성(언어마다 Mia 캐릭터 목소리)
assets/audio/<언어>/<캐릭터>/<시나리오>__<대사ID>.mp3
assets/audio/<언어>/guide/<시나리오>__<대답ID>.mp3   모범 답변
assets/audio/manifest.json         실제로 만든 음성 목록(앱은 이 목록으로 준비 여부를 판단)
lib/                               Flutter 앱
tool/tts/                          음성 생성·비교 스크립트(로컬 전용)
tool/generate_icons_test.dart      앱 아이콘·파비콘 생성
lib/ai/                            중급 AI 회화(서버 호출, 녹음, AI 음성 재생, 대화 상태)
supabase/functions/                중급 AI 회화 서버(Gemini 호출, TTS Router)
server/tts/                        캐릭터 음성 서버(기존 엔진, 아직 배포 전)
tool/ai/                           캐릭터 설정 복사본 만들기, 실제 서버 확인 스크립트
```

## 콘텐츠·음성 추가

1. `assets/content/<언어>/<시나리오>.json`을 쓰고 `catalog.json`의 해당 언어 `content`에 시나리오 ID를 넣습니다.
2. 음성 생성 도구(로컬): 언어의 엔진(`tool/tts/engines.json`)에 맞는 가상 환경을 `.tts/` 아래에 만듭니다(Supertonic: `pip install supertonic`, Kokoro: `pip install kokoro`, Qwen: `pip install qwen-tts`).
3. 해당 엔진의 생성 스크립트를 실행합니다(바뀐 문장만 다시 만듭니다).
4. 새 폴더가 생겼으면 `pubspec.yaml`의 `assets`에 더합니다.
5. `flutter test`가 분기 연결, 결말 도달, 언어 간 구조 일치, 모든 대사의 음성 파일 존재를 확인합니다.

## 개발

```
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /butterful/
```

`main`에 push하면 GitHub Actions가 분석·테스트·웹 빌드 후 GitHub Pages에 배포합니다.
