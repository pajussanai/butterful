import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_models.dart';
import 'device_voice.dart';
import 'intermediate_api.dart';
import 'voice_io.dart';

/// 대화 한 줄
sealed class ChatLine {}

/// 캐릭터가 한 말
class CharacterLine extends ChatLine {
  CharacterLine(this.text, this.translation);

  final String text;
  final String translation;

  /// 만든 음성(다시 듣기용). 메모리에만 두고 화면을 나가면 사라진다.
  Uint8List? audio;
  bool audioFailed = false;
}

/// 사용자가 한 말과 교정
class UserLine extends ChatLine {
  UserLine({required this.result, required this.typed});

  final TurnResult result;

  /// 마이크 대신 입력한 문장인지
  final bool typed;
}

enum SessionStatus { starting, idle, listening, thinking, speaking, ended }

/// AI 응답을 무엇으로 읽는지
enum VoiceMode {
  /// 기존 엔진으로 만든 캐릭터 음성(서버)
  character,

  /// 캐릭터 음성 서버가 없어 기기(브라우저) 기본 음성으로 읽음
  device,

  /// 소리 없이 글로만
  none,
}

/// 중급 AI 회화 한 번의 상태. 대화 기록은 메모리에만 있고 어디에도 저장하지 않는다.
class IntermediateSession extends ChangeNotifier {
  IntermediateSession({
    required this.api,
    required this.recorder,
    required this.player,
    this.device,
    required this.lang,
    required this.character,
    required this._topic,
    this._customTopic,
    this.maxRecording = const Duration(seconds: 30),
  });

  final IntermediateApi api;
  final VoiceRecorder recorder;
  final SpeechPlayer player;

  /// 기기 기본 음성(없으면 캐릭터 음성 서버가 없을 때 글로만 대화)
  final DeviceVoice? device;
  final String lang;
  final String character;
  final Duration maxRecording;

  String _topic;
  String? _customTopic;
  String _summary = '';

  final lines = <ChatLine>[];
  SessionStatus status = SessionStatus.starting;

  /// AI 응답을 읽는 방법. 캐릭터 음성 서버가 있으면 캐릭터 음성, 없으면 기기 기본 음성, 둘 다 없으면 글로만.
  VoiceMode voiceMode = VoiceMode.none;

  bool get voiceAvailable => voiceMode != VoiceMode.none;
  bool _deviceOk = false;

  /// 화면 아래에 보여 줄 안내(오류 등). 보여 준 뒤 [clearNotice]로 지운다.
  String? notice;

  /// 오늘 무료 사용량이 끝나 더 진행할 수 없는지
  bool quotaExhausted = false;

  /// 지금 재생 중인 캐릭터 줄
  CharacterLine? speaking;

  /// 녹음 시간(초). 화면에 0:05처럼 보여 준다.
  int recordingSeconds = 0;
  Timer? _tick;
  Timer? _limit;
  bool _disposed = false;

  String get topic => _topic;
  String? get customTopic => _customTopic;

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void clearNotice() => notice = null;

  /// 서버가 쓸 수 있는 언어를 확인하고, 캐릭터의 첫마디를 받는다.
  Future<void> start() async {
    final voices = await api.voiceLanguages();
    _deviceOk = await device?.supports(lang) ?? false;
    _set(
      () => voiceMode = voices.contains(lang)
          ? VoiceMode.character
          : _deviceOk
          ? VoiceMode.device
          : VoiceMode.none,
    );
    await _turn(
      TurnRequest(
        lang: lang,
        character: character,
        topic: _topic,
        customTopic: _customTopic,
        opening: true,
      ),
    );
  }

  /// 주제를 바꾼다. 대화 맥락은 유지하고, 다음 턴부터 새 주제를 쓴다.
  void changeTopic(String topic, {String? custom}) {
    _set(() {
      _topic = topic;
      _customTopic = (custom ?? '').trim().isEmpty ? null : custom!.trim();
      notice =
          '주제를 바꿨어요: ${_customTopic ?? topicById(topic).label}. 새 주제로 말해 보세요.';
    });
  }

