# 음성 엔진 선정 기록

언어별 엔진과 캐릭터 목소리 설정은 [engines.json](engines.json)에 있다. 이 문서는 그렇게 정한 근거다.
모든 음성은 개발 PC(CPU)에서 미리 만든 MP3이고, 앱은 실행 중에 TTS를 호출하지 않는다.

## 평가 방법 (사람이 듣지 않고 기계로 잰 것)

| 항목 | 도구 | 무엇을 보나 |
|---|---|---|
| 영어 억양 | CommonAccent ECAPA (`Jzuluaga/accent-id-commonaccent_ecapa`, 16개 억양) | 영국(england)·미국(us) 판정 |
| 발음 정확도 | faster-whisper small | 받아 적은 글과 원문의 단어 오류율(WER, 강세 부호·대소문자 무시) |
| 스페인 본토식 발음 | Kokoro 발음 변환 결과(IPA) 확인 | z·ce·ci → θ (distinción) |
| 캐릭터 구분 | 화자 인식 ECAPA (`speechbrain/spkrec-ecapa-voxceleb`) | 목소리끼리 코사인 유사도 |

시도했지만 근거로 쓰지 않은 것:
- 스페인어 억양 분류기(`Jzuluaga/accent-id-commonaccent_xlsr-es-spanish`): 모델 저장소의 실제 녹음 4개(스페인·멕시코·안데스·카리브)를 하나도 맞히지 못했다.
- 음소 인식(`facebook/wav2vec2-lv-60-espeak-cv-ft`)으로 θ 세기: 실제 멕시코 녹음에서도 θ를 잡아 구분력이 없었다.

스크립트: `eval_voices.py`, `eval_speakers.py`, `eval_theta.py`. 비교 음성과 결과 JSON은 `voice_samples/compare/`(저장소 밖, .gitignore)에 있다.

## 영어(영국식): Qwen3-TTS → Kokoro-82M

**문제 원인.** 기존 영국 영어는 Qwen3-TTS VoiceDesign으로 "Received Pronunciation" 목소리를 설계한 뒤 0.6B Base로 복제했다.
억양 분류기는 그 결과 7문장 모두를 **미국(us)** 으로 판정했다. 복제 과정에서 영국식 억양이 유지되지 않았다.
언어 코드를 en_gb로 둔 것만으로는 억양이 바뀌지 않는다.

같은 8문장(대사 5, 짧은 답변 2, 영국식 구분용 문장 1) 비교:

| 후보 | england | us | WER |
|---|---|---|---|
| Qwen3-TTS (기존 앱 음성) | 0/7 | 7/7 | 0% |
| Supertonic 3 F1 (미국식 기준) | 0/8 | 8/8 | 2% |
| Kokoro bf_emma / bf_isabella / bf_lily | 8/8 | 0 | 0–3% |
| Kokoro bf_alice | 7/8 | 0 | 2% |
| Kokoro bm_lewis / bm_george / bm_fable / bm_daniel | 8/8, 7/8, 6/8, 6/8 | 0–1 | 0–1% |

WER의 차이는 대부분 "ten-minute"를 "10"으로 적은 표기 차이다.

**결정: Kokoro-82M (lang_code "b").** 영국식 발음 사전과 G2P(misaki en-GB)를 쓰고 목소리도 영국인 화자다.
캐릭터 5명을 모두 만들었다(기존 Mia 1명 → 5명).
- Mia `bf_emma`(영국 여성 중 품질 등급 가장 높음), Hana `bf_isabella`, Ellie `bf_lily`, Leo `bm_george`, Theo `bm_fable`, 모범 답변 `bm_lewis`

## 프랑스어: Supertonic 3

8문장 비교에서 Supertonic 10개 목소리의 WER은 0–1.6%였고, Whisper 언어 판별도 모두 프랑스어였다.
Kokoro 프랑스어는 목소리가 `ff_siwis` 하나뿐이라 캐릭터 5명을 만들 수 없다.
프랑스어 억양(본토·퀘벡 등)을 가르는 공개 분류기는 찾지 못해 억양은 기계로 확인하지 못했다.

**결정: Supertonic 3.** 다른 Supertonic 언어와 같은 캐릭터 목소리(Mia F1, Leo M1, Hana F2, Theo M2, Ellie F3, 모범 답변 M4)를 쓴다.

## 스페인어(스페인 본토): Supertonic 3 → Kokoro-82M

Supertonic 3 스페인어는 발음은 정확했지만(WER 0–11%, 대부분 강세 부호 차이), 억양 분류기가 대부분 멕시코 등 중남미로 판정했다.
그 분류기는 신뢰도가 낮아(위 참고) 근거로 삼지 않았다. 대신 엔진이 무엇을 읽도록 지시받는지로 판단했다.
Supertonic은 글자를 바로 소리로 바꿔 발음을 지정할 수 없다.
Kokoro는 espeak-ng의 카스티야 스페인어 규칙으로 발음기호를 만든 뒤 그대로 읽는다.

```
Gracias. ¿Me pone una cerveza y la cuenta?  →  ɡɾˈaθjas. ¿me pˈone ˈuna θeɾβˈeθa i la kwˈɛnta?
La plaza está muy cerca del centro          →  la plˈaθa estˈa mˈuj θˈeɾka ðel θˈɛntɾo
```

z·ce·ci는 θ로, s는 s로 구분된다. 이것이 스페인 본토의 distinción 발음이다.

