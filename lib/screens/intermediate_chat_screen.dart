import 'package:flutter/material.dart';

import '../ai/ai_models.dart';
import '../ai/intermediate_session.dart';
import '../app/app.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/character_avatar.dart';

/// 중급 AI 회화: 캐릭터의 말을 듣고 내 문장으로 말하면, AI가 알아듣고 교정하며 대화를 이어 간다.
class IntermediateChatScreen extends StatefulWidget {
  const IntermediateChatScreen({
    super.key,
    required this.services,
    required this.lang,
    required this.character,
    required this.topic,
    this.customTopic,
  });

  final Services services;
  final String lang;
  final Character character;
  final String topic;
  final String? customTopic;

  @override
  State<IntermediateChatScreen> createState() => _IntermediateChatScreenState();
}

class _IntermediateChatScreenState extends State<IntermediateChatScreen> {
  late IntermediateSession s = _newSession(widget.topic, widget.customTopic);
  final _scroll = ScrollController();
  final _input = TextEditingController();
  bool _typing = false;
  bool _showCorrections = true;
  final _translated = <CharacterLine>{};
  int _lastCount = 0;

  IntermediateSession _newSession(String topic, String? custom) {
    final session = IntermediateSession(
      api: widget.services.aiApi,
      recorder: widget.services.newRecorder(),
      player: widget.services.newSpeechPlayer(),
      device: widget.services.newDeviceVoice(),
      lang: widget.lang,
      character: widget.character.id,
      topic: topic,
      customTopic: custom,
    )..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) session.start();
    });
    return session;
  }

  void _changed() {
    if (!mounted) return;
    final notice = s.notice;
    if (notice != null) {
      s.clearNotice();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    }
    if (s.lines.length != _lastCount) {
      _lastCount = s.lines.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    s.end();
    s.dispose();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  /// 한글 이름 + 이/가(예: 루시아가, 하은이)
  String get _name {
    final k = widget.character.nameIn(widget.lang).korean;
    return '$k${hasFinalConsonant(k) ? '이' : '가'}';
  }

  Future<void> _restart() async {
    final old = s..removeListener(_changed);
    await old.end();
    old.dispose();
    setState(() {
      _translated.clear();
      _lastCount = 0;
      s = _newSession(old.topic, old.customTopic);
    });
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화를 끝낼까요?'),
        content: const Text('대화 내용은 저장되지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속하기'),
          ),
          FilledButton(
            key: const Key('confirmEnd'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('끝내기'),
          ),
        ],
      ),
    );
    if (ok == true) await s.end();
  }

  Future<void> _changeTopic() async {
    var selected = s.topic;
    final custom = TextEditingController(text: s.customTopic ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.cream,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '주제 바꾸기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in topics)
                    ChoiceChip(
                      key: Key('newTopic-${t.id}'),
                      label: Text(t.label),
                      selected: t.id == selected,
                      onSelected: (_) => setSheet(() => selected = t.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: custom,
                maxLength: 60,
                decoration: const InputDecoration(labelText: '직접 주제 입력(선택)'),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('applyTopic'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('이 주제로 이어 가기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) s.changeTopic(selected, custom: custom.text);
    custom.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicLabel = s.customTopic ?? topicById(s.topic).label;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CharacterAvatar(
              characterId: widget.character.id,
              size: 38,
              speaking: s.status == SessionStatus.speaking,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.character.nameIn(widget.lang).label,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '중급 · $topicLabel',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Palette.cocoa,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('changeTopic'),
            tooltip: '주제 바꾸기',
            onPressed: s.status == SessionStatus.ended ? null : _changeTopic,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            key: const Key('toggleCorrections'),
            tooltip: _showCorrections ? '교정 숨기기' : '교정 보기',
            onPressed: () =>
                setState(() => _showCorrections = !_showCorrections),
            icon: Icon(
              _showCorrections
                  ? Icons.spellcheck_rounded
                  : Icons.visibility_off_outlined,
            ),
          ),
          if (s.status != SessionStatus.ended)
            TextButton(
              key: const Key('endConversation'),
              onPressed: _end,
              child: const Text('끝내기'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Centered(
        maxWidth: 760,
        child: Column(
          children: [
            if (s.status != SessionStatus.starting &&
                s.voiceMode != VoiceMode.character)
              _Banner(
                s.voiceMode == VoiceMode.device
                    ? '캐릭터 음성은 준비 중이라, 이 기기의 기본 목소리로 읽어 드려요(캐릭터 목소리가 아니에요).'
                    : '캐릭터 음성은 준비 중이고, 이 기기에는 이 언어의 기본 목소리가 없어 글로 대화해요.',
              ),
            Expanded(
              child: ListView(
                key: const Key('aiChat'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (final (i, line) in s.lines.indexed)
                    switch (line) {
                      CharacterLine() => _characterBubble(i, line),
                      UserLine() => _userBubble(i, line),
                    },
                  if (s.status == SessionStatus.starting ||
                      s.status == SessionStatus.thinking)
                    _Thinking(
                      name: _name,
                      starting: s.status == SessionStatus.starting,
                    ),
                  if (s.status == SessionStatus.ended) _endCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      // 아래 조작부를 bottomNavigationBar에 두어 안내 메시지(SnackBar)가 마이크 버튼을 가리지 않게 한다.
      bottomNavigationBar: s.status == SessionStatus.ended
          ? null
          : Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _controls(),
              ),
            ),
    );
  }

  Widget _characterBubble(int i, CharacterLine line) {
    final speaking = s.speaking == line;
    final translated = _translated.contains(line);
    return Padding(
      key: Key('aiLine-$i'),
      padding: const EdgeInsets.only(bottom: 12, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterAvatar(
            characterId: widget.character.id,
            size: 34,
            speaking: speaking,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Panel(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.text,
                    style: const TextStyle(fontSize: 16.5, height: 1.45),
                  ),
                  if (translated && line.translation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        line.translation,
                        style: const TextStyle(
                          color: Palette.cocoa,
                          height: 1.45,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.voiceAvailable)
                        IconButton(
                          key: Key('replay-$i'),
                          tooltip: speaking ? '멈추기' : '다시 듣기',
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              s.status == SessionStatus.listening ||
                                  s.status == SessionStatus.thinking
                              ? null
                              : () => s.speak(line),
                          icon: Icon(
                            speaking
                                ? Icons.graphic_eq_rounded
                                : Icons.volume_up_rounded,
                            color: Palette.ink,
                            size: 20,
                          ),
                        ),
                      if (line.translation.isNotEmpty)
                        TextButton(
                          key: Key('translate-$i'),
                          onPressed: () => setState(
                            () => translated
                                ? _translated.remove(line)
                                : _translated.add(line),
                          ),
                          child: Text(translated ? '번역 숨기기' : '번역 보기'),
                        ),
                      if (line.audioFailed)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '음성 없음',
                            style: TextStyle(
                              fontSize: 12,
                              color: Palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userBubble(int i, UserLine line) {
    final r = line.result;
    return Padding(
      key: Key('userLine-$i'),
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: Palette.butterSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  line.typed ? Icons.keyboard_rounded : Icons.mic_rounded,
                  size: 16,
                  color: Palette.butterDeep,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    !r.isUnderstandable && r.recognizedText.isEmpty
                        ? '(잘 들리지 않았어요)'
                        : r.recognizedText,
                    style: const TextStyle(fontSize: 16, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          if (_showCorrections && r.hasFeedback)
            _CorrectionCard(key: Key('correction-$i'), result: r)
          else if (_showCorrections &&
              r.isUnderstandable &&
              r.recognizedText.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 6),
              child: Text(
                '고칠 부분이 없어요',
                style: TextStyle(fontSize: 12.5, color: Palette.sage),
              ),
            ),
        ],
      ),
    );
  }

  Widget _endCard() => Panel(
    key: const Key('aiEndCard'),
    color: Palette.sageSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대화를 마쳤어요',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          '대화 내용은 저장되지 않아요. 위로 스크롤해 교정을 다시 볼 수 있어요.',
          style: TextStyle(color: Palette.cocoa, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('aiRestart'),
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('새 대화'),
            ),
            OutlinedButton(
              key: const Key('aiBackToSetup'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('다른 상대·주제 고르기'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _controls() {
    final busy =
        s.status == SessionStatus.starting ||
        s.status == SessionStatus.thinking;
    final listening = s.status == SessionStatus.listening;
    final blocked = s.quotaExhausted;
    final label = switch (s.status) {
      _ when blocked => '오늘 무료 사용량이 끝났어요',
      SessionStatus.starting => '$_name 대화를 준비하고 있어요',
      SessionStatus.thinking => '알아듣고 답을 만드는 중이에요',
      SessionStatus.listening =>
        '듣고 있어요 0:${s.recordingSeconds.toString().padLeft(2, '0')} · 다 말했으면 다시 누르세요',
      SessionStatus.speaking => '$_name 말하는 중 · 버튼을 누르면 바로 대답할 수 있어요',
      _ => '버튼을 누르고 말한 뒤, 다시 눌러 보내세요',
    };
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Palette.cream,
          border: Border(top: BorderSide(color: Palette.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              key: const Key('aiStatus'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: listening ? Palette.toast : Palette.cocoa,
                fontWeight: listening ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            if (_typing)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('aiTextInput'),
                      controller: _input,
                      enabled: !busy && !blocked,
                      maxLength: 300,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendTyped(),
                      decoration: InputDecoration(
                        hintText:
                            '${widget.services.repo.catalog.language(widget.lang).native}로 입력하세요',
                        counterText: '',
                        filled: true,
                        fillColor: Palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('aiSend'),
                    onPressed: busy || blocked ? null : _sendTyped,
                    icon: const Icon(Icons.send_rounded),
                  ),
                  IconButton(
                    key: const Key('aiUseMic'),
                    tooltip: '말하기로 돌아가기',
                    onPressed: () => setState(() => _typing = false),
                    icon: const Icon(Icons.mic_none_rounded),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 48),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: FilledButton(
                      key: const Key('micButton'),
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: listening
                            ? Palette.toast
                            : Palette.butter,
                        foregroundColor: listening ? Colors.white : Palette.ink,
                      ),
                      onPressed: busy || blocked ? null : s.toggleMic,
                      child: Icon(
                        listening ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    key: const Key('aiUseKeyboard'),
                    tooltip: '글자로 입력하기',
                    onPressed: listening
                        ? null
                        : () => setState(() => _typing = true),
                    icon: const Icon(Icons.keyboard_rounded),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTyped() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await s.sendText(text);
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({super.key, required this.result});

  final TurnResult result;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: BoxDecoration(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Palette.sky.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.correctionNeeded && result.correctedText.isNotEmpty) ...[
          const Text(
            '고친 문장',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Palette.sky,
            ),
          ),
          Text(
            result.correctedText,
            style: const TextStyle(fontSize: 15.5, height: 1.45),
          ),
          const SizedBox(height: 6),
        ],
        if (result.naturalExpression.isNotEmpty &&
            result.naturalExpression != result.correctedText) ...[
          const Text(
            '더 자연스럽게',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Palette.sage,
            ),
          ),
          Text(
            result.naturalExpression,
            style: const TextStyle(fontSize: 15.5, height: 1.45),
          ),
          const SizedBox(height: 6),
        ],
        if (result.correctionExplanation.isNotEmpty)
          Text(
            result.correctionExplanation,
            style: const TextStyle(
              fontSize: 13.5,
              color: Palette.cocoa,
              height: 1.5,
            ),
          ),
      ],
    ),
  );
}

class _Thinking extends StatelessWidget {
  const _Thinking({required this.name, required this.starting});

  final String name;
  final bool starting;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('aiThinking'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Palette.butterDeep,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          starting ? '$name 첫마디를 준비하고 있어요…' : '생각하는 중…',
          style: const TextStyle(color: Palette.cocoa),
        ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('aiVoiceBanner'),
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Palette.skySoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(fontSize: 13, color: Palette.ink)),
  );
}
