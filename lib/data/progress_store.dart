import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 고른 학습 언어와 대화 상대를 브라우저(기기) 저장소에 보관한다. 서버로 보내지 않는다.
///
/// 이어서 학습하기·최근 학습·진행률은 없앴다(다른 언어의 기록이 섞여 보이는 문제, 진행률 표시 금지).
/// 예전 버전이 같은 키에 남긴 학습 기록은 읽지 않으며, 다음 저장 때 이 형식으로 바뀐다.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs) {
    _read();
  }

  static const storageKey = 'butterful.progress.v1';

  final SharedPreferences _prefs;

  String? language;
  String? character;

  void _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      language = j['language'] as String?;
      character = j['character'] as String?;
    } on Object {
      // 저장 형식이 깨졌으면 처음부터 시작한다.
    }
  }

  Future<void> _write() async {
    notifyListeners();
    await _prefs.setString(
      storageKey,
      jsonEncode({'language': language, 'character': character}),
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
}
