/// 중급 AI 회화 데이터(서버 응답 형식은 supabase/functions/_shared/prompt.ts와 같다)
library;

/// 대화 주제. 대화의 시작점일 뿐이고, 언제든 바꿀 수 있다.
class Topic {
  const Topic(this.id, this.label, this.english);

  final String id;
  final String label;
  final String english;
}

const topics = <Topic>[
  Topic('daily_life', '일상생활', 'Daily Life'),
  Topic('travel', '여행', 'Travel'),
  Topic('food', '음식·식당', 'Food & Restaurant'),
  Topic('shopping', '쇼핑', 'Shopping'),
  Topic('work', '직장·업무', 'Work & Business'),
  Topic('relationships', '인간관계', 'Relationships'),
  Topic('hobbies', '취미', 'Hobbies'),
  Topic('culture', '문화', 'Culture'),
  Topic('free', '자유 대화', 'Free Conversation'),
];

Topic topicById(String id) =>
    topics.firstWhere((t) => t.id == id, orElse: () => topics.last);

/// Gemini가 한 턴에 돌려주는 결과
class TurnResult {
  const TurnResult({
    required this.recognizedText,
    required this.isUnderstandable,
    required this.correctionNeeded,
    required this.correctedText,
    required this.naturalExpression,
    required this.correctionExplanation,
    required this.characterResponse,
    required this.nextQuestion,
    required this.responseTranslation,
    required this.conversationSummary,
  });

  /// 항목이 빠지거나 형식이 다르면 안전한 기본값을 쓴다.
  factory TurnResult.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] is String ? (j[k] as String).trim() : '';
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    return TurnResult(
      recognizedText: s('recognized_text'),
      isUnderstandable: b('is_understandable', true),
      correctionNeeded: b('correction_needed', false),
      correctedText: s('corrected_text'),
      naturalExpression: s('natural_expression'),
      correctionExplanation: s('correction_explanation'),
      characterResponse: s('character_response'),
      nextQuestion: s('next_question'),
      responseTranslation: s('response_translation'),
      conversationSummary: s('conversation_summary'),
    );
  }

  final String recognizedText;
  final bool isUnderstandable;
  final bool correctionNeeded;
  final String correctedText;
  final String naturalExpression;
  final String correctionExplanation;
  final String characterResponse;
  final String nextQuestion;
  final String responseTranslation;
  final String conversationSummary;

  /// 캐릭터가 실제로 말할 문장(반응 + 다음 질문)
  String get spoken =>
      [characterResponse, nextQuestion].where((t) => t.isNotEmpty).join(' ');

  /// 화면에 보여 줄 교정이 있는지
  bool get hasFeedback =>
      correctionNeeded ||
      (naturalExpression.isNotEmpty &&
          naturalExpression.trim() != recognizedText.trim());
}

/// 한 턴 요청. 대화 맥락은 최근 몇 줄과 요약만 보낸다.
class TurnRequest {
  const TurnRequest({
    required this.lang,
    required this.character,
    required this.topic,
    this.customTopic,
    this.summary,
    this.history = const [],
    this.opening = false,
    this.audio,
    this.audioMime,
    this.text,
  });

  final String lang;
  final String character;
  final String topic;
  final String? customTopic;
  final String? summary;
  final List<(String role, String text)> history;
  final bool opening;
  final List<int>? audio;
  final String? audioMime;
  final String? text;
}

/// 서버 오류 코드(Edge Function의 ErrorCode와 같음) + 앱 쪽 오류
enum AiError {
  badRequest('bad_request'),
  forbiddenOrigin('forbidden_origin'),
  rateLimited('rate_limited'),
  quotaExceeded('quota_exceeded'),
  aiUnavailable('ai_unavailable'),
  aiBadOutput('ai_bad_output'),
  notConfigured('not_configured'),
  ttsUnavailable('tts_unavailable'),
  ttsFailed('tts_failed'),
  network('network');

  const AiError(this.code);

  final String code;

  static AiError fromCode(String? code) => AiError.values.firstWhere(
    (e) => e.code == code,
    orElse: () => AiError.aiUnavailable,
  );

  /// 사용자에게 보여 줄 안내
  String get message => switch (this) {
    rateLimited => '조금 빠르게 많이 말했어요. 잠시 뒤에 다시 말해 주세요.',
    quotaExceeded =>
      '오늘 쓸 수 있는 무료 AI 사용량이 모두 끝났어요. 하루 단위로 다시 채워지니 나중에 이용해 주세요. 요금은 청구되지 않아요.',
    aiBadOutput => 'AI가 답을 제대로 만들지 못했어요. 한 번 더 말해 주세요.',
    notConfigured => 'AI 서버 설정이 아직 끝나지 않았어요.',
    forbiddenOrigin => '이 주소에서는 AI 회화를 쓸 수 없어요.',
    badRequest => '요청을 처리하지 못했어요. 다시 시도해 주세요.',
    network => '인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
    ttsUnavailable => '이 언어의 캐릭터 음성은 아직 준비 중이에요. 글로 대화를 이어 가세요.',
    ttsFailed => '음성을 만들지 못했어요. 글로 대화를 이어 갈 수 있어요.',
    aiUnavailable => 'AI가 지금 응답하지 않아요. 잠시 뒤 다시 시도해 주세요.',
  };
}

class AiException implements Exception {
  const AiException(this.error);

  final AiError error;

  @override
  String toString() => 'AiException(${error.code})';
}
