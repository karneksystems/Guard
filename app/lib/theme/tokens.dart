import 'package:flutter/material.dart';


/// Guard design tokens · Direction B Precision Field + C phase glow.
/// Paste over app/lib/theme/tokens.dart. Poppins display, Inter body.
/// Green ONLY for calendar impactLow. Amber = soon. Red = open / impactHigh.
/// Mid impact uses distinct yellow (not amber). Clear / Stay out = sky or cool grey — never green.
abstract final class Tokens {
  // Brand (locked)
  static const Color brand = Color(0xFF0B5CAD);
  static const Color brandDeep = Color(0xFF08306B);
  static const Color sky = Color(0xFF5BC8F5);
  static const Color skyHairline = Color(0x555BC8F5);

  // Urgency (locked). Phase edge glow + cover soon/open only.
  static const Color amber = Color(0xFFF5A524);
  static const Color red = Color(0xFFE5484D);

  // Calendar impact (Myfxbook-style). On event rows + filter chips ONLY.
  // Never use impactLow green for all-clear / success / Stay out.
  // Mid yellow is distinct from phase amber so filters ≠ urgency glow.
  static const Color impactLow = Color(0xFF3DDC97);   // green · low only
  static const Color impactMid = Color(0xFFE8C547);   // yellow · mid (≠ amber #F5A524)
  static const Color impactHigh = Color(0xFFE5484D);  // same as red · high opens cover
  static const Color impactNone = Color(0xFF7C8794);  // no-impact / none (cool grey)

  // Cool ink (dark) · B Precision Field (slightly deeper than prior)
  static const Color inkBg = Color(0xFF070D18);
  static const Color inkSurface = Color(0xFF0C1422);
  static const Color inkSurfaceRaised = Color(0xFF121C2E);
  static const Color inkText = Color(0xFFEDF2F8);
  static const Color inkTextMuted = Color(0xFF8B9AAE);
  static const Color inkHairline = Color(0xFF1A2740);

  // Cool paper (light) · B
  static const Color paperBg = Color(0xFFF1F5FA);
  static const Color paperSurface = Color(0xFFFFFFFF);
  static const Color paperSurfaceRaised = Color(0xFFE6EEF7);
  static const Color paperText = Color(0xFF0A1524);
  static const Color paperTextMuted = Color(0xFF5A6A7E);
  static const Color paperHairline = Color(0xFFD0DBE8);

  // Status. Restricted is red, soon is amber, clear is cool grey (never impact green).
  static const Color statusRestricted = red;
  static const Color statusClear = Color(0xFF7C8794);
  static const Color statusWarn = amber;

  // Phase edge glow · C thickness (~3pt) + soft bloom, B instrument language.
  // Use for news_glow.dart inset border + radial wash. Breathe opacity ±15%.
  static const Color phaseGlowAmber = Color(0x47F5A524); // rgba(245,165,36,0.28)
  static const Color phaseGlowRed = Color(0x52E5484D); // rgba(229,72,77,0.32)
  static const Color phaseGlowAmberCore = Color(0xE6F5A524); // ~0.9 edge line
  static const Color phaseGlowRedCore = Color(0xF2E5484D); // ~0.95 edge line
  static const double glowWidth = 3.0; // pt
  static const double glowBloom = 40.0; // soft inset blur radius
  static const double glowOuter = 32.0; // outer bloom

  // Type
  static const String displayFamily = 'Poppins';
  static const String bodyFamily = 'Inter';

  // Type scale (sizes). Weights: display w600, labels w600/w700, body w400/w500.
  static const double typeDisplayGate = 56; // gate arc countdown
  static const double typeDisplayHome = 28; // home ring countdown
  static const double typeDisplayLive = 36; // Live Activity count
  static const double typeHeadline = 28; // page titles
  static const double typeTitle = 20;
  static const double typeTitleSm = 16;
  static const double typeBodyLg = 17;
  static const double typeBody = 15;
  static const double typeBodySm = 13;
  static const double typeLabel = 12;
  static const double typeMicro = 10; // kicker / metric keys
  static const double typeSymbol = 24; // XAUUSD on home hero

  // Spacing
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space18 = 18;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space28 = 28;
  static const double space32 = 32;
  static const double gutter = 18;

  // Radius · B hairline tighter
  static const double radiusSm = 8; // buttons, chips
  static const double radius = 10; // metrics
  static const double radiusMd = 12; // cards, rail, ring hero
  static const double radiusLg = 16; // Live Activity card
  static const double radiusPill = 99;

  // Elevation · none (hairline borders only). Keep 0.
  static const double elevation = 0;

  // Adaptive shell breakpoints
  static const double compactMax = 600;
  static const double mediumMax = 840;

  // Gate hold
  static const Duration holdToView = Duration(seconds: 3);
  static const Duration viewWindow = Duration(seconds: 60);

  // Ring / arc stroke widths
  static const double ringStrokeHome = 6;
  static const double ringStrokeGate = 8;
  static const double ringStrokeLive = 4;
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

    final display = TextStyle(
      fontFamily: Tokens.displayFamily,
      color: text,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final body = TextStyle(fontFamily: Tokens.bodyFamily, color: text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: TextTheme(
        displayLarge: display.copyWith(fontSize: Tokens.typeDisplayGate, height: 1.0, letterSpacing: -2),
        displayMedium: display.copyWith(fontSize: Tokens.typeDisplayHome, height: 1.05, letterSpacing: -1),
        headlineMedium: display.copyWith(fontSize: Tokens.typeHeadline),
        titleLarge: display.copyWith(fontSize: Tokens.typeTitle),
        titleMedium: display.copyWith(fontSize: Tokens.typeTitleSm),
        bodyLarge: body.copyWith(fontSize: Tokens.typeBodyLg),
        bodyMedium: body.copyWith(fontSize: Tokens.typeBody),
        bodySmall: body.copyWith(fontSize: Tokens.typeBodySm, color: muted),
        labelLarge: body.copyWith(fontSize: Tokens.typeBody, fontWeight: FontWeight.w600),
      ),
      dividerColor: hairline,
      cardTheme: CardThemeData(
        color: surface,
        elevation: Tokens.elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          side: BorderSide(color: hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusSm)),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: dark ? Tokens.sky.withValues(alpha: 0.4) : Tokens.brand),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusSm)),
          textStyle: body.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
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
        titleTextStyle: display.copyWith(fontSize: Tokens.typeTitle),
      ),
    );
  }
}
