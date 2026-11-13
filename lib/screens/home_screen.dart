import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../widgets/brand.dart';
import '../widgets/character_avatar.dart';
import 'character_screen.dart';
import 'conversation_screen.dart';
import 'language_screen.dart';

IconData categoryIcon(String id) => switch (id) {
  'travel' => Icons.luggage_rounded,
  'restaurant' => Icons.restaurant_rounded,
  'shopping' => Icons.shopping_bag_rounded,
  'daily' => Icons.wb_sunny_rounded,
  'work' => Icons.work_rounded,
  _ => Icons.chat_bubble_rounded,
};

/// 홈: 학습 언어, 이어서 하기, 상황별 대화, 최근 학습
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final Services services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final repo = widget.services.repo;
    final progress = widget.services.progress;
    // 처음이거나 고른 언어가 준비되지 않았으면, 준비된 첫 언어로 시작한다.
    final lang = progress.language;
    if (lang == null || !repo.isReady(lang)) {
      final first = repo.catalog.languages
          .where((l) => repo.isReady(l.code))
          .firstOrNull;
      if (first != null) progress.setLanguage(first.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return Scaffold(
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
  }

  Widget _body(BuildContext context) {
    final services = widget.services;
    final repo = services.repo;
    final progress = services.progress;
    final catalog = repo.catalog;
    final lang = progress.language;
    final language = lang == null ? null : catalog.language(lang);
    final resume = progress.resumable;
    final recent = progress.recent.take(5).toList();
    return Centered(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          const _Hero(),
          const SizedBox(height: 14),
          _LanguageCard(
            language: language,
            onChange: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LanguageScreen(services: services),
              ),
            ),
          ),
          if (resume != null &&
              repo.hasScenario(resume.lang, resume.scenario)) ...[
            const SectionTitle('이어서 학습하기'),
            _ResumeCard(services: services, session: resume),
          ],
          if (language != null)
            for (final category in catalog.categories)
              ..._category(context, category, language),
          if (recent.isNotEmpty) ...[
            SectionTitle(
              '최근 학습',
              trailing: TextButton(
                key: const Key('clearHistory'),
                onPressed: () => _confirmClear(context),
                child: const Text('기록 지우기'),
              ),
            ),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final s in recent)
                    _RecentRow(services: services, session: s),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            '대화 음성은 ${repo.engine == 'supertonic-3' ? 'Supertonic 3' : repo.engine}로 미리 만든 AI 음성이에요. '
            '버터풀은 내 목소리를 녹음하거나 저장하지 않아요. 학습 기록은 이 기기의 브라우저에만 저장돼요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Palette.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _category(
    BuildContext context,
    Category category,
    Language language,
  ) {
    final repo = widget.services.repo;
    final scenarios = [
      for (final s in repo.catalog.scenarios)
        if (s.category == category.id && repo.hasScenario(language.code, s.id))
          s,
    ];
    return [
      SectionTitle(category.name),
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
            services: widget.services,
            info: s,
            lang: language.code,
          ),
          const SizedBox(height: 10),
        ],
    ];
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학습 기록을 지울까요?'),
        content: const Text('이 기기에 저장된 진행 기록과 최근 학습이 모두 지워져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok ?? false) await widget.services.progress.clearHistory();
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
          '상대의 말을 듣고 소리 내어 따라 한 뒤, 내 대답을 고르면 대화가 이어져요. '
          '어떤 대답을 고르느냐에 따라 대화가 달라져요.',
          style: TextStyle(fontSize: 14.5, color: Palette.ink, height: 1.55),
        ),
      ],
    ),
  );
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.language, required this.onChange});

  final Language? language;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Panel(
    key: const Key('languageCard'),
    onTap: onChange,
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Palette.butterSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.translate_rounded, color: Palette.butterDeep),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '학습 언어',
                style: TextStyle(fontSize: 12.5, color: Palette.cocoa),
              ),
              const SizedBox(height: 2),
              Text(
                language == null
                    ? '언어를 골라 주세요'
                    : '${language!.name} · ${language!.native}',
                key: const Key('currentLanguage'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (language != null)
                Text(
                  language!.variant,
                  style: const TextStyle(fontSize: 12.5, color: Palette.muted),
                ),
            ],
          ),
        ),
        const Text(
          '바꾸기',
          style: TextStyle(color: Palette.toast, fontWeight: FontWeight.w700),
        ),
        const Icon(Icons.chevron_right_rounded, color: Palette.toast),
      ],
    ),
  );
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.services,
    required this.info,
    required this.lang,
  });

  final Services services;
  final ScenarioInfo info;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scenario = services.repo.scenario(lang, info.id);
    final heard = services.progress.visited(lang, info.id).length;
    final total = scenario.nodes.length;
    final done = services.progress.completions(lang, info.id);
    return Panel(
      key: Key('scenario-${info.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CharacterScreen(services: services, lang: lang, info: info),
        ),
      ),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : heard / total,
                          minHeight: 6,
                          color: Palette.butter,
                          backgroundColor: Palette.line,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      done > 0
                          ? '대사 $heard/$total · 완료 $done회'
                          : '대사 $heard/$total',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.cocoa,
                      ),
                    ),
                  ],
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
}

Future<void> openConversation(
  BuildContext context,
  Services services, {
  required String lang,
  required String scenario,
  required String character,
  List<String> resume = const [],
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ConversationScreen(
      services: services,
      lang: lang,
      scenarioId: scenario,
      character: services.repo.catalog.character(character),
      resumeChoices: resume,
    ),
  ),
);

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.services, required this.session});

  final Services services;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final catalog = services.repo.catalog;
    final info = catalog.scenario(session.scenario);
    final character = catalog.character(session.character);
    return Panel(
      key: const Key('resumeCard'),
      borderColor: Palette.butter,
      onTap: () => openConversation(
        context,
        services,
        lang: session.lang,
        scenario: session.scenario,
        character: session.character,
        resume: session.choices,
      ),
      child: Row(
        children: [
          CharacterAvatar(characterId: character.id, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${catalog.language(session.lang).name} · ${character.name}와 대화 · 대답 ${session.choices.length}번 함',
                  style: const TextStyle(fontSize: 13, color: Palette.cocoa),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Palette.toast,
            size: 38,
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.services, required this.session});

  final Services services;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final catalog = services.repo.catalog;
    final info = catalog.scenario(session.scenario);
    final character = catalog.character(session.character);
    final t = session.updatedAt.toLocal();
    final when =
        '${t.month}월 ${t.day}일 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return ListTile(
      leading: CharacterAvatar(characterId: character.id, size: 36),
      title: Text(
        info.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${catalog.language(session.lang).name} · ${character.name} · $when',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: session.done ? Palette.sageSoft : Palette.butterSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          session.done ? '완료' : '진행 중',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: session.done ? Palette.sage : Palette.butterDeep,
          ),
        ),
      ),
    );
  }
}
