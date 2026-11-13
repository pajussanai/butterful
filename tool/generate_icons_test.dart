// 앱 아이콘·파비콘·브랜드 PNG를 LogoPainter 하나로 만든다.
// 실행: flutter test tool/generate_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:butterful/widgets/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _png(
  String path,
  int size, {
  bool rounded = true,
  double scale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  LogoPainter.paintLogo(
    canvas,
    Size.square(size.toDouble()),
    rounded: rounded,
    scale: scale,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('아이콘 만들기', (tester) async {
    await tester.runAsync(() async {
      // 웹
      await _png('web/favicon.png', 48);
      await _png('web/icons/Icon-192.png', 192);
      await _png('web/icons/Icon-512.png', 512);
      await _png(
        'web/icons/Icon-maskable-192.png',
        192,
        rounded: false,
        scale: 0.8,
      );
      await _png(
        'web/icons/Icon-maskable-512.png',
        512,
        rounded: false,
        scale: 0.8,
      );
      // Android
      for (final (dir, px) in [
        ('mdpi', 48),
        ('hdpi', 72),
        ('xhdpi', 96),
        ('xxhdpi', 144),
        ('xxxhdpi', 192),
      ]) {
        await _png('android/app/src/main/res/mipmap-$dir/ic_launcher.png', px);
      }
      // iOS(모서리는 기기가 깎으므로 꽉 찬 사각형)
      const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      for (final (name, px) in [
        ('1024x1024@1x', 1024),
        ('20x20@1x', 20),
        ('20x20@2x', 40),
        ('20x20@3x', 60),
        ('29x29@1x', 29),
        ('29x29@2x', 58),
        ('29x29@3x', 87),
        ('40x40@1x', 40),
        ('40x40@2x', 80),
        ('40x40@3x', 120),
        ('60x60@2x', 120),
        ('60x60@3x', 180),
        ('76x76@1x', 76),
        ('76x76@2x', 152),
        ('83.5x83.5@2x', 167),
      ]) {
        await _png('$ios/Icon-App-$name.png', px, rounded: false);
      }
      // 브랜드 원본
      await _png('brand/butterful_icon_1024.png', 1024);
      await _png('brand/butterful_icon_512.png', 512);
    });
  });
}
