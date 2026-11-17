import 'package:butterful/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<Services> openApp(WidgetTester tester, {FakePlayer? player}) async {
    await phone(tester);
    final services = await makeServices(tester, player: player);
    await tester.pumpWidget(ButterfulApp(services: services));
    await tester.pumpAndSettle();
    return services;
  }

  Future<void> tapAndSettle(WidgetTester tester, String key) async {
    await tapKey(tester, key);
    await tester.pumpAndSettle();
  }

  testWidgets('언어 → 단계 → 초급 → 상황 → 캐릭터 → 대화(듣기, 속도, 모범 답변, 분기, 결말)', (
    tester,
  ) async {
    final player = FakePlayer();
    await openApp(tester, player: player);

    // 홈: 7개 언어를 고른다(이어서 학습하기·최근 학습은 없다).
    for (final code in ['en', 'en_gb', 'ja', 'ko', 'zh', 'fr', 'es']) {
      expect(find.byKey(Key('lang-$code')), findsOneWidget);
    }
    expect(find.text('준비 중'), findsNothing);
    expect(find.byKey(const Key('resumeCard')), findsNothing);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('최근 학습'), findsNothing);

    await tapAndSettle(tester, 'lang-en');
    for (final level in ['beginner', 'intermediate', 'advanced']) {
      expect(find.byKey(Key('level-$level')), findsOneWidget);
    }
    await tapAndSettle(tester, 'level-beginner');
    expect(find.byKey(const Key('wordCategory-greetings')), findsOneWidget);
    expect(find.textContaining('대사 '), findsNothing); // 진행률 표시 없음

    await tapAndSettle(tester, 'scenario-restaurant');
    for (final id in ['mia', 'leo', 'hana', 'theo', 'ellie']) {
      expect(find.byKey(Key('character-$id')), findsOneWidget);
    }
    expect(find.text('Emily · 에밀리'), findsOneWidget);
    await tapKey(tester, 'preview-theo');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$1, 'en/theo/restaurant__welcome.mp3');
    await tapKey(tester, 'character-hana');
    await tester.pump();
    expect(find.text('그레이스와 대화 시작'), findsOneWidget);
    await tapAndSettle(tester, 'startConversation');

    expect(
      find.text('Hi, welcome in! How many people are with you today?'),
      findsOneWidget,
    );
    expect(find.text('Grace'), findsWidgets);

    player.played.clear();
    await tapKey(tester, 'listen');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.single, ('en/hana/restaurant__welcome.mp3', 1.0));
    await tester.tap(find.text('느리게 0.75×'));
    await tester.pump();
    await tapKey(tester, 'listen');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$2, 0.75);

    await tapKey(tester, 'guide-welcome_3');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$1, 'en/guide/restaurant__welcome_3.mp3');

    await tapKey(tester, 'reply-welcome_3');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(player.played.last.$1, 'en/hana/restaurant__full_four.mp3');
    await tapKey(tester, 'reply-full_four_2');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('endCard')), findsOneWidget);
  });

  testWidgets('중급·고급도 언제든 고를 수 있고, 준비 중 안내에서 초급으로 갈 수 있다', (tester) async {
    await openApp(tester);
    await tapAndSettle(tester, 'lang-fr');
    for (final (level, label) in [('intermediate', '중급'), ('advanced', '고급')]) {
      await tapAndSettle(tester, 'level-$level');
      expect(find.text('$label 학습은 준비 중이에요'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tapAndSettle(tester, 'level-advanced');
    await tapAndSettle(tester, 'goBeginner');
    expect(find.byKey(const Key('wordCategory-greetings')), findsOneWidget);
  });

  testWidgets('초급 기초 단어: 단어·예문 듣기, 느리게, 3회 반복', (tester) async {
    final player = FakePlayer();
    await openApp(tester, player: player);
    await tapAndSettle(tester, 'lang-fr');
    await tapAndSettle(tester, 'level-beginner');
    await tapAndSettle(tester, 'wordCategory-greetings');
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('예문'), findsWidgets);

    await tapKey(tester, 'playWord-hello');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last, ('fr/words/greetings__hello.mp3', 1.0));
    await tapKey(tester, 'playExample-hello');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$1, 'fr/words/greetings__hello__ex.mp3');

    await tester.scrollUntilVisible(
      find.text('느리게 0.75×'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('느리게 0.75×'));
    await tapKey(tester, 'repeat');
    await tester.pump();
    player.played.clear();
    await tapKey(tester, 'playWord-thank_you');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(player.played, [
      for (var i = 0; i < 3; i++) ('fr/words/greetings__thank_you.mp3', 0.75),
    ]);
  });

  testWidgets('캐릭터 이름은 언어마다 현지 이름으로 보인다(ID·목소리는 그대로)', (tester) async {
    final services = await openApp(tester);
    const hana = {
      'ko': '서연',
      'en_gb': 'Imogen · 이모전',
      'ja': '美咲 · 미사키',
      'zh': '静怡 · 징이',
      'es': 'Carmen · 카르멘',
    };
    for (final MapEntry(key: lang, value: label) in hana.entries) {
      await tapAndSettle(tester, 'lang-$lang');
      await tapAndSettle(tester, 'level-beginner');
      await tapAndSettle(tester, 'scenario-restaurant');
      expect(find.text(label), findsOneWidget, reason: lang);
      expect(services.repo.voicedCharacters(lang), hasLength(5));
      for (var i = 0; i < 3; i++) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }
  });
}

/// 화면 밖에 있으면 먼저 스크롤해서 보이게 한 뒤 누른다.
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}
