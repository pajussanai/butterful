import 'device_voice_stub.dart'
    if (dart.library.js_interop) 'device_voice_web.dart'
    as impl;

/// 기기(브라우저) 기본 음성. 캐릭터 음성 서버가 없을 때만 쓰며, 화면에 캐릭터 음성이 아니라고 알린다.
abstract class DeviceVoice {
  /// 이 기기에서 [lang] 언어를 읽을 수 있는지(목소리 목록이 늦게 올 수 있어 잠시 기다린다)
  Future<bool> supports(String lang);

  /// 끝까지 읽거나 멈추면 끝난다.
  Future<void> speak(String lang, String text);

  Future<void> stop();
}

/// 앱 언어 코드 → 브라우저 언어 태그. 영국 영어·스페인 본토는 그 지역 목소리만 쓴다(다른 억양으로 대신하지 않음).
const deviceLocales = <String, String>{
  'en': 'en-US',
  'en_gb': 'en-GB',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'zh': 'zh-CN',
  'fr': 'fr-FR',
  'es': 'es-ES',
};

/// 지역까지 맞아야 하는 언어(맞는 목소리가 없으면 쓰지 않는다)
const strictLocales = {'en_gb', 'es'};

DeviceVoice createDeviceVoice() => impl.create();
