import 'package:flutter/material.dart';

/// Semantic colors for the marquee palette: warm charcoal with amber light.
abstract final class CandyColors {
  static const primary = Color(0xFFF5B83D);
  static const darkPrimary = Color(0xFFF5B83D);
  static const primaryContainer = Color(0xFF3A2C12);
  static const onPrimaryContainer = Color(0xFFFFDDA0);
  static const secondaryBrand = Color(0xFF2E2A25);
  static const accent = Color(0xFFFFD98A);
  static const softAccent = Color(0xFFB9AFA2);
  static const warmAccent = Color(0xFFFF8A75);
  static const errorContainer = Color(0xFF3F1E19);
  static const onErrorContainer = Color(0xFFFFD9D2);
  static const surface = Color(0xFF1B1916);
  static const surfaceHigh = Color(0xFF26231F);
  static const outline = Color(0xFF3B3631);
  static const background = Color(0xFF110F0D);
  static const onDark = Color(0xFFF5EFE6);
  static const contrastInk = Color(0xFF1C1405);
}

/// Shared spacing values used by the app shell and future features.
abstract final class CandySpacing {
  static const page = 24.0;
  static const gutter = 16.0;
  static const compact = 12.0;
  static const cardGap = 16.0;
  static const section = 32.0;
  static const minimumTouchTarget = 48.0;
}

/// Responsive layout constraints shared by focused content surfaces.
abstract final class CandyLayout {
  static const contentMaxWidth = 560.0;
}

/// Semantic icon sizes for branded and stateful illustrations.
abstract final class CandyIconSize {
  static const hero = 64.0;
  static const status = 48.0;
  static const action = 32.0;
  static const brand = 40.0;
}

/// Shared corner-radius values used by the candy collage.
abstract final class CandyShapes {
  static const card = 20.0;
  static const poster = 16.0;
  static const compact = 12.0;
  static const pill = 999.0;
  static const gridCardRatio = 0.56;
}

abstract final class CandyImages {
  static const artworkCacheWidth = 256;
  static const posterPreviewNetworkWidth = 48;
  static const posterPreviewQuality = 35;
  static const posterPreviewBlur = 20;
  static const posterDisplayNetworkWidth = 600;
  static const posterDisplayQuality = 90;
  static const posterCacheWidth = 600;
}

/// Shared motion values used by transitions and feedback.
abstract final class CandyMotion {
  static const quick = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 300);

  /// Total travel time of the shuffle reel before it locks on a pick.
  static const reelSpin = Duration(milliseconds: 2400);

  /// Settle time for details that arrive after the reel stops.
  static const reelSettle = Duration(milliseconds: 420);
}

/// Sizing for the shuffle slot-machine reel.
abstract final class CandyReel {
  /// Number of posters that scroll past before the selected one lands.
  static const travel = 22;

  /// Network width requested for posters that blur past during a spin.
  static const posterNetworkWidth = 240;
  static const posterQuality = 70;

  /// Maximum vertical motion blur applied at full reel speed.
  static const maxBlurSigma = 14.0;
}

/// Semantic typography roles; fonts intentionally fall back when not bundled.
abstract final class CandyTypography {
  static const display = 'Fredoka';
  static const displayWeight = FontWeight.w700;
  static const body = 'Atkinson Hyperlegible';
  static const bodyLineHeight = 1.5;
}

/// Theme extension exposing semantic design tokens through [ThemeData].
@immutable
final class CandyThemeTokens extends ThemeExtension<CandyThemeTokens> {
  const CandyThemeTokens({
    required this.canvas,
    required this.cardRadius,
    required this.standardMotion,
  });

  final Color canvas;
  final double cardRadius;
  final Duration standardMotion;

  @override
  CandyThemeTokens copyWith({
    Color? canvas,
    double? cardRadius,
    Duration? standardMotion,
  }) {
    return CandyThemeTokens(
      canvas: canvas ?? this.canvas,
      cardRadius: cardRadius ?? this.cardRadius,
      standardMotion: standardMotion ?? this.standardMotion,
    );
  }

  @override
  CandyThemeTokens lerp(
    covariant ThemeExtension<CandyThemeTokens>? other,
    double t,
  ) {
    if (other is! CandyThemeTokens) {
      return this;
    }
    return CandyThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      standardMotion: t < 0.5 ? standardMotion : other.standardMotion,
    );
  }
}

/// Builds the light Material 3 theme for the app shell.
ThemeData buildCandyLightTheme() => buildCandyTheme();

/// Builds the dark Material 3 theme for the app shell.
ThemeData buildCandyDarkTheme() => buildCandyTheme(brightness: Brightness.dark);