  /// 마이크 버튼: 듣고 있지 않으면 녹음을 시작하고, 듣고 있으면 멈춰서 보낸다.
  Future<void> toggleMic() async {
    if (status == SessionStatus.listening) return stopListening();
    if (status != SessionStatus.idle && status != SessionStatus.speaking) {
      return;
    }
    await _stopSpeaking();
    bool allowed;
    try {
      allowed = await recorder.requestPermission();
    } on Object {
      allowed = false;
    }
    if (!allowed) {
      _set(
        () => notice = '마이크를 쓸 수 없어요. 브라우저에서 마이크 권한을 허용하거나, 키보드 버튼으로 입력해 주세요.',
      );
      return;
    }
    try {
      await recorder.start();
    } on Object {
      _set(() => notice = '녹음을 시작하지 못했어요. 마이크 연결을 확인하거나 키보드로 입력해 주세요.');
      return;
    }
    _set(() {
      status = SessionStatus.listening;
      recordingSeconds = 0;
    });
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _set(() => recordingSeconds++),
    );
    _limit = Timer(maxRecording, stopListening);
  }

  Future<void> stopListening() async {
    if (status != SessionStatus.listening) return;
    _tick?.cancel();
    _limit?.cancel();
    _set(() => status = SessionStatus.thinking);
    Uint8List? audio;
    try {
      audio = await recorder.stop();
    } on Object {
      audio = null;
    }
    // WAV 머리(44바이트) + 16kHz·16비트로 0.4초(12,800바이트)보다 짧으면 말이 없었다고 본다.
    if (audio == null || audio.length < 44 + 12800) {
      _set(() {
        status = SessionStatus.idle;
        notice = '말소리가 거의 녹음되지 않았어요. 버튼을 누르고 말한 뒤 다시 눌러 주세요.';
      });
      return;
    }
    await _turn(_request(audio: audio));
  }

  /// 키보드로 입력한 문장 보내기(마이크를 못 쓸 때)
  Future<void> sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty ||
        (status != SessionStatus.idle && status != SessionStatus.speaking)) {
      return;
    }
    await _stopSpeaking();
    _set(() => status = SessionStatus.thinking);
    await _turn(_request(text: t));
  }

  TurnRequest _request({Uint8List? audio, String? text}) {
    final history = <(String, String)>[];
    for (final line in lines.reversed) {
      if (history.length >= 8) break;
      switch (line) {
        case CharacterLine(:final text):
          history.add(('character', text));
        case UserLine(:final result) when result.recognizedText.isNotEmpty:
          history.add(('user', result.recognizedText));
        case UserLine():
          break;
      }
    }
    return TurnRequest(
      lang: lang,
      character: character,
      topic: _topic,
      customTopic: _customTopic,
      summary: _summary,
      history: history.reversed.toList(),
      audio: audio,
      audioMime: audio == null ? null : 'audio/wav',
      text: text,
    );
  }

  Future<void> _turn(TurnRequest request) async {
    _set(
      () => status = request.opening
          ? SessionStatus.starting
          : SessionStatus.thinking,
    );
    TurnResult result;
    try {
      result = await api.turn(request);
    } on AiException catch (e) {
      _set(() {
        status = SessionStatus.idle;
        notice = e.error.message;
        if (e.error == AiError.quotaExceeded) quotaExhausted = true;
      });
      return;
    }
    if (_disposed || status == SessionStatus.ended) return;
    final line = CharacterLine(result.spoken, result.responseTranslation);
    _set(() {
      if (!request.opening) {
        lines.add(UserLine(result: result, typed: request.text != null));
      }
      lines.add(line);
      if (result.conversationSummary.isNotEmpty) {
        _summary = result.conversationSummary;
      }
      status = SessionStatus.idle;
    });
    // 글은 이미 보이고, 음성은 그 뒤에 만들어 재생한다(음성이 늦거나 실패해도 대화는 계속된다).
    await speak(line);
  }

  /// 캐릭터 줄을 소리 내어 읽는다(처음이면 음성을 만들고, 다시 듣기면 만들어 둔 음성을 쓴다).
  Future<void> speak(CharacterLine line) async {
    if (!voiceAvailable || _disposed || status == SessionStatus.ended) return;
    if (status == SessionStatus.listening || status == SessionStatus.thinking) {
      return;
    }
    await _stopSpeaking();
    _set(() {
      speaking = line;
      status = SessionStatus.speaking;
    });
    try {
      if (voiceMode == VoiceMode.device) {
        await device!.speak(lang, line.text);
        return;
      }
      line.audio ??= await api.speech(lang, character, line.text);
      if (speaking != line || _disposed) return;
      await player.playBytes(line.audio!);
    } on Object catch (e) {
      final error = e is AiException ? e.error : AiError.ttsFailed;
      _set(() {
        line.audioFailed = true;
        if (error == AiError.ttsUnavailable) {
          voiceMode = _deviceOk ? VoiceMode.device : VoiceMode.none;
        }
        notice = _deviceOk
            ? '캐릭터 음성을 만들지 못해 이 기기의 기본 목소리로 읽어요.'
            : error.message;
      });
      // 캐릭터 음성이 실패하면 기기 목소리로 대신 읽는다(글 대화는 그대로 이어진다).
      if (_deviceOk && speaking == line && !_disposed) {
        try {
          await device!.speak(lang, line.text);
        } on Object {
          // 기기 음성도 실패하면 글로만
        }
      }
    } finally {
      if (speaking == line) {
        _set(() {
          speaking = null;
          if (status == SessionStatus.speaking) status = SessionStatus.idle;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    if (speaking == null) return;
    speaking = null;
    try {
      await player.stop();
      await device?.stop();
    } on Object {
      // 이미 멈춘 경우
    }
    if (status == SessionStatus.speaking) status = SessionStatus.idle;
  }

  /// 대화 끝내기: 녹음·재생을 멈춘다. 대화 기록은 화면을 나가면 사라진다.
  Future<void> end() async {
    _tick?.cancel();
    _limit?.cancel();
    if (status == SessionStatus.listening) {
      try {
        await recorder.cancel();
      } on Object {
        // 무시
      }
    }
    await _stopSpeaking();
    _set(() => status = SessionStatus.ended);
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _limit?.cancel();
    unawaited(recorder.dispose());
    unawaited(player.dispose());
    super.dispose();
  }
}
