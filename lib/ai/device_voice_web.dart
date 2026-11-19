import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'device_voice.dart';

DeviceVoice create() => _WebDeviceVoice();

/// 브라우저 Web Speech API(speechSynthesis)로 읽는다.
class _WebDeviceVoice implements DeviceVoice {
  Completer<void>? _current;

  web.SpeechSynthesis? get _synth {
    try {
      return web.window.speechSynthesis;
    } on Object {
      return null; // 지원하지 않는 브라우저
    }
  }

  /// 목소리 목록(브라우저가 처음에는 빈 목록을 줄 수 있어 잠시 기다린다)
  Future<List<web.SpeechSynthesisVoice>> _voices() async {
    final synth = _synth;
    if (synth == null) return const [];
    for (var i = 0; i < 15; i++) {
      final list = synth.getVoices().toDart;
      if (list.isNotEmpty) return list;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return synth.getVoices().toDart;
  }

  Future<web.SpeechSynthesisVoice?> _pick(String lang) async {
    final tag = deviceLocales[lang];
    if (tag == null) return null;
    final voices = await _voices();
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    final exact = voices
        .where((v) => norm(v.lang) == tag.toLowerCase())
        .toList();
    if (exact.isNotEmpty) {
      // 기기에 내장된 목소리를 먼저 쓴다(문장을 밖으로 보내지 않음).
      return exact.firstWhere((v) => v.localService, orElse: () => exact.first);
    }
    if (strictLocales.contains(lang)) return null;
    final prefix = tag.split('-').first.toLowerCase();
    final same = voices
        .where(
          (v) => norm(v.lang).startsWith('$prefix-') || norm(v.lang) == prefix,
        )
        .toList();
    return same.isEmpty
        ? null
        : same.firstWhere((v) => v.localService, orElse: () => same.first);
  }

  @override
  Future<bool> supports(String lang) async => await _pick(lang) != null;

  @override
  Future<void> speak(String lang, String text) async {
    final synth = _synth;
    final voice = await _pick(lang);
    if (synth == null || voice == null) return;
    await stop();
    final done = Completer<void>();
    _current = done;
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = voice.lang
      ..voice = voice
      ..rate = 0.95;
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    u.onend = ((web.Event _) => finish()).toJS;
    u.onerror = ((web.Event _) => finish()).toJS;
    synth.speak(u);
    // 브라우저가 끝 알림을 주지 않는 경우를 대비한 상한
    await done.future.timeout(
      Duration(seconds: 8 + text.length ~/ 6),
      onTimeout: () {},
    );
  }

  @override
  Future<void> stop() async {
    _synth?.cancel();
    final c = _current;
    if (c != null && !c.isCompleted) c.complete();
    _current = null;
  }
}
