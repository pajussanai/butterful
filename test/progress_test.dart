import 'package:butterful/data/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('언어·캐릭터·진행 기록이 저장소에 남아 다시 열어도 유지된다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var t = DateTime.utc(2026, 11, 13, 9);
    final a = ProgressStore(prefs, clock: () => t);
    await a.setLanguage('ja');
    await a.setCharacter('leo');
    await a.record(
      lang: 'ja',
      scenario: 'hotel',
      character: 'leo',
      choices: [],
      nodeId: 'greet',
      isEnd: false,
    );
    t = t.add(const Duration(minutes: 1));
    await a.record(
      lang: 'ja',
      scenario: 'hotel',
      character: 'leo',
      choices: ['greet_1'],
      nodeId: 'name',
      isEnd: false,
    );
    t = t.add(const Duration(minutes: 1));
    await a.record(
      lang: 'en',
      scenario: 'restaurant',
      character: 'mia',
      choices: ['welcome_3', 'full_four_2'],
      nodeId: 'end_leave',
      isEnd: true,
    );

    // 새로고침과 같음: 같은 저장소로 새로 만든다.
    final b = ProgressStore(prefs);
    expect(b.language, 'ja');
    expect(b.character, 'leo');
    expect(b.visited('ja', 'hotel'), {'greet', 'name'});
    expect(b.session('ja', 'hotel')!.choices, ['greet_1']);
    expect(b.resumable!.key, 'ja/hotel');
    expect(b.recent.map((s) => s.key), ['en/restaurant', 'ja/hotel']);
    expect(b.completions('en', 'restaurant'), 1);
    expect(b.endings('en', 'restaurant'), {'end_leave'});

    await b.clearHistory();
    final c = ProgressStore(prefs);
    expect(c.recent, isEmpty);
    expect(c.language, 'ja');
  });

  test('저장 형식이 깨져 있어도 앱이 멈추지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      ProgressStore.storageKey: '{"sessions": 3',
    });
    final prefs = await SharedPreferences.getInstance();
    final s = ProgressStore(prefs);
    expect(s.recent, isEmpty);
  });
}
