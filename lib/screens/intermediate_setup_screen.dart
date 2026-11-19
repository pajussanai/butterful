import 'package:flutter/material.dart';

import '../ai/ai_models.dart';
import '../app/app.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/character_avatar.dart';
import 'intermediate_chat_screen.dart';

/// 중급 시작: 언어·캐릭터·주제(또는 직접 입력)를 고르고 AI와 대화를 시작한다.
class IntermediateSetupScreen extends StatefulWidget {
  const IntermediateSetupScreen({
    super.key,
    required this.services,
    required this.lang,
  });

  final Services services;
  final String lang;

  @override
  State<IntermediateSetupScreen> createState() =>
      _IntermediateSetupScreenState();
}

class _IntermediateSetupScreenState extends State<IntermediateSetupScreen> {
  late String _lang = widget.lang;
  late String _character;
  String _topic = topics.first.id;
  final _custom = TextEditingController();
  Set<String>? _voices;

  @override
  void initState() {
    super.initState();
    final ids = widget.services.repo.catalog.characters.map((c) => c.id);
    final saved = widget.services.progress.character;
    _character = ids.contains(saved) ? saved! : ids.first;
    if (widget.services.aiApi.configured) {
      widget.services.aiApi.voiceLanguages().then((v) {
        if (mounted) setState(() => _voices = v);
      });
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final s = widget.services;
    if (!s.aiConsent.accepted) {
      final ok = await showAiConsentDialog(context);
      if (ok != true || !mounted) return;
      await s.aiConsent.accept();
    }
    await s.progress.setCharacter(_character);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IntermediateChatScreen(
          services: s,
          lang: _lang,
          character: s.repo.catalog.character(_character),
          topic: _topic,
          customTopic: _custom.text.trim().isEmpty ? null : _custom.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.services.repo;
    final configured = widget.services.aiApi.configured;
    final languages = [
      for (final l in repo.catalog.languages)
        if (repo.isReady(l.code)) l,
    ];
    final character = repo.catalog.character(_character);
    return Scaffold(
      appBar: AppBar(title: const Text('중급 · AI 회화')),
      body: Centered(
        // 내용이 짧아 한 번에 그린다(캐릭터·주제가 모두 바로 보이도록).
        child: SingleChildScrollView(
          key: const Key('intermediateSetup'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  '정해진 대본 없이 내 문장으로 말해 보세요. 캐릭터가 대화를 이어 가고, '
                  '틀리거나 어색한 표현은 옆에서 자연스럽게 고쳐 줘요.',
                  style: TextStyle(color: Palette.cocoa, height: 1.55),
                ),
              ),
              if (!configured) const _NotConnected(),
              const SectionTitle('언어'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in languages)
                    ChoiceChip(
                      key: Key('aiLang-${l.code}'),
                      label: Text('${l.name} · ${l.variant}'),
                      selected: l.code == _lang,
                      onSelected: (_) => setState(() => _lang = l.code),
                    ),
                ],
              ),
              const SectionTitle('대화 상대'),
              for (final c in repo.catalog.characters) ...[
                _CharacterTile(
                  character: c,
                  lang: _lang,
                  selected: c.id == _character,
                  voiceReady: _voices?.contains(_lang),
                  onTap: () => setState(() => _character = c.id),
                ),
                const SizedBox(height: 8),
              ],
              const SectionTitle('대화 주제'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in topics)
                    ChoiceChip(
                      key: Key('topic-${t.id}'),
                      label: Text(t.label),
                      tooltip: t.english,
                      selected: t.id == _topic,
                      onSelected: (_) => setState(() => _topic = t.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('customTopic'),
                controller: _custom,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: '직접 주제 입력(선택)',
                  hintText: '예: 주말에 본 영화, 이번 여름 여행 계획',
                  filled: true,
                  fillColor: Palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '주제는 시작점일 뿐이에요. 대화 중에 다른 이야기로 넘어가거나 주제를 바꿔도 돼요.',
                style: TextStyle(fontSize: 12.5, color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('startAiConversation'),
                  onPressed: configured ? _start : null,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    configured
                        ? '${character.nameIn(_lang).withAnd} 대화 시작'
                        : 'AI 서버 연결 전이라 시작할 수 없어요',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('aiNotConnected'),
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Palette.toastSoft,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Text(
      '중급 AI 회화 서버가 아직 연결되지 않았어요. 연결이 끝나면 여기서 바로 대화를 시작할 수 있어요. '
      '그동안은 초급에서 연습해 주세요.',
      style: TextStyle(color: Palette.ink, height: 1.5),
    ),
  );
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.lang,
    required this.selected,
    required this.voiceReady,
    required this.onTap,
  });

  final Character character;
  final String lang;
  final bool selected;

  /// 이 언어의 AI 음성이 준비됐는지(모르면 null)
  final bool? voiceReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    key: Key('aiCharacter-${character.id}'),
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    borderColor: selected ? characterColor(character.id) : null,
    child: Row(
      children: [
        CharacterAvatar(characterId: character.id, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.nameIn(lang).label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${character.personality}. ${character.style}.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Palette.cocoa,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (voiceReady == false) const Tag('캐릭터 음성 준비 중'),
        if (selected)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.check_circle_rounded,
              color: characterColor(character.id),
            ),
          ),
      ],
    ),
  );
}

/// 처음 AI 회화를 시작할 때 데이터 처리 안내와 동의(사실대로 알린다).
Future<bool?> showAiConsentDialog(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    key: const Key('aiConsentDialog'),
    title: const Text('AI 회화를 시작하기 전에'),
    content: const SingleChildScrollView(
      child: Text(
        '· 마이크로 말한 음성과 대화 내용은 분석을 위해 Google Gemini API(무료 등급)로 보내져요.\n'
        '· 무료 등급에서는 Google이 보낸 내용을 서비스 개선에 쓸 수 있고, 사람이 검토할 수도 있어요. '
        '이름·연락처·주소 같은 개인 정보나 민감한 내용은 말하지 마세요.\n'
        '· 캐릭터 음성 서버가 준비되기 전에는 이 기기(브라우저)의 기본 목소리로 읽어요. '
        '브라우저에 따라 캐릭터가 할 말(글)이 브라우저 회사(Google 등) 서버로 보내질 수 있어요.\n'
        '· 버터풀은 내 음성과 대화를 저장하지 않아요. 대화는 이 화면을 나가면 사라져요.\n'
        '· Gemini API 약관에 따라 만 18세 이상만 이용할 수 있고, 유럽경제지역(EEA)·영국·스위스에서는 이용할 수 없어요.\n'
        '· 무료 사용량이 끝나면 대화가 잠시 멈추며, 요금은 청구되지 않아요.',
        style: TextStyle(height: 1.6),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('aiConsentCancel'),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('aiConsentAccept'),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('확인했어요(만 18세 이상)'),
      ),
    ],
  ),
);
