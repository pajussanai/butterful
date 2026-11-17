import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../audio/voice_player.dart';
import '../data/content_repository.dart';
import '../data/models.dart';
import '../widgets/character_avatar.dart';
import 'conversation_screen.dart';

/// 대화 상대 고르기(목소리 미리 듣기)
class CharacterScreen extends StatefulWidget {
  const CharacterScreen({
    super.key,
    required this.services,
    required this.lang,
    required this.info,
  });

  final Services services;
  final String lang;
  final ScenarioInfo info;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late final VoicePlayer _player = widget.services.newPlayer();
  late String? _selected;
  String? _previewing;

  @override
  void initState() {
    super.initState();
    final voiced = widget.services.repo.voicedCharacters(widget.lang);
    final saved = widget.services.progress.character;
    _selected = voiced.any((c) => c.id == saved)
        ? saved
        : voiced.firstOrNull?.id;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(Character c) async {
    if (_previewing == c.id) {
      await _player.stop();
      setState(() => _previewing = null);
      return;
    }
    setState(() {
      _previewing = c.id;
      _selected = c.id;
    });
    final scenario = widget.services.repo.scenario(widget.lang, widget.info.id);
    try {
      await _player.play(
        ContentRepository.npcAudio(
          widget.lang,
          c.id,
          widget.info.id,
          scenario.start,
        ),
      );
    } on Object catch (e) {
      debugPrint('미리 듣기 실패: $e');
    }
    if (mounted && _previewing == c.id) setState(() => _previewing = null);
  }

  Future<void> _start() async {
    final id = _selected;
    if (id == null) return;
    await _player.stop();
    await widget.services.progress.setCharacter(id);
    if (!mounted) return;
    await openConversation(
      context,
      widget.services,
      lang: widget.lang,
      scenario: widget.info.id,
      character: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.services.repo;
    // 언어마다 목소리가 준비된 캐릭터만 보여 준다(영국 영어·중국어는 한 명).
    final characters = repo.voicedCharacters(widget.lang);
    final selected = _selected == null
        ? null
        : repo.catalog.character(_selected!);
    return Scaffold(
      appBar: AppBar(title: Text(widget.info.title)),
      body: Centered(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Text(
                '대화 상대를 골라 주세요. 상대는 ${widget.info.role} 역할을 맡아요.\n목소리 버튼으로 첫 대사를 미리 들어 볼 수 있어요.',
                style: const TextStyle(color: Palette.cocoa, height: 1.55),
              ),
            ),
            for (final c in characters) ...[
              _CharacterCard(
                character: c,
                lang: widget.lang,
                voiced: repo.isVoiced(widget.lang, c.id),
                selected: c.id == _selected,
                previewing: c.id == _previewing,
                onTap: () => setState(() => _selected = c.id),
                onPreview: () => _preview(c),
              ),
              const SizedBox(height: 10),
            ],
          ],
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
                  key: const Key('startConversation'),
                  onPressed: selected == null ? null : _start,
                  icon: const Icon(Icons.forum_rounded),
                  label: Text(
                    selected == null
                        ? '대화 상대를 골라 주세요'
                        : '${selected.nameIn(widget.lang).withAnd} 대화 시작',
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

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.lang,
    required this.voiced,
    required this.selected,
    required this.previewing,
    required this.onTap,
    required this.onPreview,
  });

  final Character character;
  final String lang;
  final bool voiced;
  final bool selected;
  final bool previewing;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) => Panel(
    key: Key('character-${character.id}'),
    onTap: voiced ? onTap : null,
    color: voiced ? Palette.surface : Colors.transparent,
    borderColor: selected ? characterColor(character.id) : null,
    child: Opacity(
      opacity: voiced ? 1 : 0.5,
      child: Row(
        children: [
          CharacterAvatar(
            characterId: character.id,
            size: 60,
            speaking: previewing,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.nameIn(lang).label,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  voiced
                      ? '${character.personality}. ${character.style}.'
                      : '이 언어의 목소리는 준비 중이에요.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Palette.cocoa,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (voiced)
            IconButton.filledTonal(
              key: Key('preview-${character.id}'),
              tooltip: '목소리 미리 듣기',
              style: IconButton.styleFrom(backgroundColor: Palette.butterSoft),
              onPressed: onPreview,
              icon: Icon(
                previewing ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: Palette.ink,
              ),
            ),
        ],
      ),
    ),
  );
}
