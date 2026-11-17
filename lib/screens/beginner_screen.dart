import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../data/models.dart';
import 'character_screen.dart';
import 'words_screen.dart';

IconData categoryIcon(String id) => switch (id) {
  'travel' => Icons.luggage_rounded,
  'restaurant' => Icons.restaurant_rounded,
  'shopping' => Icons.shopping_bag_rounded,
  'daily' => Icons.wb_sunny_rounded,
  'work' => Icons.work_rounded,
  _ => Icons.chat_bubble_rounded,
};

IconData wordCategoryIcon(String id) => switch (id) {
  'greetings' => Icons.waving_hand_rounded,
  'numbers_time' => Icons.schedule_rounded,
  'people_family' => Icons.people_alt_rounded,
  'food_drink' => Icons.local_cafe_rounded,
  'places_directions' => Icons.place_rounded,
  'transport' => Icons.directions_bus_rounded,
  'shopping_money' => Icons.payments_rounded,
  'verbs' => Icons.directions_run_rounded,
  'adjectives' => Icons.palette_rounded,
  'questions' => Icons.help_rounded,
  _ => Icons.abc_rounded,
};

/// 초급: 기초 단어와 상황별 대화. 원하는 것부터 자유롭게 고른다.
class BeginnerScreen extends StatelessWidget {
  const BeginnerScreen({super.key, required this.services, required this.lang});

  final Services services;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final repo = services.repo;
    final catalog = repo.catalog;
    final language = catalog.language(lang);
    final book = repo.words(lang);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('초급'),
            Text(
              '${language.name} · ${language.native}',
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
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            const SectionTitle('기초 단어'),
            if (book.categories.isEmpty)
              const Panel(
                color: Colors.transparent,
                child: Text(
                  '이 언어의 기초 단어는 준비 중이에요.',
                  style: TextStyle(color: Palette.muted),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 560 ? 3 : 2;
                  final width = (box.maxWidth - 10 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in catalog.wordCategories)
                        if (book.words(c.id).isNotEmpty)
                          SizedBox(
                            width: width,
                            child: _WordCategoryTile(
                              category: c,
                              count: book.words(c.id).length,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => WordsScreen(
                                    services: services,
                                    lang: lang,
                                    category: c,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            const SectionTitle('상황별 대화'),
            for (final category in catalog.categories)
              ..._category(context, category),
          ],
        ),
      ),
    );
  }

  List<Widget> _category(BuildContext context, Category category) {
    final repo = services.repo;
    final scenarios = [
      for (final s in repo.catalog.scenarios)
        if (s.category == category.id && repo.hasScenario(lang, s.id)) s,
    ];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 0, 8),
        child: Text(
          category.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Palette.cocoa,
          ),
        ),
      ),
      if (scenarios.isEmpty)
        Panel(
          color: Colors.transparent,
          child: Row(
            children: [
              Icon(categoryIcon(category.id), color: Palette.muted),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '이 상황의 대화는 준비 중이에요.',
                  style: TextStyle(color: Palette.muted),
                ),
              ),
            ],
          ),
        )
      else
        for (final s in scenarios) ...[
          _ScenarioCard(
            info: s,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    CharacterScreen(services: services, lang: lang, info: s),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
    ];
  }
}

class _WordCategoryTile extends StatelessWidget {
  const _WordCategoryTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final WordCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    key: Key('wordCategory-${category.id}'),
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.butterSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            wordCategoryIcon(category.id),
            color: Palette.butterDeep,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              Text(
                '단어 $count개',
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.info, required this.onTap});

  final ScenarioInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    key: Key('scenario-${info.id}'),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.toastSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            categoryIcon(info.category),
            color: Palette.toast,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                info.summary,
                style: const TextStyle(fontSize: 13.5, color: Palette.cocoa),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: Palette.muted),
      ],
    ),
  );
}
