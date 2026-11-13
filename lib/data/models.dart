/// 학습 언어
class Language {
  const Language({
    required this.code,
    required this.name,
    required this.native,
    required this.variant,
    required this.pronLabel,
    required this.transLabel,
    required this.content,
  });

  factory Language.fromJson(Map<String, dynamic> j) => Language(
    code: j['code'] as String,
    name: j['name'] as String,
    native: j['native'] as String,
    variant: j['variant'] as String,
    pronLabel: j['pronLabel'] as String,
    transLabel: j['transLabel'] as String,
    content: List<String>.from(j['content'] as List),
  );

  final String code;

  /// 한국어 이름(예: 영어)
  final String name;

  /// 그 언어로 쓴 이름(예: English)
  final String native;

  /// 발음 기준(예: 미국식)
  final String variant;
  final String pronLabel;
  final String transLabel;

  /// 이 언어로 준비된 시나리오 ID
  final List<String> content;
}

/// 학습 상황 묶음(여행, 식당·카페 …)
class Category {
  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['id'] as String, name: j['name'] as String);

  final String id;
  final String name;
}

/// 시나리오 소개(언어와 무관)
class ScenarioInfo {
  const ScenarioInfo({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.role,
  });

  factory ScenarioInfo.fromJson(Map<String, dynamic> j) => ScenarioInfo(
    id: j['id'] as String,
    category: j['category'] as String,
    title: j['title'] as String,
    summary: j['summary'] as String,
    role: j['role'] as String,
  );

  final String id;
  final String category;
  final String title;
  final String summary;

  /// 캐릭터가 맡는 역할(예: 식당 직원)
  final String role;
}

/// 대화 상대
class Character {
  const Character({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.personality,
    required this.style,
    required this.voice,
    required this.speed,
  });

  factory Character.fromJson(Map<String, dynamic> j) => Character(
    id: j['id'] as String,
    name: j['name'] as String,
    nameKo: j['nameKo'] as String,
    personality: j['personality'] as String,
    style: j['style'] as String,
    voice: j['voice'] as String,
    speed: (j['speed'] as num).toDouble(),
  );

  final String id;
  final String name;
  final String nameKo;
  final String personality;
  final String style;

  /// 음성 엔진의 목소리 이름(모든 언어에서 같은 목소리)
  final String voice;

  /// 생성할 때 쓴 말하기 속도
  final double speed;
}

/// 학습자가 고를 수 있는 대답
class Reply {
  const Reply({
    required this.id,
    required this.text,
    required this.pron,
    required this.trans,
    required this.next,
  });

  factory Reply.fromJson(Map<String, dynamic> j) => Reply(
    id: j['id'] as String,
    text: j['text'] as String,
    pron: j['pron'] as String,
    trans: j['trans'] as String,
    next: j['next'] as String,
  );

  final String id;
  final String text;
  final String pron;
  final String trans;

  /// 이 대답을 고르면 이어지는 대사
  final String next;
}

/// 캐릭터의 대사 하나와 그에 대한 대답들
class DialogueNode {
  const DialogueNode({
    required this.id,
    required this.stage,
    required this.text,
    required this.pron,
    required this.trans,
    required this.replies,
  });

  factory DialogueNode.fromJson(Map<String, dynamic> j) => DialogueNode(
    id: j['id'] as String,
    stage: j['stage'] as String,
    text: j['text'] as String,
    pron: j['pron'] as String,
    trans: j['trans'] as String,
    replies: [
      for (final r in j['replies'] as List)
        Reply.fromJson(r as Map<String, dynamic>),
    ],
  );

  final String id;

  /// 상황 단계(예: 자리 안내)
  final String stage;
  final String text;
  final String pron;
  final String trans;
  final List<Reply> replies;

  /// 대답이 없으면 대화가 끝난다.
  bool get isEnd => replies.isEmpty;
}

/// 한 언어로 쓴 분기형 대화
class Scenario {
  Scenario({
    required this.id,
    required this.lang,
    required this.start,
    required List<DialogueNode> nodes,
  }) : nodes = {for (final n in nodes) n.id: n};

  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
    id: j['id'] as String,
    lang: j['lang'] as String,
    start: j['start'] as String,
    nodes: [
      for (final n in j['nodes'] as List)
        DialogueNode.fromJson(n as Map<String, dynamic>),
    ],
  );

  final String id;
  final String lang;
  final String start;
  final Map<String, DialogueNode> nodes;

  DialogueNode node(String id) {
    final n = nodes[id];
    if (n == null) throw StateError('없는 대사: $id ($lang/${this.id})');
    return n;
  }
}

/// 언어·상황·캐릭터 목록
class Catalog {
  const Catalog({
    required this.languages,
    required this.categories,
    required this.scenarios,
    required this.characters,
  });

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
    languages: [
      for (final l in j['languages'] as List)
        Language.fromJson(l as Map<String, dynamic>),
    ],
    categories: [
      for (final c in j['categories'] as List)
        Category.fromJson(c as Map<String, dynamic>),
    ],
    scenarios: [
      for (final s in j['scenarios'] as List)
        ScenarioInfo.fromJson(s as Map<String, dynamic>),
    ],
    characters: [
      for (final c in j['characters'] as List)
        Character.fromJson(c as Map<String, dynamic>),
    ],
  );

  final List<Language> languages;
  final List<Category> categories;
  final List<ScenarioInfo> scenarios;
  final List<Character> characters;

  Language language(String code) => languages.firstWhere((l) => l.code == code);
  ScenarioInfo scenario(String id) => scenarios.firstWhere((s) => s.id == id);
  Character character(String id) => characters.firstWhere((c) => c.id == id);
}
