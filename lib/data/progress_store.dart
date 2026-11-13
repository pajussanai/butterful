import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 진행 중이거나 마친 대화 하나(같은 언어·시나리오는 하나만 남긴다)
class Session {
  const Session({
    required this.lang,
    required this.scenario,
    required this.character,
    required this.choices,
    required this.updatedAt,
    required this.done,
  });

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    lang: j['lang'] as String,
    scenario: j['scenario'] as String,
    character: j['character'] as String,
    choices: List<String>.from(j['choices'] as List),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    done: j['done'] as bool,
  );

  final String lang;
  final String scenario;
  final String character;

  /// 지금까지 고른 대답 ID(처음부터 다시 따라가면 같은 위치가 된다)
  final List<String> choices;
  final DateTime updatedAt;
  final bool done;

  String get key => '$lang/$scenario';

  Map<String, dynamic> toJson() => {
    'lang': lang,
    'scenario': scenario,
    'character': character,
    'choices': choices,
    'updatedAt': updatedAt.toIso8601String(),
    'done': done,
  };
}

/// 학습 기록을 브라우저(기기) 저장소에 보관한다. 서버로 보내지 않는다.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _read();
  }

  static const storageKey = 'butterful.progress.v1';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  String? language;
  String? character;
  final Map<String, Session> _sessions = {};
  final Map<String, Set<String>> _visited = {};
  final Map<String, Set<String>> _endings = {};
  final Map<String, int> _completions = {};

  void _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      language = j['language'] as String?;
      character = j['character'] as String?;
      for (final s in (j['sessions'] as Map<String, dynamic>? ?? {}).values) {
        final session = Session.fromJson(s as Map<String, dynamic>);
        _sessions[session.key] = session;
      }
      (j['visited'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => _visited[k] = Set<String>.from(v as List),
      );
      (j['endings'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => _endings[k] = Set<String>.from(v as List),
      );
      (j['completions'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => _completions[k] = v as int,
      );
    } on Object {
      // 저장 형식이 깨졌으면 처음부터 시작한다.
      _sessions.clear();
      _visited.clear();
      _endings.clear();
      _completions.clear();
    }
  }

  Future<void> _write() async {
    notifyListeners();
    await _prefs.setString(
      storageKey,
      jsonEncode({
        'language': language,
        'character': character,
        'sessions': {for (final s in _sessions.values) s.key: s.toJson()},
        'visited': _visited.map((k, v) => MapEntry(k, v.toList())),
        'endings': _endings.map((k, v) => MapEntry(k, v.toList())),
        'completions': _completions,
      }),
    );
  }

  Future<void> setLanguage(String code) {
    language = code;
    return _write();
  }

  Future<void> setCharacter(String id) {
    character = id;
    return _write();
  }

  Session? session(String lang, String scenario) =>
      _sessions['$lang/$scenario'];

  /// 최근 학습 기록(최신순)
  List<Session> get recent {
    final list = _sessions.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 이어서 할 대화(가장 최근에 하다 만 대화)
  Session? get resumable {
    for (final s in recent) {
      if (!s.done) return s;
    }
    return null;
  }

  /// 들어 본 대사 ID
  Set<String> visited(String lang, String scenario) =>
      _visited['$lang/$scenario'] ?? const {};

  /// 도달한 결말 대사 ID
  Set<String> endings(String lang, String scenario) =>
      _endings['$lang/$scenario'] ?? const {};

  int completions(String lang, String scenario) =>
      _completions['$lang/$scenario'] ?? 0;

  /// 대사 하나를 들을 때마다 기록한다(새로고침해도 이 위치에서 이어진다).
  Future<void> record({
    required String lang,
    required String scenario,
    required String character,
    required List<String> choices,
    required String nodeId,
    required bool isEnd,
  }) {
    final key = '$lang/$scenario';
    _sessions[key] = Session(
      lang: lang,
      scenario: scenario,
      character: character,
      choices: List.unmodifiable(choices),
      updatedAt: _clock(),
      done: isEnd,
    );
    (_visited[key] ??= {}).add(nodeId);
    if (isEnd) {
      (_endings[key] ??= {}).add(nodeId);
      _completions[key] = (_completions[key] ?? 0) + 1;
    }
    return _write();
  }

  /// 학습 기록 지우기(언어·캐릭터 선택은 남긴다)
  Future<void> clearHistory() {
    _sessions.clear();
    _visited.clear();
    _endings.clear();
    _completions.clear();
    return _write();
  }
}
