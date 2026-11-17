import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/voice_player.dart';
import '../data/content_repository.dart';

/// 기초 단어 화면의 음성 재생(단어·예문 듣기, 반복, 속도). 대화 화면과 같은 방식이다.
class WordAudioController extends ChangeNotifier {
  WordAudioController({
    required this.repo,
    required this.player,
    this.repeatTimes = 3,
  });

  final ContentRepository repo;
  final VoicePlayer player;

  /// 반복 재생을 켰을 때 듣는 횟수
  final int repeatTimes;

  bool slow = false;
  bool repeat = false;

  /// 지금 재생 중인 음성(assets/audio 기준 경로). 없으면 null
  String? playing;

  /// 반복 재생 중 몇 번째인지(1부터)
  int round = 0;

  int _token = 0;
  bool _disposed = false;

  double get speed => slow ? 0.75 : 1.0;

  /// [audio]를 듣는다. 이미 재생 중인 같은 음성을 다시 누르면 멈춘다.
  Future<void> toggle(String audio) async {
    if (playing == audio) return stop();
    final token = ++_token;
    await player.stop();
    final times = repeat ? repeatTimes : 1;
    for (var i = 1; i <= times; i++) {
      if (token != _token) return;
      playing = audio;
      round = i;
      _notify();
      try {
        await player.play(audio, speed: speed);
      } on Object catch (e) {
        debugPrint('재생 실패: $e');
        break;
      }
      if (token != _token) return;
      if (i < times) {
        // 들은 길이만큼 + 0.8초 동안 따라 말한다.
        final gap = repo.seconds(audio) / speed + 0.8;
        await Future<void>.delayed(
          Duration(milliseconds: (gap * 1000).round()),
        );
      }
    }
    if (token == _token) {
      playing = null;
      _notify();
    }
  }

  Future<void> stop() async {
    _token++;
    playing = null;
    await player.stop();
    _notify();
  }

  void setSlow(bool value) {
    slow = value;
    _notify();
  }

  void setRepeat(bool value) {
    repeat = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    unawaited(player.stop());
    super.dispose();
  }
}
