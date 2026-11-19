import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

/// 사용자 음성 녹음. 녹음은 메모리(브라우저 Blob)에만 있고, 서버로 보낸 뒤 버린다.
abstract class VoiceRecorder {
  /// 마이크 권한(없으면 요청)
  Future<bool> requestPermission();

  Future<void> start();

  /// 녹음을 끝내고 WAV 바이트를 돌려준다(녹음이 없으면 null).
  Future<Uint8List?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

/// record 패키지: 브라우저에서 16kHz 모노 WAV로 녹음한다(Gemini가 받는 형식, 모든 브라우저에서 같은 결과).
class MicRecorder implements VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();

  @override
  Future<bool> requestPermission() => _rec.hasPermission();

  @override
  Future<void> start() => _rec.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
    ),
    path: '',
  );

  @override
  Future<Uint8List?> stop() async {
    final url = await _rec.stop();
    if (url == null || url.isEmpty) return null;
    // 웹에서는 blob: 주소가 돌아온다. 바이트를 읽은 뒤에는 따로 보관하지 않는다.
    final res = await http.get(Uri.parse(url));
    return res.statusCode == 200 ? res.bodyBytes : null;
  }

  @override
  Future<void> cancel() => _rec.cancel();

  @override
  Future<void> dispose() => _rec.dispose();
}

/// AI 캐릭터 음성 재생(초급의 미리 만든 MP3 재생기와 따로 관리한다).
abstract class SpeechPlayer {
  /// 끝까지 재생하거나 멈추면 끝난다.
  Future<void> playBytes(Uint8List mp3);

  Future<void> stop();

  Future<void> dispose();
}

class BytesSpeechPlayer implements SpeechPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playBytes(Uint8List mp3) async {
    await _player.stop();
    await _player.setAudioSource(
      AudioSource.uri(Uri.dataFromBytes(mp3, mimeType: 'audio/mpeg')),
    );
    await _player.play();
    await _player.stop();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
