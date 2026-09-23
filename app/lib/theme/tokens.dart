import 'package:flutter/material.dart';

/// Design tokens from the total brief: OTTO craft on cool ink. Poppins display,
/// Inter body, metal accent #AE9558, champagne hairlines, flat metal buttons.
/// No greens anywhere, including status chips: status is metal or cool grey.
/// This is the only file that names a colour or a font family.
abstract final class Tokens {
  // Metal and champagne
  static const Color metal = Color(0xFFAE9558);
  static const Color metalDeep = Color(0xFF8A7440);
  static const Color champagne = Color(0xFFE8DCC0);
  static const Color champagneHairline = Color(0x66E8DCC0);

  // Cool ink (dark)
  static const Color inkBg = Color(0xFF0F1216);
  static const Color inkSurface = Color(0xFF161B21);
  static const Color inkSurfaceRaised = Color(0xFF1E252D);
  static const Color inkText = Color(0xFFEDEFF2);
  static const Color inkTextMuted = Color(0xFF9AA3AE);
  static const Color inkHairline = Color(0xFF2A333D);

  // Cool paper (light)
  static const Color paperBg = Color(0xFFF4F5F7);
  static const Color paperSurface = Color(0xFFFFFFFF);
  static const Color paperSurfaceRaised = Color(0xFFEDEFF2);
  static const Color paperText = Color(0xFF14181D);
  static const Color paperTextMuted = Color(0xFF5B6673);
  static const Color paperHairline = Color(0xFFD9DEE4);

  // Status. Restricted is metal, not red; clear is cool grey, not green.
  static const Color statusRestricted = metal;
  static const Color statusClear = Color(0xFF7C8794);
  static const Color statusWarn = Color(0xFFC98F3B);

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
      primary: Tokens.metal,
      onPrimary: Tokens.inkBg,
      secondary: Tokens.champagne,
      onSecondary: Tokens.inkBg,
      error: Tokens.statusWarn,
      onError: Tokens.inkBg,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: raised,
      outline: hairline,
      outlineVariant: Tokens.champagneHairline,
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
      dividerColor: Tokens.champagneHairline,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radius),
          side: const BorderSide(color: Tokens.champagneHairline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.metal,
          foregroundColor: Tokens.inkBg,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: Tokens.metal),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Tokens.metal.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(body.copyWith(fontSize: 12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: Tokens.metal.withValues(alpha: 0.18),
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
