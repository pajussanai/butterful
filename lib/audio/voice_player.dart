import 'package:just_audio/just_audio.dart';

/// 미리 만든 음성 파일을 재생한다(사용자 음성은 녹음하지 않는다).
abstract class VoicePlayer {
  /// [audio]는 assets/audio 기준 상대 경로. 끝까지 재생하거나 멈추면 끝난다.
  Future<void> play(String audio, {double speed = 1});

  Future<void> stop();

  Future<void> dispose();
}

/// just_audio로 재생(웹에서는 브라우저의 오디오 요소를 쓴다)
class AssetVoicePlayer implements VoicePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String audio, {double speed = 1}) async {
    await _player.stop();
    await _player.setAsset('assets/audio/$audio');
    await _player.setSpeed(speed);
    // play()는 재생이 끝나거나 멈출 때 완료된다.
    await _player.play();
    await _player.stop();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
