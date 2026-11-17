import 'package:butterful/data/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('고른 언어와 대화 상대만 기기에 저장하고, 새로 열어도 유지된다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = ProgressStore(prefs);
    await a.setLanguage('fr');
    await a.setCharacter('hana');
    final b = ProgressStore(prefs);
    expect(b.language, 'fr');
    expect(b.character, 'hana');
  });

  test('예전 버전의 학습 기록(이어서 하기 등)이 남아 있어도 언어 선택은 그대로 읽는다', () async {
    SharedPreferences.setMockInitialValues({
      ProgressStore.storageKey: '{"language":"ja","character":"leo","sessions":{"ja/hotel":{}},"visited":{},"endings":{},"completions":{}}',
    });
    final store = ProgressStore(await SharedPreferences.getInstance());
    expect(store.language, 'ja');
    expect(store.character, 'leo');
  });
}
