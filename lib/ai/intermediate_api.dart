import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_models.dart';

/// 중급 AI 회화 서버(BUTTERFUL 전용 Supabase 프로젝트의 Edge Functions) 주소. 공개 주소이며 비밀값이 아니다.
/// 다른 서버로 시험할 때만 빌드 옵션으로 바꾼다: --dart-define=AI_API_BASE=...
/// 비어 있으면 앱은 "AI 서버가 아직 연결되지 않았어요"를 보여 주고 대화를 시작하지 않는다.
const aiApiBase = String.fromEnvironment(
  'AI_API_BASE',
  defaultValue: 'https://rtnmjulqeuoccatlrhzb.supabase.co/functions/v1',
);

/// 앱이 아는 것은 이 인터페이스뿐이다(Gemini·TTS 엔진은 서버 뒤에 숨어 있다).
abstract class IntermediateApi {
  /// 서버 주소가 설정되어 있는지
  bool get configured;

  Future<TurnResult> turn(TurnRequest request);

  /// 캐릭터 음성을 만들 수 있는 언어
  Future<Set<String>> voiceLanguages();

  /// 캐릭터 음성(MP3)
  Future<Uint8List> speech(String lang, String character, String text);
}

class HttpIntermediateApi implements IntermediateApi {
  HttpIntermediateApi({String base = aiApiBase, http.Client? client})
    : _base = base.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _base;
  final http.Client _client;
  Future<Set<String>>? _voices;

  @override
  bool get configured => _base.isNotEmpty;

  Never _fail(http.Response res) {
    String? code;
    try {
      code = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String?;
    } on Object {
      code = null;
    }
    throw AiException(AiError.fromCode(code));
  }

  Future<http.Response> _send(
    Future<http.Response> Function() call,
    Duration timeout,
  ) async {
    if (!configured) throw const AiException(AiError.notConfigured);
    try {
      return await call().timeout(timeout);
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(AiError.aiUnavailable);
    } on Object {
      throw const AiException(AiError.network);
    }
  }

  @override
  Future<TurnResult> turn(TurnRequest r) async {
    final body = <String, Object?>{
      'lang': r.lang,
      'character': r.character,
      'topic': r.topic,
      if (r.customTopic != null && r.customTopic!.isNotEmpty)
        'custom_topic': r.customTopic,
      if (r.summary != null && r.summary!.isNotEmpty) 'summary': r.summary,
      'history': [
        for (final (role, text) in r.history) {'role': role, 'text': text},
      ],
      'opening': r.opening,
      if (r.audio != null) 'audio_base64': base64Encode(r.audio!),
      if (r.audio != null) 'audio_mime': r.audioMime ?? 'audio/wav',
      if (r.text != null) 'text': r.text,
    };
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/intermediate-turn'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      const Duration(seconds: 70),
    );
    if (res.statusCode != 200) _fail(res);
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final result = TurnResult.fromJson(j['result'] as Map<String, dynamic>);
      if (result.spoken.isEmpty) throw const AiException(AiError.aiBadOutput);
      return result;
    } on AiException {
      rethrow;
    } on Object {
      throw const AiException(AiError.aiBadOutput);
    }
  }

  @override
  Future<Set<String>> voiceLanguages() => _voices ??= () async {
    try {
      final res = await _send(
        () => _client.get(Uri.parse('$_base/tts')),
        const Duration(seconds: 15),
      );
      if (res.statusCode != 200) return <String>{};
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return {for (final l in j['languages'] as List) l as String};
    } on Object {
      _voices = null; // 다음에 다시 묻는다
      return <String>{};
    }
  }();

  @override
  Future<Uint8List> speech(String lang, String character, String text) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/tts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language': lang,
          'character_id': character,
          'text': text,
        }),
      ),
      // 무료 음성 서버가 잠들어 있으면 깨어나는 데 시간이 걸린다.
      const Duration(seconds: 60),
    );
    if (res.statusCode != 200) _fail(res);
    return res.bodyBytes;
  }
}
