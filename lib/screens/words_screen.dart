import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../data/content_repository.dart';
import '../data/models.dart';
import '../words/word_audio_controller.dart';

/// 초급 기초 단어: 단어와 예문을 각각 듣고(반복·속도 조절) 따라 말한다.
class WordsScreen extends StatefulWidget {
  const WordsScreen({
    super.key,
    required this.services,
    required this.lang,
    required this.category,
  });

  final Services services;
  final String lang;
  final WordCategory category;

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  late final WordAudioController c = WordAudioController(
    repo: widget.services.repo,
    player: widget.services.newPlayer(),
  );

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.services.repo.catalog.language(widget.lang);
    final words = widget.services.repo
        .words(widget.lang)
        .words(widget.category.id);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category.name),
            Text(
              '${language.name} · ${language.native} · 초급 기초 단어',
              style: const TextStyle(
                fontSize: 12.5,
                color: Palette.cocoa,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Centered(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
              const SizedBox(height: 14),
              for (final w in words) ...[
                _WordCard(
                  word: w,
                  pronLabel: language.pronLabel,
                  wordAudio: ContentRepository.wordAudio(
                    widget.lang,
                    widget.category.id,
                    w.id,
                  ),
                  exampleAudio: ContentRepository.exampleAudio(
                    widget.lang,
                    widget.category.id,
                    w.id,
                  ),
                  c: c,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.pronLabel,
    required this.wordAudio,
    required this.exampleAudio,
    required this.c,
  });

  final WordItem word;
  final String pronLabel;
  final String wordAudio;
  final String exampleAudio;
  final WordAudioController c;

  @override
  Widget build(BuildContext context) {
    final active = c.playing == wordAudio || c.playing == exampleAudio;
    return Panel(
      key: Key('word-${word.id}'),
      borderColor: active ? Palette.butter : null,
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.text,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.pron,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Palette.sky,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      word.meaning,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Palette.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _PlayButton(
                key: Key('playWord-${word.id}'),
                tooltip: '단어 듣기',
                audio: wordAudio,
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Palette.cream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '예문',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Palette.toast,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        word.example,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        word.exampleTrans,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Palette.sage,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                _PlayButton(
                  key: Key('playExample-${word.id}'),
                  tooltip: '예문 듣기',
                  audio: exampleAudio,
                  c: c,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 듣기 버튼: 재생 중이면 멈춤 모양(반복 중이면 몇 번째인지)으로 바뀐다.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    super.key,
    required this.tooltip,
    required this.audio,
    required this.c,
    this.small = false,
  });

  final String tooltip;
  final String audio;
  final WordAudioController c;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final playing = c.playing == audio;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          tooltip: playing ? '멈춤' : tooltip,
          iconSize: small ? 22 : 26,
          style: IconButton.styleFrom(
            backgroundColor: playing ? Palette.toast : Palette.butter,
            foregroundColor: playing ? Colors.white : Palette.ink,
          ),
          onPressed: () => c.toggle(audio),
          icon: Icon(playing ? Icons.stop_rounded : Icons.volume_up_rounded),
        ),
        if (playing && c.repeat)
          Text(
            '${c.round}/${c.repeatTimes}',
            style: const TextStyle(
              fontSize: 11.5,
              color: Palette.toast,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