**결정: Kokoro-82M (lang_code "e").** 스페인어 원어민 목소리는 3개뿐이다(ef_dora, em_alex, em_santa).
나머지는 다른 언어 목소리의 음색에 스페인어 발음기호를 입혔다. 화자 유사도로 서로 구분되는 목소리를 골랐다.
- 같은 사람으로 나온 조합은 제외했다: pf_dora≈ef_dora 0.98, pm_santa≈em_santa 0.98.

| 캐릭터 | 목소리 | 비고 |
|---|---|---|
| Mia | ef_dora | 스페인어 원어민 여성 |
| Hana | if_sara | Mia와 유사도 0.22, 스페인어 판별 확률 0.904(ef_dora 0.910과 비슷) |
| Ellie | af_heart 50% + ef_dora 50% | af_heart만 쓰면 영어 억양이 남음(스페인어 판별 확률 0.727) → 혼합 후 0.903 |
| Leo | em_santa | 스페인어 원어민 남성, θ가 가장 뚜렷 |
| Theo | em_alex | 스페인어 원어민 남성 |
| 모범 답변 | im_nicola 35% + em_alex 65% | im_nicola만 쓰면 이탈리아어 억양(판별 확률 0.814). 혼합 후 짧은 답변 50개 중 43개가 스페인어로 판별(원어민 em_santa 42/50) |

빌려 온 목소리(Hana의 if_sara 등)의 원래 억양이 남는지는 Whisper 언어 판별로 확인했다.
처음 정한 af_heart·im_nicola 단독은 일부 문장이 영어·이탈리아어로 판별되어, 스페인어 원어민 목소리를 섞었다.
그 대가로 모범 답변은 Theo와 목소리가 비슷하다(유사도 0.84).
Whisper 언어 판별은 카스티야 억양을 갈리시아어 등으로 헷갈리기도 한다(원어민 em_santa도 0.685). 그래서 외국어 억양 여부를 보는 데만 썼다.

모든 후보의 WER은 0–13%였고, 오류는 "siete a diez"를 "7 a 10"으로 적은 정도였다.

## 중국어: Qwen3-TTS

Supertonic은 중국어를 지원하지 않는다. Qwen3-TTS는 중국어에 가장 강한 엔진이다.
VoiceDesign 1.7B로 캐릭터 6명의 목소리를 설계했고, 0.6B Base로 복제해 대사를 읽힌다.
기존 Leo 1명에서 캐릭터 5명으로 늘렸다.
- Qwen은 가끔 끝을 내지 못하고 소리를 계속 만든다. 그래서 문장 길이로 상한을 두고, 넘치면 다시 만든다.
- 모범 답변은 두 번째 후보 `guide_1`을 쓴다. 생성된 음성 기준으로 Leo와의 유사도가 0.87(`guide_0`)에서 0.73으로 내려갔다.
- `tool/tts/voices/en_gb/`의 Qwen 목소리는 영국 영어가 Kokoro로 바뀌어 더 이상 쓰지 않는다(기록으로 남김).

## 최종 전수 검증 (앱에 들어간 음성 파일 전부)

| 언어 | 파일 | 받아쓰기 오류율(캐릭터별 평균) | 언어 판별 | 억양 | 캐릭터 구분(유사도 최대) |
|---|---|---|---|---|---|
| 영어(영국식) | 225 | 0.6–3.8% | 영어 225/225 | england 218/225, us 2 | 0.51 (Mia–Ellie) |
| 프랑스어 | 225 | 1.4–3.5% | 프랑스어 225/225 | (분류기 없음) | 0.50 (Leo–모범 답변) |
| 스페인어 | 225 | 1.0–3.6% | 스페인어 208/225 (처음 구성 198/225) | θ 발음기호 입력 확인 | 0.84 (Theo–모범 답변) |
| 중국어 | 225 | 글자 오류율 2.8–5.1%, 모범 답변 9.7%* | 중국어 223/225 | — | 0.76 (Mia–Ellie), 0.74 (Theo–모범 답변) |

\* Whisper가 번체자로 적은 것을 간체자로 바꿔 채점했다. 남은 오류는 대부분 발음이 같은 글자(坐/做, 七/7)를 헷갈린 경우다.
아주 짧은 답변 3개(付现金 등)는 다시 만들어 2개가 나아졌다.
- 받아쓰기 오류가 25%를 넘는 파일: 프랑스어 3개, 영국 영어 5개, 스페인어 4개.
- 대부분 동음 표현("je la prends"/"je l'apprends"), 이름(Kim Minjun), 숫자 표기, "lift"→"left" 같은 경우다.

## 상용 서비스

계정과 API 키가 없어 비교 음성을 만들지 못했다.
세 언어(영국 영어·프랑스어·스페인어) 전체 대사는 약 33,000자다. 공개된 가격으로 어림하면 비용은 크지 않다.
- Azure Neural 약 $15/100만 자, Google Neural2 약 $16/100만 자, Chirp 3 HD 약 $30/100만 자. 둘 다 무료 한도가 있다.
- ElevenLabs는 유료 요금제부터 상업적 이용이 가능하다.

비용보다 계정 개설, 키 관리, 상업 이용 약관 검토가 걸림돌이다. 품질이 부족하다고 판단되면 다음 후보로 둔다.

## 실행 환경 메모 (이 PC)

- 윈도우 애플리케이션 제어 정책이 일부 최신 패키지의 DLL을 막는다. 다음 버전으로 고정했다: numpy 2.5.4, torch 2.15.0, ctranslate2 4.9.0, srsly 2.4.8, spacy 3.8.7, transformers 4.57.3.
- 심볼릭 링크 권한이 없다. speechbrain 모델은 `LocalStrategy.COPY`로 받는다.
