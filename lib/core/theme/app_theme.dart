import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/theme/tokens.g.dart';

/// Semantic colours from the "Mohor" design system that Material's
/// [ColorScheme] does not model directly.
///
/// Paper surfaces always use the light paper tokens in both light and dark
/// themes so scanned and generated pages remain true to physical paper.
@immutable
class RosidColors extends ThemeExtension<RosidColors> {
  const RosidColors({
    required this.bgCanvas,
    required this.bgSheet,
    required this.bgSunken,
    required this.bgInverse,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.inkOnAccent,
    required this.inkOnInverse,
    required this.lineSubtle,
    required this.lineStrong,
    required this.accentBase,
    required this.accentSoft,
    required this.accentInk,
    required this.goodBase,
    required this.goodSoft,
    required this.warnBase,
    required this.warnSoft,
    required this.badBase,
    required this.badSoft,
    required this.paperSheet,
    required this.paperInk,
    required this.paperLine,
    required this.cameraScene,
  });

  static const light = RosidColors(
    bgCanvas: RosidColorTokens.bgCanvasLight,
    bgSheet: RosidColorTokens.bgSheetLight,
    bgSunken: RosidColorTokens.bgSunkenLight,
    bgInverse: RosidColorTokens.bgInverseLight,
    inkPrimary: RosidColorTokens.inkPrimaryLight,
    inkSecondary: RosidColorTokens.inkSecondaryLight,
    inkTertiary: RosidColorTokens.inkTertiaryLight,
    inkOnAccent: RosidColorTokens.inkOnAccentLight,
    inkOnInverse: RosidColorTokens.inkOnInverseLight,
    lineSubtle: RosidColorTokens.lineSubtleLight,
    lineStrong: RosidColorTokens.lineStrongLight,
    accentBase: RosidColorTokens.accentBaseLight,
    accentSoft: RosidColorTokens.accentSoftLight,
    accentInk: RosidColorTokens.accentInkLight,
    goodBase: RosidColorTokens.goodBaseLight,
    goodSoft: RosidColorTokens.goodSoftLight,
    warnBase: RosidColorTokens.warnBaseLight,
    warnSoft: RosidColorTokens.warnSoftLight,
    badBase: RosidColorTokens.badBaseLight,
    badSoft: RosidColorTokens.badSoftLight,
    paperSheet: RosidColorTokens.paperSheetLight,
    paperInk: RosidColorTokens.paperInkLight,
    paperLine: RosidColorTokens.paperLineLight,
    cameraScene: RosidColorTokens.cameraSceneLight,
  );

  static const dark = RosidColors(
    bgCanvas: RosidColorTokens.bgCanvasDark,
    bgSheet: RosidColorTokens.bgSheetDark,
    bgSunken: RosidColorTokens.bgSunkenDark,
    bgInverse: RosidColorTokens.bgInverseDark,
    inkPrimary: RosidColorTokens.inkPrimaryDark,
    inkSecondary: RosidColorTokens.inkSecondaryDark,
    inkTertiary: RosidColorTokens.inkTertiaryDark,
    inkOnAccent: RosidColorTokens.inkOnAccentDark,
    inkOnInverse: RosidColorTokens.inkOnInverseDark,
    lineSubtle: RosidColorTokens.lineSubtleDark,
    lineStrong: RosidColorTokens.lineStrongDark,
    accentBase: RosidColorTokens.accentBaseDark,
    accentSoft: RosidColorTokens.accentSoftDark,
    accentInk: RosidColorTokens.accentInkDark,
    goodBase: RosidColorTokens.goodBaseDark,
    goodSoft: RosidColorTokens.goodSoftDark,
    warnBase: RosidColorTokens.warnBaseDark,
    warnSoft: RosidColorTokens.warnSoftDark,
    badBase: RosidColorTokens.badBaseDark,
    badSoft: RosidColorTokens.badSoftDark,
    // Paper stays light even in dark theme.
    paperSheet: RosidColorTokens.paperSheetDark,
    paperInk: RosidColorTokens.paperInkDark,
    paperLine: RosidColorTokens.paperLineDark,
    cameraScene: RosidColorTokens.cameraSceneDark,
  );

