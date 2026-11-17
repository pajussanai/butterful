import 'package:butterful/conversation/conversation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Future<(ConversationController, FakePlayer, Null)> make(
    WidgetTester tester, {
    String lang = 'en',
  }) async {
    final repo = await loadRepo(tester);
    final player = FakePlayer();
    final c = ConversationController(
      repo: repo,
      player: player,
      lang: lang,
      scenarioId: 'restaurant',
      character: repo.catalog.character('mia'),
    );
    return (c, player, null);
  }

  testWidgets('듣기: 지금 대사의 캐릭터 음성을 보통 속도로 한 번 재생한다', (tester) async {
    final (c, player, _) = await make(tester);
    expect(c.state, SpeakState.idle);
    final f = c.listen();
    await tester.pump(const Duration(milliseconds: 10));
    expect(c.state, SpeakState.playing);
    await tester.pump(const Duration(milliseconds: 400));
    await f;
    expect(player.played, [('en/mia/restaurant__welcome.mp3', 1.0)]);
    expect(c.state, SpeakState.done);
  });

  testWidgets('느리게: 0.75배 속도로 재생한다', (tester) async {
    final (c, player, _) = await make(tester);
    c.setSlow(true);
    final f = c.listen();
    await tester.pump(const Duration(milliseconds: 400));
    await f;
    expect(player.played.single.$2, 0.75);
  });

  testWidgets('반복: 따라 말할 틈을 두고 세 번 재생한다', (tester) async {
    final (c, player, _) = await make(tester);
    c.setRepeat(true);
    final f = c.listen();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.state, SpeakState.shadowing);
    expect(c.round, 1);
    // 음성 길이 + 1초 동안 따라 말하기
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    await f;
    expect(player.played, hasLength(3));
    expect(
      player.played.every((p) => p.$1 == 'en/mia/restaurant__welcome.mp3'),
      isTrue,
    );
    expect(c.state, SpeakState.done);
  });

  testWidgets('대답에 따라 다른 대사로 이어지고, 이어진 대사를 바로 들려준다', (tester) async {
    final (c, player, _) = await make(tester);
    final one = c.current.replies.firstWhere((r) => r.id == 'welcome_1');
    final f = c.choose(one);
    await tester.pump(const Duration(milliseconds: 400));
    await f;
    expect(c.current.id, 'seat_solo');
    expect(player.played.last.$1, 'en/mia/restaurant__seat_solo.mp3');

    final (c2, _, _) = await make(tester);
    final four = c2.current.replies.firstWhere((r) => r.id == 'welcome_3');
    final f2 = c2.choose(four);
    await tester.pump(const Duration(milliseconds: 400));
    await f2;
    expect(c2.current.id, 'full_four');
    expect(c2.current.text, isNot(c.current.text));
  });

  testWidgets('내 대답 들어 보기: 모범 답변 음성을 재생한다', (tester) async {
    final (c, player, _) = await make(tester, lang: 'ja');
    final r = c.current.replies.first;
    final f = c.listenGuide(r);
    await tester.pump(const Duration(milliseconds: 400));
    await f;
    expect(player.played.single.$1, 'ja/guide/restaurant__${r.id}.mp3');
  });

  testWidgets('대답을 고르면 그 대답의 분기로 이어지고, 결말에서 대화가 끝난다', (tester) async {
    final (c, _, _) = await make(tester);
    for (final id in ['welcome_3', 'full_four_2']) {
      final f = c.choose(c.current.replies.firstWhere((r) => r.id == id));
      await tester.pump(const Duration(milliseconds: 400));
      await f;
    }
    expect(c.isEnd, isTrue);
    expect(c.current.id, 'end_leave');
    expect(c.choices, ['welcome_3', 'full_four_2']);
  });
}
