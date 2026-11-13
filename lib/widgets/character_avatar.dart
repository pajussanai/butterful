import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum _Hair { bob, short, bun, curly, long }

/// 캐릭터 얼굴 모양(벡터로 그려 이미지 파일 없이 선명하다)
class _Look {
  const _Look({
    required this.background,
    required this.skin,
    required this.hairColor,
    required this.hair,
    required this.shirt,
  });

  final Color background;
  final Color skin;
  final Color hairColor;
  final _Hair hair;
  final Color shirt;
}

const _looks = <String, _Look>{
  'mia': _Look(
    background: Palette.butterSoft,
    skin: Color(0xFFF5D2B8),
    hairColor: Color(0xFF3B2A22),
    hair: _Hair.bob,
    shirt: Palette.toast,
  ),
  'leo': _Look(
    background: Palette.skySoft,
    skin: Color(0xFFE6B793),
    hairColor: Color(0xFF2B2B2B),
    hair: _Hair.short,
    shirt: Palette.sky,
  ),
  'hana': _Look(
    background: Palette.sageSoft,
    skin: Color(0xFFF2CDB2),
    hairColor: Color(0xFF1F1A17),
    hair: _Hair.bun,
    shirt: Palette.sage,
  ),
  'theo': _Look(
    background: Palette.toastSoft,
    skin: Color(0xFFC48A66),
    hairColor: Color(0xFF34211A),
    hair: _Hair.curly,
    shirt: Palette.butterDeep,
  ),
  'ellie': _Look(
    background: Color(0xFFEFE7F8),
    skin: Color(0xFFF6D8C4),
    hairColor: Color(0xFF8A5A3B),
    hair: _Hair.long,
    shirt: Color(0xFF8C6BC7),
  ),
};

/// 캐릭터 대표 색(카드 테두리 등)
Color characterColor(String id) => (_looks[id] ?? _looks['mia']!).shirt;

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.characterId,
    this.size = 64,
    this.speaking = false,
  });

  final String characterId;
  final double size;

  /// 말하는 중이면 바깥에 고리가 생긴다.
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final look = _looks[characterId] ?? _looks['mia']!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: speaking ? look.shirt : Colors.transparent,
          width: size * 0.04,
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AvatarPainter(look)),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter(this.look);

  final _Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromPoints(p(l, t), p(rr, b));
    final circle = Path()..addOval(Offset.zero & Size(s, s));
    canvas
      ..save()
      ..clipPath(circle)
      ..drawPaint(Paint()..color = look.background);
    final hair = Paint()..color = look.hairColor;
    final skin = Paint()..color = look.skin;

    // 뒷머리
    switch (look.hair) {
      case _Hair.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r(0.26, 0.2, 0.74, 0.68),
            Radius.circular(s * 0.2),
          ),
          hair,
        );
      case _Hair.long:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r(0.25, 0.2, 0.75, 0.86),
            Radius.circular(s * 0.22),
          ),
          hair,
        );
      case _Hair.short || _Hair.bun || _Hair.curly:
        break;
    }
    // 어깨(옷)와 목
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r(0.16, 0.76, 0.84, 1.2),
        Radius.circular(s * 0.28),
      ),
      Paint()..color = look.shirt,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r(0.43, 0.58, 0.57, 0.8),
        Radius.circular(s * 0.05),
      ),
      Paint()..color = Color.lerp(look.skin, Colors.black, 0.08)!,
    );
    // 얼굴
    canvas.drawOval(r(0.31, 0.24, 0.69, 0.68), skin);
    // 앞머리
    switch (look.hair) {
      case _Hair.short:
        canvas.drawArc(r(0.29, 0.2, 0.71, 0.56), math.pi, math.pi, true, hair);
      case _Hair.bob || _Hair.long:
        canvas.drawArc(
          r(0.29, 0.2, 0.71, 0.58),
          math.pi * 0.95,
          math.pi * 1.1,
          true,
          hair,
        );
      case _Hair.bun:
        canvas
          ..drawCircle(p(0.5, 0.17), s * 0.085, hair)
          ..drawArc(r(0.3, 0.21, 0.7, 0.54), math.pi, math.pi, true, hair);
      case _Hair.curly:
        for (var i = 0; i <= 6; i++) {
          final a = math.pi + math.pi * i / 6;
          canvas.drawCircle(
            p(0.5 + 0.18 * math.cos(a), 0.4 + 0.17 * math.sin(a)),
            s * 0.075,
            hair,
          );
        }
    }
    // 눈, 볼, 웃는 입
    final ink = Paint()..color = Palette.ink;
    canvas
      ..drawCircle(p(0.43, 0.47), s * 0.02, ink)
      ..drawCircle(p(0.57, 0.47), s * 0.02, ink)
      ..drawCircle(
        p(0.39, 0.54),
        s * 0.03,
        Paint()..color = Palette.toast.withValues(alpha: 0.22),
      )
      ..drawCircle(
        p(0.61, 0.54),
        s * 0.03,
        Paint()..color = Palette.toast.withValues(alpha: 0.22),
      )
      ..drawArc(
        r(0.45, 0.5, 0.55, 0.58),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        Paint()
          ..color = Palette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.016
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => oldDelegate.look != look;
}
