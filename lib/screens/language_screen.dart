import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';

/// 학습 언어 고르기(음성과 대화가 준비되지 않은 언어는 '준비 중')
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    final repo = services.repo;
    final current = services.progress.language;
    return Scaffold(
      appBar: AppBar(title: const Text('학습 언어')),
      body: Centered(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Text(
                '현지에서 쓰는 발음과 억양을 기준으로 해요.',
                style: TextStyle(color: Palette.cocoa),
              ),
            ),
            for (final l in repo.catalog.languages) ...[
              Builder(
                builder: (context) {
                  final ready = repo.isReady(l.code);
                  final selected = l.code == current;
                  return Panel(
                    key: Key('lang-${l.code}'),
                    borderColor: selected ? Palette.butter : null,
                    color: ready ? Palette.surface : Colors.transparent,
                    onTap: ready
                        ? () async {
                            await services.progress.setLanguage(l.code);
                            if (context.mounted) Navigator.of(context).pop();
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
                                ready
                                    ? '${l.variant} · 상황 ${l.content.length}개 · 캐릭터 ${repo.voicedCharacters(l.code).length}명'
                                    : l.variant,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Palette.cocoa,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!ready)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Palette.line,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '준비 중',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Palette.cocoa,
                              ),
                            ),
                          )
                        else if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Palette.butterDeep,
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
