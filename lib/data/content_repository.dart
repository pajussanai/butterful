import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// 앱에 들어 있는 콘텐츠(JSON)와 미리 만든 음성 목록을 읽는다. 서버를 쓰지 않는다.
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  late Catalog catalog;

  /// 실제로 만들어 둔 음성 파일(assets/audio 기준 상대 경로)
  late Set<String> audioFiles;

  /// 음성 엔진 이름(manifest.json)
  late String engine;
  final Map<String, Scenario> _scenarios = {};
  final Map<String, WordBook> _words = {};
  Map<String, double> _seconds = {};

  /// 음성 길이(초). 따라 말할 시간을 정할 때 쓴다.
  double seconds(String audio) => _seconds[audio] ?? 2;

  Future<void> load() async {
    catalog = Catalog.fromJson(
      jsonDecode(await _bundle.loadString('assets/content/catalog.json'))
          as Map<String, dynamic>,
    );
    Future<Map<String, dynamic>> json(String path) async =>
        jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>;
    // 웹에서는 파일마다 내려받으므로 한꺼번에 요청한다(차례로 받으면 첫 화면이 늦게 뜬다).
    await Future.wait([
      json('assets/audio/manifest.json').then((manifest) {
        engine = manifest['engine'] as String;
        final files = manifest['files'] as Map<String, dynamic>;
        audioFiles = files.keys.toSet();
        _seconds = {
          for (final e in files.entries)
            e.key: ((e.value as Map<String, dynamic>)['sec'] as num).toDouble(),
        };
      }),
      for (final lang in catalog.languages) ...[
        for (final id in lang.content)
          json(
            'assets/content/${lang.code}/$id.json',
          ).then((j) => _scenarios['${lang.code}/$id'] = Scenario.fromJson(j)),
        if (lang.words)
          json('assets/content/${lang.code}/words.json')
              .then((j) => _words[lang.code] = WordBook.fromJson(j)),
      ],
    ]);
  }

  /// 초급 기초 단어(없는 언어는 빈 목록)
  WordBook words(String lang) => _words[lang] ?? WordBook(lang, const {});

  static String wordAudio(String lang, String category, String word) =>
      '$lang/words/${category}__$word.mp3';

  static String exampleAudio(String lang, String category, String word) =>
      '$lang/words/${category}__${word}__ex.mp3';

  Scenario scenario(String lang, String id) {
    final s = _scenarios['$lang/$id'];
    if (s == null) throw StateError('준비되지 않은 시나리오: $lang/$id');
    return s;
  }

  bool hasScenario(String lang, String id) =>
      _scenarios.containsKey('$lang/$id');

  static String npcAudio(
    String lang,
    String character,
    String scenario,
    String node,
  ) => '$lang/$character/${scenario}__$node.mp3';

  static String guideAudio(String lang, String scenario, String reply) =>
      '$lang/guide/${scenario}__$reply.mp3';

  /// 이 캐릭터 목소리로 이 언어의 모든 대사가 만들어져 있는지
  bool isVoiced(String lang, String character) {
    final language = catalog.language(lang);
    if (language.content.isEmpty) return false;
    for (final id in language.content) {
      final s = scenario(lang, id);
      for (final node in s.nodes.values) {
        if (!audioFiles.contains(npcAudio(lang, character, id, node.id))) {
          return false;
        }
      }
    }
    return true;
  }

  /// 모범 답변 음성이 있는지
  bool hasGuide(String lang, String scenario, String reply) =>
      audioFiles.contains(guideAudio(lang, scenario, reply));

  /// 대화와 음성이 모두 준비된 언어인지(준비 안 된 언어는 '준비 중'으로 보인다)
  bool isReady(String lang) =>
      catalog.characters.any((c) => isVoiced(lang, c.id));

  List<Character> voicedCharacters(String lang) => [
    for (final c in catalog.characters)
      if (isVoiced(lang, c.id)) c,
  ];
}
