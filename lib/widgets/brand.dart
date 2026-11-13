import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 로고 모양(앱 아이콘, 파비콘, 화면 로고가 모두 이 좌표 하나로 그려진다)
///
/// 버터 바탕 위의 말풍선 안에 목소리 막대 세 개. 말풍선 아래가 버터처럼 녹아 떨어진다.
class LogoPainter extends CustomPainter {
  const LogoPainter({this.background = true});

  /// false면 바탕 없이 말풍선만(투명 배경 아이콘용)
  final bool background;

  /// [rounded]가 false면 바탕을 꽉 찬 사각형으로 칠한다(iOS·마스커블 아이콘: 모서리는 기기가 깎는다).
  /// [scale]로 바탕 안에서 그림 크기를 줄인다(마스커블 아이콘의 안전 영역).
  static void paintLogo(
    Canvas canvas,
    Size size, {
    bool background = true,
    bool rounded = true,
    double scale = 1,
  }) {
    final full = size.shortestSide;
    final s = full * scale;
    final o = (full - s) / 2;
    Offset p(double x, double y) => Offset(o + x * s, o + y * s);
    final ink = Paint()..color = Palette.ink;
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & Size(full, full),
          Radius.circular(rounded ? full * 0.23 : 0),
        ),
        Paint()..color = Palette.butter,
      );
    }
    // 말풍선
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.17, 0.23), p(0.83, 0.66)),
        Radius.circular(s * 0.17),
      ),
      ink,
    );
    // 녹아 떨어지는 방울(말풍선 꼬리)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.275, 0.55), p(0.385, 0.79)),
        Radius.circular(s * 0.055),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.585, 0.58), p(0.645, 0.72)),
        Radius.circular(s * 0.03),
      ),
      ink,
    );
    // 목소리 막대
    final bar = Paint()..color = Palette.butter;
    for (final (x, h) in [(0.36, 0.13), (0.5, 0.23), (0.64, 0.13)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p(x, 0.445), width: s * 0.075, height: s * h),
          Radius.circular(s * 0.04),
        ),
        bar,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) =>
      paintLogo(canvas, size, background: background);

  @override
  bool shouldRepaint(LogoPainter oldDelegate) =>
      oldDelegate.background != background;
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: LogoPainter()),
  );
}

/// BUTTERFUL 워드마크(로고 + 글자)
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22, this.showKorean = false});

  final double size;
  final bool showKorean;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'BUTTERFUL 버터풀',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: size * 1.6),
        SizedBox(width: size * 0.45),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BUTTERFUL',
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w900,
                letterSpacing: size * 0.08,
                color: Palette.ink,
                height: 1.05,
              ),
            ),
            if (showKorean)
              Text(
                '버터풀',
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w700,
                  color: Palette.cocoa,
                  letterSpacing: size * 0.04,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
