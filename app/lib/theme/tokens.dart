import 'package:flutter/material.dart';

/// Design tokens. Guard's blue and sky blue, with amber for "news soon" and red
/// for "window open". Poppins display, Inter body. This is the only file that
/// names a colour or a font family; the native gate screens, the Screen Time
/// card and the Live Activity mirror these values by hand.
abstract final class Tokens {
  // Brand
  static const Color brand = Color(0xFF0B5CAD);
  static const Color brandDeep = Color(0xFF08306B);
  static const Color sky = Color(0xFF5BC8F5);
  static const Color skyHairline = Color(0x555BC8F5);

  // High impact accents
  static const Color amber = Color(0xFFF5A524);
  static const Color red = Color(0xFFE5484D);

  // Cool ink (dark), tinted towards the brand navy
  static const Color inkBg = Color(0xFF0A1220);
  static const Color inkSurface = Color(0xFF101A2B);
  static const Color inkSurfaceRaised = Color(0xFF16233A);
  static const Color inkText = Color(0xFFEDF2F8);
  static const Color inkTextMuted = Color(0xFF9AA8BA);
  static const Color inkHairline = Color(0xFF223250);

  // Cool paper (light)
  static const Color paperBg = Color(0xFFF3F7FC);
  static const Color paperSurface = Color(0xFFFFFFFF);
  static const Color paperSurfaceRaised = Color(0xFFE8F0FA);
  static const Color paperText = Color(0xFF0E1A2B);
  static const Color paperTextMuted = Color(0xFF55657A);
  static const Color paperHairline = Color(0xFFD6E0EC);

  // Status. Restricted is red, soon is amber, clear is cool grey.
  static const Color statusRestricted = red;
  static const Color statusClear = Color(0xFF7C8794);
  static const Color statusWarn = amber;

  static const String displayFamily = 'Poppins';
  static const String bodyFamily = 'Inter';

  static const double radius = 10;
  static const double gutter = 16;

  // Width classes for the adaptive shell.
  static const double compactMax = 600;
  static const double mediumMax = 840;
}

abstract final class GuardTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? Tokens.inkBg : Tokens.paperBg;
    final surface = dark ? Tokens.inkSurface : Tokens.paperSurface;
    final raised = dark ? Tokens.inkSurfaceRaised : Tokens.paperSurfaceRaised;
    final text = dark ? Tokens.inkText : Tokens.paperText;
    final muted = dark ? Tokens.inkTextMuted : Tokens.paperTextMuted;
    final hairline = dark ? Tokens.inkHairline : Tokens.paperHairline;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? Tokens.sky : Tokens.brand,
      onPrimary: dark ? Tokens.inkBg : Colors.white,
      secondary: Tokens.sky,
      onSecondary: Tokens.inkBg,
      error: Tokens.statusWarn,
      onError: Tokens.inkBg,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: raised,
      outline: hairline,
      outlineVariant: Tokens.skyHairline,
    );

    final display = TextStyle(fontFamily: Tokens.displayFamily, color: text, fontWeight: FontWeight.w600);
    final body = TextStyle(fontFamily: Tokens.bodyFamily, color: text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: TextTheme(
        displayLarge: display.copyWith(fontSize: 56, height: 1.0, letterSpacing: -1),
        displayMedium: display.copyWith(fontSize: 40, height: 1.05),
        headlineMedium: display.copyWith(fontSize: 28),
        titleLarge: display.copyWith(fontSize: 20),
        titleMedium: display.copyWith(fontSize: 16),
        bodyLarge: body.copyWith(fontSize: 17),
        bodyMedium: body.copyWith(fontSize: 15),
        bodySmall: body.copyWith(fontSize: 13, color: muted),
        labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      dividerColor: Tokens.skyHairline,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radius),
          side: const BorderSide(color: Tokens.skyHairline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: Tokens.brand),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Tokens.brand.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(body.copyWith(fontSize: 12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: Tokens.brand.withValues(alpha: 0.18),
        selectedLabelTextStyle: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: body.copyWith(fontSize: 13, color: muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: display.copyWith(fontSize: 20),
      ),
    );
  }
}
