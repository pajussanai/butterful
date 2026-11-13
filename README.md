# BUTTERFUL 버터풀

원어민 목소리를 듣고, 소리 내어 따라 말하고, 내 대답을 골라 대화를 이어 가는 **대화형 외국어 회화 학습 앱**입니다.
주변에 외국인이 없어도 혼자서 실제 상황 대화를 연습할 수 있습니다.

- 웹: https://pajussanai.github.io/butterful/
- 음성 엔진 비교 샘플: https://pajussanai.github.io/butterful/voice-samples/

## 학습 방식

1. 학습 언어를 고릅니다.
2. 상황(여행, 식당·카페 …)을 고릅니다.
3. 대화 상대 캐릭터를 고릅니다(목소리 미리 듣기).
4. 캐릭터가 원어민 음성으로 말합니다. 다시 듣기, 느리게(0.75배), 따라 말할 틈을 둔 3회 반복을 쓸 수 있습니다.
5. 소리 내어 따라 말합니다. 앱은 내 목소리를 녹음·분석하지 않습니다.
6. 내 대답을 고릅니다. 고른 대답에 따라 다음 대사가 달라집니다. 대답도 원어민 음성으로 들어 볼 수 있습니다.
7. 원문, 발음 표기, 번역은 각각 숨기거나 보일 수 있습니다.

진행 상황(들은 대사, 도달한 결말, 완료 횟수, 최근 학습, 이어서 하기)은 브라우저 저장소에만 저장됩니다.
로그인, 서버, DB, 결제, 광고가 없습니다.

## 지원 현황

| 언어 | 발음 기준 | 상태 |
|---|---|---|
| 영어 | 미국식 | 식당·호텔 대화, 캐릭터 5명 음성 |
| 영어 | 영국식 | 식당·호텔 대화, 캐릭터 1명(Mia) 음성 |
| 일본어 | 도쿄 표준어 | 식당·호텔 대화, 캐릭터 5명 음성 |
| 한국어 | 서울 표준어 | 식당·호텔 대화, 캐릭터 5명 음성 |
| 중국어 | 표준 보통화 | 식당·호텔 대화, 캐릭터 1명(Leo) 음성 |
| 프랑스어 | 프랑스 본토 | 준비 중 |
| 스페인어 | 스페인 본토 | 준비 중 |

쇼핑, 일상생활, 직장·업무 상황도 같은 구조로 추가할 수 있으며 지금은 '준비 중'으로 표시됩니다.

## 음성

- 대화 음성은 개발 PC에서 미리 만든 MP3입니다. 앱은 실행 중에 TTS API를 호출하지 않습니다.
- 영어(미국식)·일본어·한국어: **Supertonic 3**(오픈 웨이트, CPU). `tool/tts/generate_audio.py`
- 영어(영국식)·중국어: Supertonic이 지원하지 않아 **Qwen3-TTS**(오픈 웨이트, CPU)로 만듭니다. `tool/tts/qwen_voices.py design <언어>`로 캐릭터 목소리를 설계하고, `tool/tts/qwen_audio.py`로 그 목소리를 복제해 대사를 읽힙니다. 언어마다 캐릭터 1명과 모범 답변 목소리만 있습니다.
- Supertonic 언어에서 캐릭터는 언어와 관계없이 같은 목소리를 씁니다: Mia=F1, Leo=M1, Hana=F2, Theo=M2, Ellie=F3, 모범 답변=M4.
- 비교한 엔진: Supertonic 3, Qwen3-TTS(0.6B CustomVoice). 결과와 샘플은 위 비교 페이지에 있습니다.
- 라이선스 고지는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 보세요.

## 구조

```
assets/content/catalog.json        언어·상황·시나리오·캐릭터 목록
assets/content/<언어>/<시나리오>.json  분기형 대화(언어마다 같은 대사 ID·분기 구조)
assets/audio/<언어>/<캐릭터>/<시나리오>__<대사ID>.mp3
assets/audio/<언어>/guide/<시나리오>__<대답ID>.mp3   모범 답변
assets/audio/manifest.json         실제로 만든 음성 목록(앱은 이 목록으로 준비 여부를 판단)
lib/                               Flutter 앱
tool/tts/                          음성 생성·비교 스크립트(로컬 전용)
tool/generate_icons_test.dart      앱 아이콘·파비콘 생성
```

## 콘텐츠·음성 추가

1. `assets/content/<언어>/<시나리오>.json`을 쓰고 `catalog.json`의 해당 언어 `content`에 시나리오 ID를 넣습니다.
2. 음성 생성 도구(로컬): `.tts/venv-st`에 Python 3.12 가상 환경을 만들고 `pip install supertonic`
3. `.tts/venv-st/Scripts/python.exe tool/tts/generate_audio.py <언어>` (바뀐 문장만 다시 만듭니다)
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
