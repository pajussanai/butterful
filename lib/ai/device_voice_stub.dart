import 'device_voice.dart';

/// 웹이 아닌 환경(테스트 등): 기기 음성을 쓰지 않는다.
DeviceVoice create() => _NoDeviceVoice();

class _NoDeviceVoice implements DeviceVoice {
  @override
  Future<bool> supports(String lang) async => false;

  @override
  Future<void> speak(String lang, String text) async {}

  @override
  Future<void> stop() async {}
}
