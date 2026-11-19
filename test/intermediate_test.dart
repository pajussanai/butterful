import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:butterful/ai/ai_consent.dart';
import 'package:butterful/ai/ai_models.dart';
import 'package:butterful/ai/device_voice.dart';
import 'package:butterful/ai/intermediate_api.dart';
import 'package:butterful/ai/voice_io.dart';
import 'package:butterful/app/app.dart';
import 'package:butterful/data/progress_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_flow_test.dart' show tapKey;
import 'helpers.dart';

TurnResult result({
  String recognized = '',
  bool understandable = true,
  bool needed = false,
  String corrected = '',
  String natural = '',
  String why = '',
  String reply = 'Nice!',
  String question = 'What about you?',
  String translation = '좋네요! 당신은요?',
  String summary = '',
}) => TurnResult(
  recognizedText: recognized,
  isUnderstandable: understandable,
  correctionNeeded: needed,
  correctedText: corrected,
  naturalExpression: natural,
  correctionExplanation: why,
  characterResponse: reply,
  nextQuestion: question,
  responseTranslation: translation,
  conversationSummary: summary,
);

/// 서버 대신 정해 둔 결과를 돌려주고, 받은 요청을 기록한다.
class FakeApi implements IntermediateApi {
  FakeApi({
    this.configured = true,
    this.voices = const {'en', 'en_gb', 'ja', 'ko', 'fr', 'es'},
  });

  @override
  final bool configured;
  final Set<String> voices;
  final requests = <TurnRequest>[];
  final spoken = <(String, String, String)>[];
  final results = <Object>[]; // TurnResult 또는 AiException
  Object? speechError;

  @override
  Future<TurnResult> turn(TurnRequest request) async {
    requests.add(request);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final next = results.isEmpty
        ? result(reply: 'Hi!', question: 'How are you?')
        : results.removeAt(0);
    if (next is AiException) throw next;
    return next as TurnResult;
  }

  @override
  Future<Set<String>> voiceLanguages() async => voices;

  @override
  Future<Uint8List> speech(String lang, String character, String text) async {
    spoken.add((lang, character, text));
    if (speechError != null) throw speechError!;
    return Uint8List.fromList([1, 2, 3]);
  }
}

class FakeRecorder implements VoiceRecorder {
  bool allow = true;
  bool recording = false;
  Uint8List? audio = Uint8List(44 + 32000); // 1초 분량 WAV

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> start() async => recording = true;

  @override
  Future<Uint8List?> stop() async {
    recording = false;
    return audio;
  }

  @override
  Future<void> cancel() async => recording = false;

  @override
  Future<void> dispose() async {}
}

class FakeDevice implements DeviceVoice {
  FakeDevice(this.langs);

  final Set<String> langs;
  final spoken = <(String, String)>[];

  @override
  Future<bool> supports(String lang) async => langs.contains(lang);

  @override
  Future<void> speak(String lang, String text) async {
    spoken.add((lang, text));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> stop() async {}
}

class FakeSpeech implements SpeechPlayer {
  final played = <Uint8List>[];

