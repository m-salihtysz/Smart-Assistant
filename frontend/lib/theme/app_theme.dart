import 'package:flutter/material.dart';

/// Uygulamanın tüm renkleri burada tanımlanır. Ekranlar renk yazmak yerine
/// `context.pal.xxx` kullanır; böylece açık/koyu tema tek yerden yönetilir.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.fill,
    required this.border,
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.subtle,
    required this.shadow,
    required this.link,
    required this.positive,
    required this.negative,
  });

  /// Sayfa zemini.
  final Color bg;

  /// Kart, alan ve alt menü yüzeyi.
  final Color surface;

  /// Yüzeyin üstündeki hafif dolgu (pasif alan, çip).
  final Color fill;
  final Color border;

  /// Ana metin ve vurgu (siyah düğmeler).
  final Color ink;

  /// `ink` zemin üzerindeki metin/ikon.
  final Color onInk;

  /// İkincil metin.
  final Color muted;

  /// Yer tutucu, pasif ikon.
  final Color subtle;
  final Color shadow;
  final Color link;
  final Color positive;
  final Color negative;

  static const light = AppPalette(
    bg: Color(0xFFF8F9FA),
    surface: Colors.white,
    fill: Color(0xFFF3F4F5),
    border: Color(0xFFEEEEEE),
    ink: Color(0xFF1A1A1A),
    onInk: Colors.white,
    muted: Color(0xFF757575),
    subtle: Color(0xFFBDBDBD),
    shadow: Colors.black,
    link: Color(0xFF1A1A1A),
    positive: Color(0xFF2E7D32),
    negative: Color(0xFFC62828),
  );

  static const dark = AppPalette(
    bg: Color(0xFF0F0F11),
    surface: Color(0xFF1B1B1E),
    fill: Color(0xFF26262A),
    border: Color(0xFF2E2E33),
    ink: Color(0xFFF2F2F3),
    onInk: Color(0xFF111113),
    muted: Color(0xFFA1A1A8),
    subtle: Color(0xFF6C6C74),
    shadow: Colors.black,
    link: Color(0xFFF2F2F3),
    positive: Color(0xFF66BB6A),
    negative: Color(0xFFEF5350),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      fill: l(fill, other.fill),
      border: l(border, other.border),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      muted: l(muted, other.muted),
      subtle: l(subtle, other.subtle),
      shadow: l(shadow, other.shadow),
      link: l(link, other.link),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: Colors.transparent,
    extensions: [p],
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A1A),
      brightness: brightness,
      primary: p.ink,
      onPrimary: p.onInk,
      secondary: p.muted,
      surface: p.surface,
      onSurface: p.ink,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w900,
        color: p.ink,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: p.ink,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
      bodyLarge: TextStyle(color: p.muted, fontSize: 16),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: p.ink,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: p.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: p.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.fill,
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.subtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.subtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.ink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.negative),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: p.negative, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.link),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface),
  );
}
