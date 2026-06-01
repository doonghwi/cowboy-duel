import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game/game_logic.dart';

/// Spaghetti-western / wanted-poster palette. Deliberate, committed direction:
/// warm parchment & leather with a dusty-sunset rust accent, plus a distinct
/// colour per action so the three choices read instantly.
class CD {
  static const sand = Color(0xFFE8D5A8);
  static const parchment = Color(0xFFF5EAD0);
  static const leather = Color(0xFF3B2412);
  static const ink = Color(0xFF241A12);
  static const muted = Color(0xFF7A6748);

  static const rust = Color(0xFFC8541E); // primary accent / sunset
  static const danger = Color(0xFF9E2B25); // shoot / hit
  static const sage = Color(0xFF2E6E5A); // defend
  static const gold = Color(0xFFD9A441); // reload

  // Dusk sky tones for the painted background.
  static const skyTop = Color(0xFF3A2A55);
  static const skyMid = Color(0xFFC8541E);
  static const skyLow = Color(0xFFF2B25C);
  static const duneFar = Color(0xFFB9712E);
  static const duneNear = Color(0xFF7A3E18);

  /// Colour for each action button.
  static Color actionColor(CowboyAction a) {
    switch (a) {
      case CowboyAction.reload:
        return gold;
      case CowboyAction.defend:
        return sage;
      case CowboyAction.shoot:
        return danger;
    }
  }
}

ThemeData buildCowboyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: CD.rust,
    scaffoldBackgroundColor: CD.sand,
    brightness: Brightness.light,
  );
  // Noto Sans KR gives full Korean support across the whole app.
  final textTheme = GoogleFonts.notoSansKrTextTheme(base.textTheme).apply(
    bodyColor: CD.ink,
    displayColor: CD.leather,
  );
  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: CD.leather,
      centerTitle: true,
    ),
  );
}

/// Heavy poster-style Korean title (Black Han Sans has full Hangul glyphs).
TextStyle posterTitle(double size, {Color? color}) => GoogleFonts.blackHanSans(
      fontSize: size,
      letterSpacing: 1,
      color: color ?? CD.leather,
      height: 1.05,
    );

/// Latin-only western display font, for English taglines / numbers only.
TextStyle westernLatin(double size, {Color? color, double spacing = 1}) =>
    GoogleFonts.rye(
      fontSize: size,
      letterSpacing: spacing,
      color: color ?? CD.rust,
    );
