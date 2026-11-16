# 외부 구성 요소 고지

앱의 `assets/audio/` 음성은 모두 아래 모델로 개발 PC에서 미리 만든 **AI 생성 음성**입니다. 이 저장소는 모델 가중치를 포함하거나 배포하지 않으며, 모델로 만든 음성 파일만 포함합니다. 앱 화면에 음성이 AI로 만들어졌다는 사실을 표시합니다.

## 대화 음성(영어 미국식·일본어·한국어·프랑스어): Supertonic 3

- 모델: Supertone Supertonic 3, 가중치 라이선스 BigScience Open RAIL-M (https://huggingface.co/Supertone/supertonic-3)
- 라이선스의 사용 제한(유해한 용도 금지 등)을 따르고, AI 생성 음성임을 표시합니다.
- 음성 생성 예제 코드(supertonic 패키지): MIT

## 대화 음성(영어 영국식·스페인어): Kokoro-82M

- 모델과 목소리: hexgrad/Kokoro-82M, Apache-2.0 (https://huggingface.co/hexgrad/Kokoro-82M)
- 발음 변환: misaki (MIT), espeak-ng (GPL-3.0, 개발 PC에서 발음기호를 만드는 데만 쓰며 앱에 포함하지 않음)
- 스페인어 일부 캐릭터는 Kokoro의 다른 언어 목소리(if_sara, af_heart, im_nicola)에 스페인어 발음기호를 입혀 만들었습니다.

## 대화 음성(중국어): Qwen3-TTS

- 캐릭터 목소리는 `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`으로 설계하고 `Qwen/Qwen3-TTS-12Hz-0.6B-Base`로 복제해 대사를 읽혔습니다. 모델 라이선스: Apache-2.0

## 비교용 샘플: Qwen3-TTS

- `web/voice-samples/qwen_*.mp3`는 Qwen3-TTS(`Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`, Apache-2.0)로 만든 비교용 AI 음성입니다.

## 앱 라이브러리

- Flutter (BSD-3-Clause), just_audio (MIT), shared_preferences (BSD-3-Clause)
