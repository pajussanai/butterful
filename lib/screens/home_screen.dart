import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../widgets/brand.dart';
import 'level_screen.dart';

/// 홈: 학습 언어 고르기 → 학습 단계(초급·중급·고급) → 학습
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 68,
      titleSpacing: 20,
      title: const Wordmark(size: 19),
    ),
    body: ListenableBuilder(
      listenable: services.progress,
      builder: (context, _) => _body(context),
    ),
  );

  Widget _body(BuildContext context) {
    final repo = services.repo;
    final current = services.progress.language;
    return Centered(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          const _Hero(),
          const SectionTitle('학습 언어'),
          for (final l in repo.catalog.languages) ...[
            Builder(
              builder: (context) {
                final ready = repo.isReady(l.code);
                final selected = ready && l.code == current;
                return Panel(
                  key: Key('lang-${l.code}'),
                  borderColor: selected ? Palette.butter : null,
                  color: ready ? Palette.surface : Colors.transparent,
                  onTap: ready
                      ? () async {
                          await services.progress.setLanguage(l.code);
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  LevelScreen(services: services, lang: l.code),
                            ),
                          );
                        }
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l.name} · ${l.native}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: ready ? Palette.ink : Palette.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.variant,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Palette.cocoa,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!ready)
                        const Tag('준비 중')
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Palette.muted,
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 22),
          const Text(
            '음성은 공개 음성 모델(Supertonic 3, Kokoro, Qwen3-TTS)로 만든 AI 음성이에요. '
            '초급은 내 목소리를 쓰지 않아요. 중급 AI 회화는 말한 음성을 Google Gemini로 보내 분석하며, '
            '버터풀은 내 음성과 대화를 저장하지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Palette.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
    decoration: BoxDecoration(
      color: Palette.butter,
      borderRadius: BorderRadius.circular(26),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '원어민 목소리를 듣고\n따라 말해 보세요',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            height: 1.3,
            color: Palette.ink,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '배우고 싶은 언어를 고른 뒤, 원하는 단계에서 자유롭게 시작하세요.',
          style: TextStyle(fontSize: 14.5, color: Palette.ink, height: 1.55),
        ),
      ],
    ),
  );
}
