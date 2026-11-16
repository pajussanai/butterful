// 콘텐츠와 음성 파일 점검: 분기가 모두 이어지고, 모든 대사에 실제 음성 파일이 있는지
import 'dart:convert';
import 'dart:io';

import 'package:butterful/data/content_repository.dart';
import 'package:butterful/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final catalog = Catalog.fromJson(_json('assets/content/catalog.json'));
  final manifest = _json('assets/audio/manifest.json');
  final files = (manifest['files'] as Map<String, dynamic>).keys.toSet();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  // 언어마다 목소리를 만든 캐릭터(모든 언어에 다섯 명)
  final all = [for (final c in catalog.characters) c.id];
  final voicedIn = {
    'en': all,
    'ja': all,
    'ko': all,
    'en_gb': all,
    'zh': all,
    'fr': all,
    'es': all,
  };

  Scenario load(String lang, String id) =>
      Scenario.fromJson(_json('assets/content/$lang/$id.json'));

  test('초기 콘텐츠: 7개 언어 모두에 여행과 식당 대화가 있다', () {
    // 7개 언어가 목록에 있고, 모두 대화가 준비되어 있다.
    expect(catalog.languages.map((l) => l.code), [
      'en',
      'en_gb',
      'ja',
      'ko',
      'zh',
      'fr',
      'es',
    ]);
    for (final l in catalog.languages) {
      expect(l.content, containsAll(['restaurant', 'hotel']), reason: l.code);
    }
    expect(catalog.characters, hasLength(5));
  });

  for (final language in catalog.languages) {
    for (final id in language.content) {
      final lang = language.code;
      group('$lang/$id', () {
        final s = load(lang, id);

        test('파일 안의 언어·ID가 맞고, 모든 글이 채워져 있다', () {
          expect(s.lang, lang);
          expect(s.id, id);
          expect(catalog.scenarios.map((x) => x.id), contains(id));
          for (final n in s.nodes.values) {
            expect(
              [
                n.text,
                n.pron,
                n.trans,
                n.stage,
              ].every((t) => t.trim().isNotEmpty),
              isTrue,
              reason: n.id,
            );
            for (final r in n.replies) {
              expect(
                [r.text, r.pron, r.trans].every((t) => t.trim().isNotEmpty),
                isTrue,
                reason: r.id,
              );
            }
          }
        });

        test('모든 대답이 있는 대사로 이어지고, 모든 대사에 처음부터 갈 수 있다', () {
          final reached = <String>{};
          final queue = [s.start];
          while (queue.isNotEmpty) {
            final n = s.node(queue.removeLast());
            if (!reached.add(n.id)) continue;
            for (final r in n.replies) {
              expect(
                s.nodes.containsKey(r.next),
                isTrue,
                reason: '${r.id} -> ${r.next}',
              );
              queue.add(r.next);
            }
          }
          expect(reached, s.nodes.keys.toSet());
        });

        test('어느 대사에서든 결말에 닿을 수 있다(막다른 길·무한 반복 없음)', () {
          final canEnd = {
            for (final n in s.nodes.values)
              if (n.isEnd) n.id,
          };
          var changed = true;
          while (changed) {
            changed = false;
            for (final n in s.nodes.values) {
              if (!canEnd.contains(n.id) &&
                  n.replies.any((r) => canEnd.contains(r.next))) {
                canEnd.add(n.id);
                changed = true;
              }
            }
          }
          expect(canEnd, s.nodes.keys.toSet());
          expect(
            s.nodes.values.where((n) => n.isEnd).length,
            greaterThanOrEqualTo(2),
          );
        });

        test('대답 고르기에 따라 실제로 다른 대사로 갈라진다', () {
          final branching = s.nodes.values.where(
            (n) => n.replies.map((r) => r.next).toSet().length > 1,
          );
          expect(branching.length, greaterThanOrEqualTo(3));
        });

        test('대답 ID가 겹치지 않는다', () {
          final ids = [
            for (final n in s.nodes.values) ...n.replies.map((r) => r.id),
          ];
          expect(ids.toSet().length, ids.length);
        });

        test('정해 둔 캐릭터 목소리와 모범 답변 음성이 모두 실제 파일로 있다', () {
          for (final n in s.nodes.values) {
            for (final c in voicedIn[lang]!) {
              final rel = ContentRepository.npcAudio(lang, c, id, n.id);
              expect(files, contains(rel));
            }
            for (final r in n.replies) {
              expect(
                files,
                contains(ContentRepository.guideAudio(lang, id, r.id)),
              );
            }
          }
        });
      });
    }
  }

  test('언어마다 같은 시나리오는 같은 분기 구조(대사 ID)를 쓴다', () {
    for (final info in catalog.scenarios) {
      final langs = [
        for (final l in catalog.languages)
          if (l.content.contains(info.id)) l.code,
      ];
      final base = load(langs.first, info.id);
      for (final lang in langs.skip(1)) {
        final other = load(lang, info.id);
        expect(
          other.nodes.keys.toSet(),
          base.nodes.keys.toSet(),
          reason: '$lang/${info.id}',
        );
        for (final n in base.nodes.values) {
          expect(
            other.node(n.id).replies.map((r) => '${r.id}>${r.next}').toList(),
            n.replies.map((r) => '${r.id}>${r.next}').toList(),
            reason: '$lang/${info.id}/${n.id}',
          );
        }
      }
    }
  });

  test('음성 목록에 콘텐츠에 없는 파일이 없고, 언어마다 정해진 엔진으로 만들었다', () {
    final engines = _json('tool/tts/engines.json');
    const engineId = {
      'supertonic': null, // 기존 항목에는 engine 필드가 없다(목록 머리의 supertonic-3)
      'kokoro': 'kokoro-82m',
      'qwen': 'qwen3-tts-0.6b-base',
    };
    final expected = <String>{};
    for (final l in catalog.languages) {
      for (final id in l.content) {
        final s = load(l.code, id);
        for (final n in s.nodes.values) {
          for (final c in voicedIn[l.code]!) {
            expected.add(ContentRepository.npcAudio(l.code, c, id, n.id));
          }
          for (final r in n.replies) {
            expected.add(ContentRepository.guideAudio(l.code, id, r.id));
          }
        }
      }
    }
    expect(files.difference(expected), isEmpty, reason: '콘텐츠에 없는 음성');
    expect(expected.difference(files), isEmpty, reason: '빠진 음성');
    final entries = manifest['files'] as Map<String, dynamic>;
    for (final rel in files) {
      final lang = rel.split('/').first;
      final engine =
          (engines[lang] as Map<String, dynamic>)['engine'] as String;
      final meta = entries[rel] as Map<String, dynamic>;
      expect(meta['engine'], engineId[engine], reason: rel);
      expect((meta['sec'] as num).toDouble(), greaterThan(0.3), reason: rel);
    }
  });

  test('목록의 음성 파일이 실제로 있고 비어 있지 않은 MP3이며, 앱 자산으로 포함된다', () {
    expect(manifest['engine'], 'supertonic-3');
    expect(files, isNotEmpty);
    final dirs = <String>{};
    for (final rel in files) {
      final f = File('assets/audio/$rel');
      expect(f.existsSync(), isTrue, reason: rel);
      final bytes = f.readAsBytesSync();
      // 무음·빈 파일이 아님: MP3 머리(ID3 또는 프레임 동기)와 충분한 크기
      expect(bytes.length, greaterThan(2000), reason: rel);
      final header =
          bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33 ||
          bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
      expect(header, isTrue, reason: rel);
      dirs.add(rel.substring(0, rel.lastIndexOf('/') + 1));
    }
    for (final d in dirs) {
      expect(pubspec, contains('- assets/audio/$d'), reason: d);
    }
  });
}
