import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_consent.dart';
import 'app/app.dart';
import 'app/theme.dart';
import 'data/content_repository.dart';
import 'data/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repo = ContentRepository();
    await repo.load();
    final prefs = await SharedPreferences.getInstance();
    runApp(
      ButterfulApp(
        services: Services(
          repo: repo,
          progress: ProgressStore(prefs),
          aiConsent: AiConsent(prefs),
        ),
      ),
    );
  } on Object catch (e) {
    runApp(_LoadError(error: '$e'));
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '학습 자료를 불러오지 못했어요. 새로고침해 주세요.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
