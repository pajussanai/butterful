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

  testWidgets('홈 → 상황 → 캐릭터 → 대화: 듣기, 대답 고르기, 분기, 결말까지', (tester) async {
    await phone(tester);
    final player = FakePlayer();
    final services = await makeServices(tester, player: player);
    await tester.pumpWidget(ButterfulApp(services: services));
    await tester.pumpAndSettle();

    // 처음에는 준비된 첫 언어(영어)
    expect(find.text('BUTTERFUL'), findsOneWidget);
    expect(find.text('영어 · English'), findsOneWidget);

    await tapKey(tester, 'scenario-restaurant');
    await tester.pumpAndSettle();
    // 캐릭터 다섯 명, 목소리 미리 듣기
    for (final id in ['mia', 'leo', 'hana', 'theo', 'ellie']) {
      expect(find.byKey(Key('character-$id')), findsOneWidget);
    }
    await tapKey(tester, 'preview-theo');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$1, 'en/theo/restaurant__welcome.mp3');
    await tapKey(tester, 'character-hana');
    await tester.pump();
    expect(find.text('Hana와 대화 시작'), findsOneWidget);
    await tapKey(tester, 'startConversation');
    await tester.pumpAndSettle();

    // 첫 대사: 원문·발음·번역
    expect(
      find.text('Hi, welcome in! How many people are with you today?'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('linePron')), findsOneWidget);
    expect(find.byKey(const Key('lineTrans')), findsOneWidget);

    // 원문 숨기기/보이기
    await tapKey(tester, 'toggleText');
    await tester.pump();
    expect(find.byKey(const Key('lineText')), findsNothing);
    await tapKey(tester, 'toggleText');
    await tester.pump();
    expect(find.byKey(const Key('lineText')), findsOneWidget);

    // 듣기(사용자가 눌러야 재생 시작)
    player.played.clear();
    await tapKey(tester, 'listen');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('듣는 중'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.single, ('en/hana/restaurant__welcome.mp3', 1.0));
    expect(find.text('소리 내어 따라 말한 뒤 대답을 골라 보세요'), findsOneWidget);

    // 느리게로 다시 듣기
    await tester.tap(find.text('느리게 0.75×'));
    await tester.pump();
    await tapKey(tester, 'listen');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$2, 0.75);

    // 내 대답 들어 보기
    await tapKey(tester, 'guide-welcome_3');
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.played.last.$1, 'en/guide/restaurant__welcome_3.mp3');

    // 네 명 → 만석 분기 → 다음에 오기 → 결말
    await tapKey(tester, 'reply-welcome_3');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('ten-minute wait'), findsOneWidget);
    expect(player.played.last.$1, 'en/hana/restaurant__full_four.mp3');
    await tapKey(tester, 'reply-full_four_2');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('endCard')), findsOneWidget);

    // 다시 하면 다른 분기(혼자 → 자리 고르기)
    await tapKey(tester, 'again');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tapKey(tester, 'reply-welcome_1');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('table by the window'), findsOneWidget);

    // 홈으로 돌아가면 이어서 하기와 최근 학습이 보인다.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resumeCard')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('진행 중'), 300);
    expect(find.text('진행 중'), findsOneWidget);
  });

  testWidgets('언어 선택: 7개 언어가 모두 준비되어 있고, 언어마다 캐릭터 다섯 명을 고를 수 있다', (
    tester,
  ) async {
    await phone(tester);
    final services = await makeServices(tester);
    await tester.pumpWidget(ButterfulApp(services: services));
    await tester.pumpAndSettle();
    await tapKey(tester, 'languageCard');
    await tester.pumpAndSettle();
    for (final code in ['en', 'en_gb', 'ja', 'ko', 'zh', 'fr', 'es']) {
      expect(find.byKey(Key('lang-$code')), findsOneWidget);
    }
    expect(find.text('준비 중'), findsNothing);
    await tapKey(tester, 'lang-ja');
    await tester.pumpAndSettle();
    expect(find.text('일본어 · 日本語'), findsOneWidget);
    expect(services.progress.language, 'ja');

    for (final (code, title) in [
      ('en_gb', '영어 · English'),
      ('zh', '중국어 · 中文'),
      ('fr', '프랑스어 · Français'),
      ('es', '스페인어 · Español'),
    ]) {
      // 홈이 아래로 스크롤돼 있으면 맨 위의 언어 카드가 아직 그려지지 않았다.
      await tester.scrollUntilVisible(
        find.byKey(const Key('languageCard')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, 'languageCard');
      await tester.pumpAndSettle();
      await tapKey(tester, 'lang-$code');
      await tester.pumpAndSettle();
      expect(services.progress.language, code);
      expect(find.text(title), findsOneWidget);
      await tapKey(tester, 'scenario-restaurant');
      await tester.pumpAndSettle();
      for (final id in ['mia', 'leo', 'hana', 'theo', 'ellie']) {
        expect(
          find.byKey(Key('character-$id')),
          findsOneWidget,
          reason: '$code/$id',
        );
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('새로고침 뒤 이어서 하기: 저장된 위치에서 다시 시작한다', (tester) async {
    await phone(tester);
    final services = await makeServices(tester);
    await services.progress.setLanguage('ko');
    await services.progress.record(
      lang: 'ko',
      scenario: 'hotel',
      character: 'leo',
      choices: ['greet_2', 'walkin_2'],
      nodeId: 'breakfast_q',
      isEnd: false,
    );
    await tester.pumpWidget(ButterfulApp(services: services));
    await tester.pumpAndSettle();
    await tapKey(tester, 'resumeCard');
    await tester.pumpAndSettle();
    expect(find.text('네, 조식 포함이고요. 아침 일곱 시부터 열 시까지 드실 수 있어요.'), findsOneWidget);
    expect(find.text('Leo'), findsWidgets);
  });
}

/// 화면 밖에 있으면 먼저 스크롤해서 보이게 한 뒤 누른다.
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}