  final Color bgCanvas;
  final Color bgSheet;
  final Color bgSunken;
  final Color bgInverse;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color inkOnAccent;
  final Color inkOnInverse;
  final Color lineSubtle;
  final Color lineStrong;
  final Color accentBase;
  final Color accentSoft;
  final Color accentInk;
  final Color goodBase;
  final Color goodSoft;
  final Color warnBase;
  final Color warnSoft;
  final Color badBase;
  final Color badSoft;
  final Color paperSheet;
  final Color paperInk;
  final Color paperLine;
  final Color cameraScene;

  static RosidColors of(BuildContext context) {
    final ext = Theme.of(context).extension<RosidColors>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  RosidColors copyWith({
    Color? bgCanvas,
    Color? bgSheet,
    Color? bgSunken,
    Color? bgInverse,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? inkOnAccent,
    Color? inkOnInverse,
    Color? lineSubtle,
    Color? lineStrong,
    Color? accentBase,
    Color? accentSoft,
    Color? accentInk,
    Color? goodBase,
    Color? goodSoft,
    Color? warnBase,
    Color? warnSoft,
    Color? badBase,
    Color? badSoft,
    Color? paperSheet,
    Color? paperInk,
    Color? paperLine,
    Color? cameraScene,
  }) {
    return RosidColors(
      bgCanvas: bgCanvas ?? this.bgCanvas,
      bgSheet: bgSheet ?? this.bgSheet,
      bgSunken: bgSunken ?? this.bgSunken,
      bgInverse: bgInverse ?? this.bgInverse,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      inkOnAccent: inkOnAccent ?? this.inkOnAccent,
      inkOnInverse: inkOnInverse ?? this.inkOnInverse,
      lineSubtle: lineSubtle ?? this.lineSubtle,
      lineStrong: lineStrong ?? this.lineStrong,
      accentBase: accentBase ?? this.accentBase,
      accentSoft: accentSoft ?? this.accentSoft,
      accentInk: accentInk ?? this.accentInk,
      goodBase: goodBase ?? this.goodBase,
      goodSoft: goodSoft ?? this.goodSoft,
      warnBase: warnBase ?? this.warnBase,
      warnSoft: warnSoft ?? this.warnSoft,
      badBase: badBase ?? this.badBase,
      badSoft: badSoft ?? this.badSoft,
      paperSheet: paperSheet ?? this.paperSheet,
      paperInk: paperInk ?? this.paperInk,
      paperLine: paperLine ?? this.paperLine,
      cameraScene: cameraScene ?? this.cameraScene,
    );
  }

  @override
  RosidColors lerp(ThemeExtension<RosidColors>? other, double t) {
    if (other is! RosidColors) return this;
    return RosidColors(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSheet: Color.lerp(bgSheet, other.bgSheet, t)!,
      bgSunken: Color.lerp(bgSunken, other.bgSunken, t)!,
      bgInverse: Color.lerp(bgInverse, other.bgInverse, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      inkOnAccent: Color.lerp(inkOnAccent, other.inkOnAccent, t)!,
      inkOnInverse: Color.lerp(inkOnInverse, other.inkOnInverse, t)!,
      lineSubtle: Color.lerp(lineSubtle, other.lineSubtle, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      accentBase: Color.lerp(accentBase, other.accentBase, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      goodBase: Color.lerp(goodBase, other.goodBase, t)!,
      goodSoft: Color.lerp(goodSoft, other.goodSoft, t)!,
      warnBase: Color.lerp(warnBase, other.warnBase, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      badBase: Color.lerp(badBase, other.badBase, t)!,
      badSoft: Color.lerp(badSoft, other.badSoft, t)!,
      paperSheet: Color.lerp(paperSheet, other.paperSheet, t)!,
      paperInk: Color.lerp(paperInk, other.paperInk, t)!,
      paperLine: Color.lerp(paperLine, other.paperLine, t)!,
      cameraScene: Color.lerp(cameraScene, other.cameraScene, t)!,
    );
  }
}

abstract final class AppTheme {
  // Legacy color aliases kept for any v1 screens being upgraded across M2–M8.
  static const Color ink = RosidColorTokens.inkPrimaryLight;
  static const Color leaf = RosidColorTokens.accentBaseLight;
  static const Color mint = RosidColorTokens.accentSoftLight;
  static const Color paper = RosidColorTokens.bgCanvasLight;
  static const Color amber = RosidColorTokens.warnBaseLight;

  static ThemeData light() => _build(Brightness.light, RosidColors.light);

  static ThemeData dark() => _build(Brightness.dark, RosidColors.dark);

  static ThemeData _build(Brightness brightness, RosidColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accentBase,
      onPrimary: c.inkOnAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accentInk,
      secondary: c.goodBase,
      onSecondary: c.inkOnAccent,
      secondaryContainer: c.goodSoft,
      onSecondaryContainer: c.goodBase,
      tertiary: c.warnBase,
      onTertiary: c.inkOnAccent,
      tertiaryContainer: c.warnSoft,
      onTertiaryContainer: c.warnBase,
      error: c.badBase,
      onError: c.inkOnAccent,
      errorContainer: c.badSoft,
      onErrorContainer: c.badBase,
      surface: c.bgCanvas,
      onSurface: c.inkPrimary,
      surfaceContainerLowest: c.bgSheet,
      surfaceContainerLow: c.bgSheet,
      surfaceContainer: c.bgSunken,
      surfaceContainerHigh: c.bgSunken,
      surfaceContainerHighest: c.bgSunken,
      onSurfaceVariant: c.inkSecondary,
      outline: c.lineStrong,
      outlineVariant: c.lineSubtle,
      shadow: RosidColorTokens.inkPrimaryLight,
      scrim: RosidColorTokens.inkPrimaryLight,
      inverseSurface: c.bgInverse,
      onInverseSurface: c.inkOnInverse,
      inversePrimary: c.accentSoft,
    );

    final textTheme = TextTheme(
      displayLarge: RosidTextTokens.uiDisplay.copyWith(color: c.inkPrimary),
      headlineLarge: RosidTextTokens.uiTitleLg.copyWith(color: c.inkPrimary),
      headlineMedium: RosidTextTokens.uiTitleLg.copyWith(color: c.inkPrimary),
      titleLarge: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
      titleMedium: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
      titleSmall: RosidTextTokens.uiBodyStrong.copyWith(color: c.inkPrimary),
      bodyLarge: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
      bodyMedium: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
      bodySmall: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
      labelLarge: RosidTextTokens.uiBodyStrong.copyWith(color: c.inkPrimary),
      labelMedium: RosidTextTokens.uiLabel.copyWith(color: c.inkSecondary),
      labelSmall: RosidTextTokens.uiMicro.copyWith(color: c.inkTertiary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Anek Bangla',
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgCanvas,
      textTheme: textTheme,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgCanvas,
        foregroundColor: c.inkPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: c.lineSubtle,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.bgSheet,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          side: BorderSide(color: c.lineSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgSheet,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: RosidTextTokens.uiBody.copyWith(color: c.inkTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          borderSide: BorderSide(color: c.lineSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          borderSide: BorderSide(color: c.lineSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          borderSide: BorderSide(color: c.accentBase, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: c.accentBase,
          foregroundColor: c.inkOnAccent,
          textStyle: RosidTextTokens.uiBodyStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: c.inkPrimary,
          side: BorderSide(color: c.lineStrong),
          textStyle: RosidTextTokens.uiBodyStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: c.accentBase,
          textStyle: RosidTextTokens.uiBodyStrong,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgInverse,
        contentTextStyle: RosidTextTokens.uiLabel.copyWith(
          color: c.inkOnInverse,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
        ),
      ),
    );
  }
}
