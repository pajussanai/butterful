# 외부 구성 요소 고지

## 대화 음성: Supertonic 3

- 앱의 `assets/audio/` 음성은 Supertone의 Supertonic 3 모델로 만든 **AI 생성 음성**입니다.
- 모델 가중치 라이선스: BigScience Open RAIL-M (https://huggingface.co/Supertone/supertonic-3)
- 이 저장소는 모델 가중치를 포함하거나 배포하지 않으며, 모델로 만든 음성 파일만 포함합니다.
- 라이선스의 사용 제한에 따라 앱 화면에 음성이 AI로 만들어졌다는 사실을 표시합니다.
- 음성 생성 예제 코드(supertonic 패키지): MIT

## 비교용 샘플: Qwen3-TTS

- `web/voice-samples/qwen_*.mp3`는 Qwen3-TTS(`Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`, Apache-2.0)로 만든 비교용 AI 음성입니다. 앱 대화에는 쓰지 않습니다.

## 앱 라이브러리

- Flutter (BSD-3-Clause), just_audio (MIT), shared_preferences (BSD-3-Clause)