/// Builds a Material 3 theme for the requested appearance.
ThemeData buildCandyTheme({Brightness brightness = Brightness.light}) {
  // The app is always presented on a dark, cinema-like canvas; only the
  // reported brightness differs so platform widgets pick sensible defaults.
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: CandyColors.primary,
    onPrimary: CandyColors.contrastInk,
    primaryContainer: CandyColors.primaryContainer,
    onPrimaryContainer: CandyColors.onPrimaryContainer,
    secondary: CandyColors.accent,
    onSecondary: CandyColors.contrastInk,
    secondaryContainer: CandyColors.secondaryBrand,
    onSecondaryContainer: CandyColors.onDark,
    tertiary: CandyColors.accent,
    onTertiary: CandyColors.contrastInk,
    tertiaryContainer: CandyColors.surfaceHigh,
    onTertiaryContainer: CandyColors.softAccent,
    surface: CandyColors.surface,
    onSurface: CandyColors.onDark,
    onSurfaceVariant: CandyColors.softAccent,
    surfaceContainerLowest: CandyColors.background,
    surfaceContainerLow: CandyColors.surface,
    surfaceContainer: CandyColors.surface,
    surfaceContainerHigh: CandyColors.surfaceHigh,
    surfaceContainerHighest: CandyColors.surfaceHigh,
    outline: CandyColors.softAccent,
    outlineVariant: CandyColors.outline,
    inverseSurface: CandyColors.onDark,
    onInverseSurface: CandyColors.background,
    inversePrimary: CandyColors.primaryContainer,
    error: CandyColors.warmAccent,
    onError: CandyColors.contrastInk,
    errorContainer: CandyColors.errorContainer,
    onErrorContainer: CandyColors.onErrorContainer,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );
  final baseTextTheme = ThemeData.dark().textTheme;
  final textTheme = baseTextTheme.copyWith(
    displayLarge: baseTextTheme.displayLarge?.copyWith(
      fontFamily: CandyTypography.display,
      fontWeight: CandyTypography.displayWeight,
    ),
    displayMedium: baseTextTheme.displayMedium?.copyWith(
      fontFamily: CandyTypography.display,
      fontWeight: CandyTypography.displayWeight,
    ),
    displaySmall: baseTextTheme.displaySmall?.copyWith(
      fontFamily: CandyTypography.display,
      fontWeight: CandyTypography.displayWeight,
    ),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(
      fontFamily: CandyTypography.display,
      fontWeight: CandyTypography.displayWeight,
    ),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontFamily: CandyTypography.display,
      fontWeight: CandyTypography.displayWeight,
    ),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontFamily: CandyTypography.display,
      fontWeight: CandyTypography.displayWeight,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(
      fontFamily: CandyTypography.body,
      height: CandyTypography.bodyLineHeight,
    ),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(
      fontFamily: CandyTypography.body,
      height: CandyTypography.bodyLineHeight,
    ),
    bodySmall: baseTextTheme.bodySmall?.copyWith(
      fontFamily: CandyTypography.body,
      height: CandyTypography.bodyLineHeight,
    ),
  );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: CandyColors.background,
    colorScheme: colorScheme,
    cardTheme: CardThemeData(
      color: CandyColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandyShapes.card),
        side: const BorderSide(color: CandyColors.outline),
      ),
    ),
    dividerTheme: const DividerThemeData(color: CandyColors.outline),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CandyColors.primary,
      linearTrackColor: Colors.transparent,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: CandyColors.primary,
      selectionColor: CandyColors.primary.withValues(alpha: 0.35),
      selectionHandleColor: CandyColors.primary,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: CandyColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandyShapes.poster),
      ),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: CandyColors.primary,
      textColor: CandyColors.contrastInk,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: CandyColors.surface,
      modalBackgroundColor: CandyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CandyShapes.card),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CandyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandyShapes.card),
      ),
    ),
    chipTheme: ChipThemeData(
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) =>
            states.contains(WidgetState.selected) ? colorScheme.primary : null,
      ),
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : CandyColors.onDark,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CandySpacing.cardGap,
        vertical: CandySpacing.compact,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandyShapes.card),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandyShapes.card),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandyShapes.card),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(0, CandySpacing.minimumTouchTarget),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(0, CandySpacing.minimumTouchTarget),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size.square(CandySpacing.minimumTouchTarget),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CandyColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: colorScheme.primary,
      indicatorShape: const StadiumBorder(),
      height: CandySpacing.minimumTouchTarget + CandySpacing.compact * 2,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : CandyColors.softAccent,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (states) => textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : CandyColors.softAccent,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : CandyColors.onDark,
        ),
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(0, CandySpacing.minimumTouchTarget),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandyShapes.card),
      ),
    ),
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    extensions: <ThemeExtension<dynamic>>[
      CandyThemeTokens(
        canvas: CandyColors.background,
        cardRadius: CandyShapes.card,
        standardMotion: CandyMotion.standard,
      ),
    ],
  );
}
