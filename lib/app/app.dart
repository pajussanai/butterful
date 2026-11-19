import 'package:flutter/material.dart';

import '../ai/ai_consent.dart';
import '../ai/device_voice.dart';
import '../ai/intermediate_api.dart';
import '../ai/voice_io.dart';
import '../audio/voice_player.dart';
import '../data/content_repository.dart';
import '../data/progress_store.dart';
import '../screens/home_screen.dart';
import 'theme.dart';

/// 앱 전체가 함께 쓰는 것들. 초급은 서버를 쓰지 않고, 중급 AI 회화만 [aiApi]로 서버를 부른다.
class Services {
  Services({
    required this.repo,
    required this.progress,
    VoicePlayer Function()? playerFactory,
    IntermediateApi? aiApi,
    VoiceRecorder Function()? recorderFactory,
    SpeechPlayer Function()? speechPlayerFactory,
    AiConsent? aiConsent,
    DeviceVoice Function()? deviceVoiceFactory,
  }) : newPlayer = playerFactory ?? AssetVoicePlayer.new,
       aiApi = aiApi ?? HttpIntermediateApi(),
       newRecorder = recorderFactory ?? MicRecorder.new,
       newSpeechPlayer = speechPlayerFactory ?? BytesSpeechPlayer.new,
       aiConsent = aiConsent ?? AiConsent(),
       newDeviceVoice = deviceVoiceFactory ?? createDeviceVoice;

  final ContentRepository repo;
  final ProgressStore progress;

  /// 화면마다 새 재생기를 만든다(초급의 미리 만든 음성).
  final VoicePlayer Function() newPlayer;

  /// 중급 AI 회화 서버(Supabase Edge Functions)
  final IntermediateApi aiApi;

  /// 중급 대화마다 새 녹음기·AI 음성 재생기를 만든다.
  final VoiceRecorder Function() newRecorder;
  final SpeechPlayer Function() newSpeechPlayer;

  /// 중급 AI 회화 데이터 안내 동의
  final AiConsent aiConsent;

  /// 캐릭터 음성 서버가 없을 때 쓰는 기기(브라우저) 기본 음성
  final DeviceVoice Function() newDeviceVoice;
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
