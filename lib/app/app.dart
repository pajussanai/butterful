import 'package:flutter/material.dart';

import '../audio/voice_player.dart';
import '../data/content_repository.dart';
import '../data/progress_store.dart';
import '../screens/home_screen.dart';
import 'theme.dart';

/// 앱 전체가 함께 쓰는 것들(서버 없음: 콘텐츠, 기기 저장소, 음성 재생)
class Services {
  Services({
    required this.repo,
    required this.progress,
    VoicePlayer Function()? playerFactory,
  }) : newPlayer = playerFactory ?? AssetVoicePlayer.new;

  final ContentRepository repo;
  final ProgressStore progress;

  /// 화면마다 새 재생기를 만든다.
  final VoicePlayer Function() newPlayer;
}

class ButterfulApp extends StatelessWidget {
  const ButterfulApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BUTTERFUL 버터풀',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: HomeScreen(services: services),
  );
}
