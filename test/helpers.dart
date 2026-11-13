import 'package:butterful/app/app.dart';
import 'package:butterful/audio/voice_player.dart';
import 'package:butterful/data/content_repository.dart';
import 'package:butterful/data/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 실제 소리 대신 무엇을 어떤 속도로 재생했는지 기록한다.
class FakePlayer implements VoicePlayer {
  final played = <(String, double)>[];
  int stops = 0;

  @override
  Future<void> play(String audio, {double speed = 1}) async {
    played.add((audio, speed));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}

/// 실제 앱 자산(콘텐츠·음성 목록)을 읽은 저장소
Future<ContentRepository> loadRepo(WidgetTester tester) async {
  final repo = ContentRepository();
  await tester.runAsync(repo.load);
  return repo;
}

Future<Services> makeServices(
  WidgetTester tester, {
  FakePlayer? player,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final repo = await loadRepo(tester);
  final fake = player ?? FakePlayer();
  return Services(
    repo: repo,
    progress: ProgressStore(p),
    playerFactory: () => fake,
  );
}
