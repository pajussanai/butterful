import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 중급 AI 회화 데이터 안내에 동의했는지(기기에만 저장). 안내 내용이 바뀌면 [version]을 올려 다시 묻는다.
/// 기존 학습 설정(butterful.progress.v1)과는 다른 키를 쓰고, 그 값을 건드리지 않는다.
class AiConsent extends ChangeNotifier {
  AiConsent([this._prefs])
    : _accepted = _prefs?.getString(storageKey) == version;

  static const storageKey = 'butterful.ai_consent';
  static const version = '2026-11-19';

  final SharedPreferences? _prefs;
  bool _accepted;

  bool get accepted => _accepted;

  Future<void> accept() async {
    _accepted = true;
    notifyListeners();
    await _prefs?.setString(storageKey, version);
  }
}
