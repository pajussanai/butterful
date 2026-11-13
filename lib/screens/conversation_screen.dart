import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../conversation/conversation_controller.dart';
import '../data/models.dart';
import '../widgets/character_avatar.dart';

/// 대화 학습: 듣기 → 따라 말하기 → 대답 고르기 → 다음 대사
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.services,
    required this.lang,
    required this.scenarioId,
    required this.character,
    this.resumeChoices = const [],
  });

  final Services services;
  final String lang;
  final String scenarioId;
  final Character character;
  final List<String> resumeChoices;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late final ConversationController c = ConversationController(
    repo: widget.services.repo,
    progress: widget.services.progress,
    player: widget.services.newPlayer(),
    lang: widget.lang,
    scenarioId: widget.scenarioId,
    character: widget.character,
    resumeChoices: widget.resumeChoices,
  );
  final _scroll = ScrollController();
  int _lastLength = -1;

  @override
  void initState() {
    super.initState();
    // 대화를 열면 첫 대사를 바로 들려준다(막히면 듣기 버튼으로).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.listen();
    });
  }

  @override
  void dispose() {
    c.dispose();
    c.player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 대화가 이어지면 새 대사 카드의 위쪽이 보이도록 스크롤한다.
  void _scrollToCurrent() {
    if (_lastLength == c.history.length) return;
    _lastLength = c.history.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.history.isEmpty) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        return;
      }
      final ctx = _currentKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.02,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  final _currentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final repo = widget.services.repo;
    final info = repo.catalog.scenario(widget.scenarioId);
    final language = repo.catalog.language(widget.lang);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.title),
            Text(
              '${language.name} · ${widget.character.name}',
              style: const TextStyle(
                fontSize: 12.5,
                color: Palette.cocoa,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('restart'),
            tooltip: '처음부터 다시',
            onPressed: c.restart,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          _scrollToCurrent();
          // 지금 대사 카드로 스크롤할 수 있도록 전부 한 번에 그린다(대화 길이는 짧다).
          return SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            child: Centered(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in c.history) ...[
                    _PastLine(node: e.node, character: widget.character),
                    _MyLine(reply: e.reply),
                  ],
                  KeyedSubtree(
                    key: _currentKey,
                    child: _CurrentLine(c: c, language: language),
                  ),
                  const SizedBox(height: 18),
                  if (c.isEnd) _EndCard(c: c) else _Replies(c: c),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 지난 캐릭터 대사(작게)
class _PastLine extends StatelessWidget {
  const _PastLine({required this.node, required this.character});

  final DialogueNode node;
  final Character character;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 48),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CharacterAvatar(characterId: character.id, size: 28),
        const SizedBox(width: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Palette.surface,
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(18)
                  .copyWith(bottomLeft: const Radius.circular(4)),
            ),
            child: Text(
              node.text,
              style: const TextStyle(fontSize: 14.5, color: Palette.cocoa),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 내가 고른 대답(오른쪽)
class _MyLine extends StatelessWidget {
  const _MyLine({required this.reply});

  final Reply reply;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 64),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Palette.butterSoft,
          borderRadius: BorderRadius.circular(18)
              .copyWith(bottomRight: const Radius.circular(4)),
        ),
        child: Text(
          reply.text,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

/// 지금 대사: 원문·발음·번역과 듣기 조작
class _CurrentLine extends StatelessWidget {
  const _CurrentLine({required this.c, required this.language});

  final ConversationController c;
  final Language language;

  @override
  Widget build(BuildContext context) {
    final node = c.current;
    final busy =
        c.state == SpeakState.playing && c.playingGuide == null ||
        c.state == SpeakState.shadowing;
    return Container(
      key: const Key('currentLine'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: characterColor(c.character.id).withValues(alpha: 0.5),
          width: 1.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CharacterAvatar(
                characterId: c.character.id,
                size: 52,
                speaking:
                    c.state == SpeakState.playing && c.playingGuide == null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c.character.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Palette.toastSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            node.stage,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Palette.toast,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _status(c),
                      key: const Key('status'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Palette.cocoa,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (c.showText)
            Text(
              node.text,
              key: const Key('lineText'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            )
          else
            const Text(
              '원문을 숨겼어요. 소리에만 집중해 들어 보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Palette.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (c.showPron) ...[
            const SizedBox(height: 8),
            _Labeled(
              label: language.pronLabel,
              text: node.pron,
              color: Palette.sky,
              key: const Key('linePron'),
            ),
          ],
          if (c.showTrans) ...[
            const SizedBox(height: 6),
            _Labeled(
              label: language.transLabel,
              text: node.trans,
              color: Palette.sage,
              key: const Key('lineTrans'),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('listen'),
                // 글자가 바뀌어도 옆 버튼이 움직이지 않게 폭을 고정한다.
                style: FilledButton.styleFrom(
                  fixedSize: const Size(142, 46),
                  padding: EdgeInsets.zero,
                ),
                onPressed: busy ? c.stop : c.listen,
                icon: Icon(
                  busy
                      ? Icons.stop_rounded
                      : (c.state == SpeakState.idle
                            ? Icons.play_arrow_rounded
                            : Icons.replay_rounded),
                ),
                label: Text(
                  busy ? '멈춤' : (c.state == SpeakState.idle ? '듣기' : '다시 듣기'),
                ),
              ),
              SegmentedButton<bool>(
                key: const Key('speed'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Palette.butterSoft,
                  side: const BorderSide(color: Palette.line),
                ),
                segments: const [
                  ButtonSegment(value: true, label: Text('느리게 0.75×')),
                  ButtonSegment(value: false, label: Text('보통 1×')),
                ],
                selected: {c.slow},
                onSelectionChanged: (s) => c.setSlow(s.first),
              ),
              FilterChip(
                key: const Key('repeat'),
                avatar: const Icon(Icons.repeat_rounded, size: 18),
                label: Text('반복 ${c.repeatTimes}회'),
                selected: c.repeat,
                showCheckmark: false,
                onSelected: c.setRepeat,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              _Toggle(
                key: const Key('toggleText'),
                label: '원문',
                on: c.showText,
                onTap: c.toggleText,
              ),
              _Toggle(
                key: const Key('togglePron'),
                label: '발음',
                on: c.showPron,
                onTap: c.togglePron,
              ),
              _Toggle(
                key: const Key('toggleTrans'),
                label: '번역',
                on: c.showTrans,
                onTap: c.toggleTrans,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _status(ConversationController c) => switch (c.state) {
    SpeakState.idle => '듣기 버튼을 눌러 대사를 들어 보세요',
    SpeakState.playing when c.playingGuide != null => '내 대답을 듣는 중',
    SpeakState.playing =>
      c.repeat ? '듣는 중 (${c.round}/${c.repeatTimes})' : '듣는 중',
    SpeakState.shadowing => '이제 따라 말해 보세요 (${c.round}/${c.repeatTimes})',
    SpeakState.done => c.isEnd ? '소리 내어 따라 말해 보세요' : '소리 내어 따라 말한 뒤 대답을 골라 보세요',
  };
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    super.key,
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label  ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        TextSpan(
          text: text,
          style: const TextStyle(fontSize: 15, color: Palette.cocoa),
        ),
      ],
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: on,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
  );
}

/// 대답 고르기. 스피커 버튼으로 내 대답을 원어민 음성으로 먼저 들어 볼 수 있다.
class _Replies extends StatelessWidget {
  const _Replies({required this.c});

  final ConversationController c;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          '내 대답 고르기',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      for (final r in c.current.replies) ...[
        Panel(
          key: Key('reply-${r.id}'),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          onTap: () => c.choose(r),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.text,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (c.showPron)
                      Text(
                        r.pron,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Palette.sky,
                        ),
                      ),
                    if (c.showTrans)
                      Text(
                        r.trans,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Palette.sage,
                        ),
                      ),
                  ],
                ),
              ),
              if (c.repo.hasGuide(c.lang, c.scenarioId, r.id))
                IconButton(
                  key: Key('guide-${r.id}'),
                  tooltip: '내 대답 들어 보기',
                  onPressed: () =>
                      c.playingGuide == r.id ? c.stop() : c.listenGuide(r),
                  icon: Icon(
                    c.playingGuide == r.id
                        ? Icons.stop_circle_rounded
                        : Icons.volume_up_rounded,
                    color: Palette.toast,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _EndCard extends StatelessWidget {
  const _EndCard({required this.c});

  final ConversationController c;

  @override
  Widget build(BuildContext context) {
    final endings = c.scenario.nodes.values.where((n) => n.isEnd).length;
    final reached = c.progress.endings(c.lang, c.scenarioId).length;
    return Container(
      key: const Key('endCard'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.butter,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '대화를 끝까지 마쳤어요!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '대답을 ${c.history.length}번 했어요. 지금까지 만난 결말 $reached/$endings개.\n다른 대답을 고르면 다른 대화로 이어져요.',
            style: const TextStyle(height: 1.55),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('again'),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.ink,
                  foregroundColor: Palette.butter,
                ),
                onPressed: c.restart,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('다른 대답으로 다시'),
              ),
              OutlinedButton(
                key: const Key('backHome'),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('다른 상황 고르기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