  @override
  Future<void> playBytes(Uint8List mp3) async {
    played.add(mp3);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeApi api;
  late FakeRecorder recorder;
  late FakeSpeech speech;
  late FakeDevice device;

  Future<Services> open(
    WidgetTester tester, {
    FakeApi? fakeApi,
    String lang = 'en',
    Map<String, Object> prefs = const {},
    Set<String> deviceLangs = const {},
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api = fakeApi ?? FakeApi();
    recorder = FakeRecorder();
    speech = FakeSpeech();
    device = FakeDevice(deviceLangs);
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final services = Services(
      repo: await loadRepo(tester),
      progress: ProgressStore(p),
      playerFactory: FakePlayer.new,
      aiApi: api,
      recorderFactory: () => recorder,
      speechPlayerFactory: () => speech,
      aiConsent: AiConsent(p),
      deviceVoiceFactory: () => device,
    );
    await tester.pumpWidget(ButterfulApp(services: services));
    await tester.pumpAndSettle();
    await tapKey(tester, 'lang-$lang');
    await tester.pumpAndSettle();
    await tapKey(tester, 'level-intermediate');
    await tester.pumpAndSettle();
    return services;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tapKey(tester, key);
    await tester.pumpAndSettle();
  }

  Future<void> startChat(WidgetTester tester) async {
    await tap(tester, 'startAiConversation');
    expect(find.byKey(const Key('aiConsentDialog')), findsOneWidget);
    await tap(tester, 'aiConsentAccept');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('서버가 연결되지 않았으면 정직하게 알리고 시작하지 않는다', (tester) async {
    await open(tester, fakeApi: FakeApi(configured: false));
    expect(find.byKey(const Key('aiNotConnected')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('startAiConversation')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('설정: 7개 언어, 기존 캐릭터 5명(현지 이름), 9개 주제, 직접 입력', (tester) async {
    await open(tester, lang: 'es');
    for (final code in ['en', 'en_gb', 'ja', 'ko', 'zh', 'fr', 'es']) {
      expect(find.byKey(Key('aiLang-$code')), findsOneWidget);
    }
    for (final id in ['mia', 'leo', 'hana', 'theo', 'ellie']) {
      expect(find.byKey(Key('aiCharacter-$id')), findsOneWidget);
    }
    expect(find.text('Lucía · 루시아'), findsOneWidget);
    for (final t in topics) {
      expect(find.byKey(Key('topic-${t.id}')), findsOneWidget);
    }
    await tapKey(tester, 'aiLang-ja');
    await tester.pumpAndSettle();
    expect(find.text('結衣 · 유이'), findsOneWidget);
  });

  testWidgets('동의 → 첫마디(음성) → 말하기 → 교정과 응답 → 다시 듣기·번역 → 끝내기·새 대화', (
    tester,
  ) async {
    final fake = FakeApi()
      ..results.addAll([
        result(
          reply: 'Hi, I\'m Grace!',
          question: 'Where did you travel last?',
          translation: '안녕하세요, 저는 그레이스예요! 마지막으로 어디 여행했어요?',
        ),
        result(
          recognized: 'I go to Japan last year',
          needed: true,
          corrected: 'I went to Japan last year.',
          natural: 'I went to Japan last year.',
          why: '지난 일이라 과거형 went를 써요.',
          reply: 'Oh, Japan! Nice.',
          question: 'Which city did you like most?',
          summary: 'Visited Japan last year.',
        ),
      ]);
    final services = await open(tester, fakeApi: fake);
    await tapKey(tester, 'aiCharacter-hana');
    await tester.pump();
    await tapKey(tester, 'topic-travel');
    await tester.pump();
    await startChat(tester);

    expect(services.aiConsent.accepted, isTrue);
    expect(fake.requests.single.opening, isTrue);
    expect(fake.requests.single.topic, 'travel');
    expect(fake.requests.single.character, 'hana');
    expect(
      find.text("Hi, I'm Grace! Where did you travel last?"),
      findsOneWidget,
    );
    // 글이 먼저 보이고 그 뒤 캐릭터 목소리로 읽는다.
    expect(fake.spoken.single, (
      'en',
      'hana',
      "Hi, I'm Grace! Where did you travel last?",
    ));
    expect(speech.played, hasLength(1));

    // 말하기: 누르면 녹음, 다시 누르면 보낸다.
    await tap(tester, 'micButton');
    expect(recorder.recording, isTrue);
    expect(find.textContaining('듣고 있어요'), findsOneWidget);
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final sent = fake.requests.last;
    expect(sent.audio, isNotNull);
    expect(sent.audioMime, 'audio/wav');
    expect(sent.history.single.$1, 'character');

    expect(find.text('I go to Japan last year'), findsOneWidget); // 내가 말한 그대로
    expect(find.byKey(const Key('correction-1')), findsOneWidget);
    expect(find.text('I went to Japan last year.'), findsOneWidget);
    expect(find.text('지난 일이라 과거형 went를 써요.'), findsOneWidget);
    expect(
      find.text('Oh, Japan! Nice. Which city did you like most?'),
      findsOneWidget,
    );
    expect(speech.played, hasLength(2));

    // 다시 듣기는 만들어 둔 음성을 다시 쓴다(서버에 다시 요청하지 않음).
    await tapKey(tester, 'replay-2');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(fake.spoken, hasLength(2));
    expect(speech.played, hasLength(3));

    await tap(tester, 'translate-0');
    expect(find.text('안녕하세요, 저는 그레이스예요! 마지막으로 어디 여행했어요?'), findsOneWidget);

    // 교정 숨기기
    await tap(tester, 'toggleCorrections');
    expect(find.byKey(const Key('correction-1')), findsNothing);
    await tap(tester, 'toggleCorrections');

    // 다음 턴에는 요약을 함께 보낸다.
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(fake.requests.last.summary, 'Visited Japan last year.');

    await tap(tester, 'endConversation');
    await tap(tester, 'confirmEnd');
    expect(find.byKey(const Key('aiEndCard')), findsOneWidget);
    expect(find.byKey(const Key('micButton')), findsNothing);

    await tap(tester, 'aiRestart');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(fake.requests.last.opening, isTrue);
    expect(find.byKey(const Key('aiEndCard')), findsNothing);
  });

  testWidgets('맞는 문장은 고치지 않았다고 보여 준다', (tester) async {
    final fake = FakeApi()
      ..results.addAll([
        result(),
        result(recognized: 'I usually walk to work.'),
      ]);
    await open(tester, fakeApi: fake);
    await startChat(tester);
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('I usually walk to work.'), findsOneWidget);
    expect(find.byKey(const Key('correction-1')), findsNothing);
    expect(find.text('고칠 부분이 없어요'), findsOneWidget);
  });

  testWidgets('중국어처럼 음성 서버가 없는 언어는 글로 대화하고 음성을 요청하지 않는다', (tester) async {
    await open(tester, lang: 'zh');
    await startChat(tester);
    expect(find.byKey(const Key('aiVoiceBanner')), findsOneWidget);
    expect(api.spoken, isEmpty);
    expect(find.byKey(const Key('replay-0')), findsNothing);
  });

  testWidgets('마이크 권한이 없으면 안내하고 글자로 입력할 수 있다', (tester) async {
    final fake = FakeApi()
      ..results.addAll([result(), result(recognized: 'Hello there')]);
    await open(tester, fakeApi: fake);
    await startChat(tester);
    recorder.allow = false;
    await tap(tester, 'micButton');
    expect(find.textContaining('마이크를 쓸 수 없어요'), findsOneWidget);

    await tap(tester, 'aiUseKeyboard');
    await tester.enterText(find.byKey(const Key('aiTextInput')), 'Hello there');
    await tap(tester, 'aiSend');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(fake.requests.last.text, 'Hello there');
    expect(fake.requests.last.audio, isNull);
    expect(find.text('Hello there'), findsOneWidget);
  });

  testWidgets('너무 짧은 녹음은 보내지 않는다', (tester) async {
    await open(tester);
    await startChat(tester);
    recorder.audio = Uint8List(100);
    await tap(tester, 'micButton');
    await tap(tester, 'micButton');
    expect(api.requests, hasLength(1)); // 첫마디만
    expect(find.textContaining('거의 녹음되지 않았어요'), findsOneWidget);
  });

  testWidgets('무료 사용량이 끝나면 요금 없이 멈추고 마이크를 막는다', (tester) async {
    final fake = FakeApi()
      ..results.addAll([result(), const AiException(AiError.quotaExceeded)]);
    await open(tester, fakeApi: fake);
    await startChat(tester);
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('요금은 청구되지 않아요'), findsOneWidget);
    expect(find.text('오늘 무료 사용량이 끝났어요'), findsOneWidget);
    final mic = tester.widget<FilledButton>(find.byKey(const Key('micButton')));
    expect(mic.onPressed, isNull);
  });

  testWidgets('음성 생성에 실패해도 글 대화는 이어진다', (tester) async {
    final fake = FakeApi()
      ..speechError = const AiException(AiError.ttsFailed)
      ..results.addAll([result(), result(recognized: 'Fine, thanks')]);
    await open(tester, fakeApi: fake);
    await startChat(tester);
    expect(find.text('음성 없음'), findsOneWidget);
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Fine, thanks'), findsOneWidget);
  });

  testWidgets('AI 서버 오류는 안내하고 다시 말할 수 있다', (tester) async {
    final fake = FakeApi()
      ..results.addAll([
        result(),
        const AiException(AiError.aiUnavailable),
        result(recognized: 'Again'),
      ]);
    await open(tester, fakeApi: fake);
    await startChat(tester);
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI가 지금 응답하지 않아요'), findsOneWidget);
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Again'), findsOneWidget);
  });

  testWidgets('대화 중 주제를 바꾸면 다음 턴부터 새 주제를 보낸다', (tester) async {
    await open(tester);
    await startChat(tester);
    await tap(tester, 'changeTopic');
    await tap(tester, 'newTopic-hobbies');
    await tap(tester, 'applyTopic');
    await tap(tester, 'micButton');
    await tapKey(tester, 'micButton');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(api.requests.last.topic, 'hobbies');
  });

  testWidgets('동의는 따로 저장하고 기존 학습 설정은 건드리지 않는다', (tester) async {
    const progress = '{"language":"en","character":"leo"}';
    await open(tester, prefs: {'butterful.progress.v1': progress});
    await startChat(tester);
    final p = await SharedPreferences.getInstance();
    expect(p.getString(AiConsent.storageKey), AiConsent.version);
    expect(jsonDecode(p.getString('butterful.progress.v1')!)['language'], 'en');
  });

  testWidgets('캐릭터 음성 서버가 없으면 기기 기본 목소리로 읽고, 캐릭터 목소리가 아니라고 알린다', (
    tester,
  ) async {
    final fake = FakeApi(voices: const {})
      ..results.addAll([result(reply: '你好！', question: '你周末做什么？')]);
    await open(tester, fakeApi: fake, lang: 'zh', deviceLangs: {'zh'});
    await startChat(tester);
    expect(fake.spoken, isEmpty); // 캐릭터 음성 서버는 부르지 않는다
    expect(device.spoken.single, ('zh', '你好！ 你周末做什么？'));
    expect(find.textContaining('캐릭터 목소리가 아니에요'), findsOneWidget);
    await tapKey(tester, 'replay-0');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(device.spoken, hasLength(2));
  });

  testWidgets('기기에 그 언어 목소리가 없으면 글로만 대화한다(영국 영어를 미국 목소리로 대신하지 않음)', (
    tester,
  ) async {
    await open(
      tester,
      fakeApi: FakeApi(voices: const {}),
      lang: 'en_gb',
      deviceLangs: {'en'},
    );
    await startChat(tester);
    expect(device.spoken, isEmpty);
    expect(find.textContaining('글로 대화해요'), findsOneWidget);
    expect(find.byKey(const Key('replay-0')), findsNothing);
  });

  testWidgets('캐릭터 음성 생성이 실패하면 기기 목소리로 대신 읽는다', (tester) async {
    final fake = FakeApi()..speechError = const AiException(AiError.ttsFailed);
    await open(tester, fakeApi: fake, deviceLangs: {'en'});
    await startChat(tester);
    expect(fake.spoken, hasLength(1));
    expect(device.spoken, hasLength(1));
    expect(find.textContaining('기본 목소리로 읽어요'), findsOneWidget);
  });

  test('Edge Function의 캐릭터 설정 복사본이 catalog.json과 같다(python tool/ai/sync_characters.py)', () {
    final catalog = jsonDecode(
      File('assets/content/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final copy = jsonDecode(
      File('supabase/functions/_shared/characters.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final chars = copy['characters'] as Map<String, dynamic>;
    for (final c in catalog['characters'] as List) {
      final m = c as Map<String, dynamic>;
      final d = chars[m['id']] as Map<String, dynamic>;
      expect(d['names'], m['names']);
      expect(d['personality'], m['personality']);
      expect(d['style'], m['style']);
    }
    expect(chars.length, (catalog['characters'] as List).length);
    expect((copy['languages'] as Map).keys.toSet(), {
      for (final l in catalog['languages'] as List) (l as Map)['code'],
    });
  });

  test('응답 JSON의 일부 항목이 빠지거나 형식이 달라도 안전한 기본값을 쓴다', () {
    final r = TurnResult.fromJson({
      'character_response': 'Hi',
      'correction_needed': 'yes',
    });
    expect(r.correctionNeeded, isFalse);
    expect(r.isUnderstandable, isTrue);
    expect(r.spoken, 'Hi');
    expect(r.hasFeedback, isFalse);
  });
}
