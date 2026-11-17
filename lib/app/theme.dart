import 'package:flutter/material.dart';

/// BUTTERFUL 색: 버터 옐로를 중심으로 크림 배경, 따뜻한 코코아 글자, 토스트 오렌지 강조
abstract final class Palette {
  static const butter = Color(0xFFF6C945);
  static const butterSoft = Color(0xFFFFF0BF);
  static const butterDeep = Color(0xFFB98A0F);
  static const cream = Color(0xFFFFF9EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2A2420);
  static const cocoa = Color(0xFF6E5A4B);
  static const muted = Color(0xFFA39484);
  static const line = Color(0xFFEFE4D3);
  static const toast = Color(0xFFE46F3A);
  static const toastSoft = Color(0xFFFCE5D8);
  static const sage = Color(0xFF4F8F6E);
  static const sageSoft = Color(0xFFE2F0E7);
  static const sky = Color(0xFF4E7FD8);
  static const skySoft = Color(0xFFE3ECFB);
}

final cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(22),
  side: const BorderSide(color: Palette.line),
);

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.butter,
        surface: Palette.cream,
      ).copyWith(
        primary: Palette.ink,
        onPrimary: Palette.butter,
        secondary: Palette.toast,
        surface: Palette.cream,
        onSurface: Palette.ink,
        outline: Palette.line,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.cream,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Palette.ink,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Palette.ink, height: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.butter,
        foregroundColor: Palette.ink,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Palette.line, width: 1.4),
        backgroundColor: Palette.surface,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.surface,
      selectedColor: Palette.butterSoft,
      side: const BorderSide(color: Palette.line),
      labelStyle: const TextStyle(
        color: Palette.ink,
        fontWeight: FontWeight.w600,
      ),
      shape: const StadiumBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// 화면 폭이 넓으면 가운데에 고정 폭으로 놓는다.
class Centered extends StatelessWidget {
  const Centered({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// 흰 카드
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.onTap,
    this.color = Palette.surface,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: borderColor ?? Palette.line,
        width: borderColor == null ? 1 : 1.6,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// 구역 제목
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 0, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// 작은 상태 표시(예: 준비 중)
class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.color = Palette.line,
    this.textColor = Palette.cocoa,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    ),
  );
}
