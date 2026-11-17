import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import 'beginner_screen.dart';

/// 학습 단계. 고르기 위한 구분일 뿐이고, 승급·평가·잠금은 없다.
enum Level {
  beginner(
    '초급',
    '기초 단어와 상황별 대화',
    ['기초 단어와 자주 쓰는 표현 익히기', '상황별 대화 연습', '듣고 반복하며 표현 익히기'],
    Icons.eco_rounded,
    Palette.butterSoft,
    Palette.butterDeep,
  ),
  intermediate(
    '중급',
    '내 문장으로 대화하기',
    ['직접 문장으로 대답하며 대화 진행', 'AI가 내 답을 이해하고 자연스러운 표현 제안', '정답 고르기가 아닌 실제 의사소통'],
    Icons.edit_note_rounded,
    Palette.skySoft,
    Palette.sky,
  ),
  advanced(
    '고급',
    '대본 없는 자유 대화',
    ['다양한 주제로 자유롭게 대화', '예상하지 못한 질문과 상황에 대응', '필요할 때 표현·문법 피드백'],
    Icons.forum_rounded,
    Palette.sageSoft,
    Palette.sage,
  );

  const Level(
    this.label,
    this.summary,
    this.points,
    this.icon,
    this.soft,
    this.deep,
  );

  final String label;
  final String summary;
  final List<String> points;
  final IconData icon;
  final Color soft;
  final Color deep;

  /// 지금 쓸 수 있는 단계(중급·고급은 아직 준비 중)
  bool get available => this == Level.beginner;
}

/// 언어를 고른 뒤 초급·중급·고급 중 하나를 고른다. 어느 단계든 언제든 들어갈 수 있다.
class LevelScreen extends StatelessWidget {
  const LevelScreen({super.key, required this.services, required this.lang});

  final Services services;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final language = services.repo.catalog.language(lang);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${language.name} · ${language.native}'),
            Text(
              language.variant,
              style: const TextStyle(
                fontSize: 12.5,
                color: Palette.cocoa,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Centered(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Text(
                '학습 단계를 골라 주세요. 언제든 다른 단계로 바꿀 수 있어요.',
                style: TextStyle(color: Palette.cocoa),
              ),
            ),
            for (final level in Level.values) ...[
              _LevelCard(
                level: level,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => level == Level.beginner
                        ? BeginnerScreen(services: services, lang: lang)
                        : _ComingSoonScreen(
                            services: services,
                            lang: lang,
                            level: level,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.onTap});

  final Level level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    key: Key('level-${level.name}'),
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: level.soft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(level.icon, color: level.deep, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    level.label,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!level.available) const Tag('준비 중'),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                level.summary,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: level.deep,
                ),
              ),
              const SizedBox(height: 8),
              for (final p in level.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('·  ', style: TextStyle(color: Palette.cocoa)),
                      Expanded(
                        child: Text(
                          p,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Palette.cocoa,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Palette.muted),
      ],
    ),
  );
}

/// 중급·고급: 아직 학습 기능이 없어 무엇을 하게 될지만 보여 준다(가짜 기능을 만들지 않는다).
class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({
    required this.services,
    required this.lang,
    required this.level,
  });

  final Services services;
  final String lang;
  final Level level;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(level.label)),
    body: Centered(
      child: ListView(
        key: Key('comingSoon-${level.name}'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: level.soft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(level.icon, color: level.deep, size: 34),
                const SizedBox(height: 10),
                Text(
                  '${level.label} 학습은 준비 중이에요',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  level.summary,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: level.deep,
                  ),
                ),
                const SizedBox(height: 10),
                for (final p in level.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '·  $p',
                      style: const TextStyle(color: Palette.ink, height: 1.45),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('goBeginner'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BeginnerScreen(services: services, lang: lang),
              ),
            ),
            icon: const Icon(Icons.eco_rounded),
            label: const Text('지금은 초급으로 연습하기'),
          ),
        ],
      ),
    ),
  );
}
