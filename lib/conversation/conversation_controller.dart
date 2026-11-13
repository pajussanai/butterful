import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/voice_player.dart';
import '../data/content_repository.dart';
import '../data/models.dart';
import '../data/progress_store.dart';

/// 지나간 대화 한 줄(캐릭터 대사 + 내가 고른 대답)
class Exchange {
  const Exchange(this.node, this.reply);

  final DialogueNode node;
  final Reply reply;
}

enum SpeakState {
  /// 아직 듣지 않음(브라우저 자동 재생 제한 때문에 첫 재생은 버튼으로 시작한다)
  idle,

  /// 음성 재생 중
  playing,

  /// 반복 재생 사이, 따라 말할 시간
  shadowing,

  /// 다 듣고 대답을 기다림
  done,
}

/// 분기형 대화 진행과 음성 재생(다시 듣기, 반복, 속도)을 맡는다.
class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.repo,
    required this.progress,
    required this.player,
    required this.lang,
    required this.scenarioId,
    required this.character,
    List<String> resumeChoices = const [],
    this.repeatTimes = 3,
  }) : scenario = repo.scenario(lang, scenarioId) {
    _current = scenario.node(scenario.start);
    // 이어서 하기: 저장된 대답을 처음부터 따라가 같은 위치로 간다.
    for (final id in resumeChoices) {
      final reply = _current.replies.where((r) => r.id == id).firstOrNull;
      if (reply == null) break;
      history.add(Exchange(_current, reply));
      _current = scenario.node(reply.next);
    }
  }

  final ContentRepository repo;
  final ProgressStore progress;
  final VoicePlayer player;
  final String lang;
  final String scenarioId;
  final Character character;
  final Scenario scenario;

  /// 반복 재생을 켰을 때 듣는 횟수
  final int repeatTimes;

  final List<Exchange> history = [];
  late DialogueNode _current;
  DialogueNode get current => _current;

  SpeakState state = SpeakState.idle;

  /// 반복 재생 중 몇 번째인지(1부터)
  int round = 0;

  bool slow = false;
  bool repeat = false;
  bool showText = true;
  bool showPron = true;
  bool showTrans = true;

  /// 지금 재생 중인 모범 답변(대답 ID)
  String? playingGuide;

  int _token = 0;
  bool _disposed = false;

  double get speed => slow ? 0.75 : 1.0;
  List<String> get choices => [for (final e in history) e.reply.id];
  bool get isEnd => _current.isEnd;
  String get npcAudio =>
      ContentRepository.npcAudio(lang, character.id, scenarioId, _current.id);

  /// 지금 대사를 듣는다(반복이 켜져 있으면 따라 말할 틈을 두고 여러 번).
  Future<void> listen() async {
    final token = ++_token;
    playingGuide = null;
    await player.stop();
    await progress.record(
      lang: lang,
      scenario: scenarioId,
      character: character.id,
      choices: choices,
      nodeId: _current.id,
      isEnd: _current.isEnd,
    );
    final times = repeat ? repeatTimes : 1;
    for (var i = 1; i <= times; i++) {
      if (token != _token) return;
      round = i;
      _set(SpeakState.playing);
      try {
        await player.play(npcAudio, speed: speed);
      } on Object catch (e) {
        // 브라우저가 자동 재생을 막았거나 파일을 못 불러온 경우: 듣기 버튼으로 다시 시도
        debugPrint('재생 실패: $e');
        if (token == _token) _set(SpeakState.idle);
        return;
      }
      if (token != _token) return;
      if (i < times) {
        // 들은 길이만큼 + 1초 동안 따라 말한다.
        _set(SpeakState.shadowing);
        final gap = repo.seconds(npcAudio) / speed + 1;
        await Future<void>.delayed(
          Duration(milliseconds: (gap * 1000).round()),
        );
      }
    }
    if (token == _token) _set(SpeakState.done);
  }

  /// 내가 할 대답을 원어민 음성으로 들어 본다.
  Future<void> listenGuide(Reply reply) async {
    final token = ++_token;
    await player.stop();
    playingGuide = reply.id;
    _set(SpeakState.playing);
    try {
      await player.play(
        ContentRepository.guideAudio(lang, scenarioId, reply.id),
        speed: speed,
      );
    } on Object catch (e) {
      debugPrint('재생 실패: $e');
    }
    if (token != _token) return;
    playingGuide = null;
    _set(SpeakState.done);
  }

  /// 대답을 고르면 그 대답에 맞는 다음 대사로 가서 바로 들려준다.
  Future<void> choose(Reply reply) {
    history.add(Exchange(_current, reply));
    _current = scenario.node(reply.next);
    return listen();
  }

  /// 처음부터 다시
  Future<void> restart() {
    history.clear();
    _current = scenario.node(scenario.start);
    return listen();
  }

  Future<void> stop() async {
    _token++;
    playingGuide = null;
    await player.stop();
    _set(state == SpeakState.idle ? SpeakState.idle : SpeakState.done);
  }

  void setSlow(bool value) {
    slow = value;
    _notify();
  }

  void setRepeat(bool value) {
    repeat = value;
    _notify();
  }

  void toggleText() {
    showText = !showText;
    _notify();
  }

  void togglePron() {
    showPron = !showPron;
    _notify();
  }

  void toggleTrans() {
    showTrans = !showTrans;
    _notify();
  }

  void _set(SpeakState s) {
    state = s;
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
