import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';

void main() {
  test('should expose the marquee amber palette without violet hues', () {
    final palette = (
      primary: CandyColors.primary,
      darkPrimary: CandyColors.darkPrimary,
      accent: CandyColors.accent,
      surface: CandyColors.surface,
      background: CandyColors.background,
      onDark: CandyColors.onDark,
    );

    expect(palette, (
      primary: const Color(0xFFF5B83D),
      darkPrimary: const Color(0xFFF5B83D),
      accent: const Color(0xFFFFD98A),
      surface: const Color(0xFF1B1916),
      background: const Color(0xFF110F0D),
      onDark: const Color(0xFFF5EFE6),
    ));
    for (final theme in [buildCandyLightTheme(), buildCandyDarkTheme()]) {
      final scheme = theme.colorScheme;
      for (final color in <Color>[
        scheme.primary,
        scheme.secondary,
        scheme.tertiary,
        scheme.surface,
        scheme.surfaceContainerHighest,
        scheme.secondaryContainer,
        scheme.tertiaryContainer,
        scheme.outlineVariant,
        theme.scaffoldBackgroundColor,
      ]) {
        final hue = HSVColor.fromColor(color).hue;
        final saturation = HSVColor.fromColor(color).saturation;
        expect(
          saturation < 0.15 || hue < 60 || hue > 340,
          isTrue,
          reason: '$color must stay out of the violet/blue range',
        );
      }
    }
  });

  test('should use the amber accent in both brightness modes', () {
    final themes = [buildCandyLightTheme(), buildCandyDarkTheme()];

    final brandRoles = [
      for (final theme in themes)
        (
          brightness: theme.brightness,
          primary: theme.colorScheme.primary,
          onPrimary: theme.colorScheme.onPrimary,
        ),
    ];

    expect(brandRoles, [
      (
        brightness: Brightness.light,
        primary: CandyColors.primary,
        onPrimary: CandyColors.contrastInk,
      ),
      (
        brightness: Brightness.dark,
        primary: CandyColors.primary,
        onPrimary: CandyColors.contrastInk,
      ),
    ]);
  });

  test('should keep readable contrast on every key pairing', () {
    final scheme = buildCandyDarkTheme().colorScheme;
    final pairs = <(Color, Color)>[
      (scheme.primary, scheme.onPrimary),
      (scheme.surface, scheme.onSurface),
      (scheme.surface, scheme.onSurfaceVariant),
      (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.errorContainer, scheme.onErrorContainer),
      (scheme.inverseSurface, scheme.onInverseSurface),
      (CandyColors.background, scheme.primary),
    ];

    for (final (background, foreground) in pairs) {
      expect(
        _contrastRatio(background, foreground),
        greaterThanOrEqualTo(4.5),
        reason: '$foreground on $background',
      );
    }
  });

  test('should style selected filter controls in both brightness modes', () {
    final themes = [buildCandyLightTheme(), buildCandyDarkTheme()];
    final selectedStates = <WidgetState>{WidgetState.selected};
    final unselectedStates = <WidgetState>{};

    for (final theme in themes) {
      expect(
        theme.chipTheme.color?.resolve(selectedStates),
        CandyColors.primary,
      );
      expect(
        WidgetStateProperty.resolveAs<Color?>(
          theme.chipTheme.labelStyle?.color,
          selectedStates,
        ),
        CandyColors.contrastInk,
      );
      expect(
        WidgetStateProperty.resolveAs<Color?>(
          theme.chipTheme.labelStyle?.color,
          unselectedStates,
        ),
        CandyColors.onDark,
      );
      expect(theme.chipTheme.checkmarkColor, CandyColors.contrastInk);
      expect(
        theme.segmentedButtonTheme.style?.backgroundColor?.resolve(
          selectedStates,
        ),
        CandyColors.primary,
      );
      expect(
        theme.segmentedButtonTheme.style?.minimumSize?.resolve(selectedStates),
        const Size(0, CandySpacing.minimumTouchTarget),
      );
      expect(
        theme.segmentedButtonTheme.style?.shape?.resolve(selectedStates),
        isA<StadiumBorder>(),
      );
    }
  });

  test('should style persistent mode navigation in both brightness modes', () {
    final selected = <WidgetState>{WidgetState.selected};
    for (final theme in [buildCandyLightTheme(), buildCandyDarkTheme()]) {
      final navigation = theme.navigationBarTheme;
      expect(navigation.backgroundColor, CandyColors.background);
      expect(navigation.indicatorColor, CandyColors.primary);
      expect(
        navigation.height,
        CandySpacing.minimumTouchTarget + CandySpacing.compact * 2,
      );
      // The selected label sits beside the indicator, on the bar itself.
      expect(
        navigation.labelTextStyle?.resolve(selected)?.color,
        CandyColors.primary,
      );
      expect(
        navigation.iconTheme?.resolve(selected)?.color,
        CandyColors.contrastInk,
      );
    }
  });

  test('should use background canvas and raised surface in both modes', () {
    final themes = [buildCandyLightTheme(), buildCandyDarkTheme()];

    final surfaces = [
      for (final theme in themes)
        (
          scaffold: theme.scaffoldBackgroundColor,
          card: theme.cardTheme.color,
          bottomSheet: theme.bottomSheetTheme.backgroundColor,
          modalBottomSheet: theme.bottomSheetTheme.modalBackgroundColor,
          dialog: theme.dialogTheme.backgroundColor,
        ),
    ];

    expect(surfaces, [
      (
        scaffold: CandyColors.background,
        card: CandyColors.surface,
        bottomSheet: CandyColors.surface,
        modalBottomSheet: CandyColors.surface,
        dialog: CandyColors.surface,
      ),
      (
        scaffold: CandyColors.background,
        card: CandyColors.surface,
        bottomSheet: CandyColors.surface,
        modalBottomSheet: CandyColors.surface,
        dialog: CandyColors.surface,
      ),
    ]);
  });

  test(
    'should expose shared spacing shape and motion tokens when requested',
    () {
      expect(CandySpacing.page, 24);
      expect(CandyShapes.card, 20);
      expect(CandyMotion.standard, const Duration(milliseconds: 300));
      expect(CandyLayout.contentMaxWidth, 560);
      expect(CandyIconSize.hero, 64);
      expect(CandyIconSize.status, 48);
    },
  );

  test('should build a material three theme with typography roles', () {
    final theme = buildCandyTheme();

    expect(theme.useMaterial3, isTrue);
    expect(theme.extension<CandyThemeTokens>(), isNotNull);
    expect(theme.colorScheme.primary, CandyColors.primary);
    expect(theme.textTheme.displaySmall?.fontFamily, CandyTypography.display);
    expect(
      theme.textTheme.displaySmall?.fontWeight,
      CandyTypography.displayWeight,
    );
    expect(theme.textTheme.bodyLarge?.fontFamily, CandyTypography.body);
    expect(theme.textTheme.bodyLarge?.height, CandyTypography.bodyLineHeight);
  });

  test('should style primary controls through the shared component theme', () {
    final theme = buildCandyLightTheme();
    final states = <WidgetState>{};

    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve(states)?.height,
      CandySpacing.minimumTouchTarget,
    );
    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve(states)?.width,
      CandySpacing.minimumTouchTarget,
    );
    expect(theme.segmentedButtonTheme.style, isNotNull);
  });

  test('should build a dark material three theme with dark semantic roles', () {
    final theme = buildCandyDarkTheme();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.colorScheme.surface, CandyColors.surface);
    expect(theme.colorScheme.onSurface, CandyColors.onDark);
    expect(theme.scaffoldBackgroundColor, CandyColors.background);
    expect(theme.textTheme.bodyLarge?.color, CandyColors.onDark);
    expect(
      _contrastRatio(theme.colorScheme.primary, theme.colorScheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test(
    'should preserve the light theme through the explicit light builder',
    () {
      final theme = buildCandyLightTheme();

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.surface, CandyColors.surface);
      expect(theme.colorScheme.onSurface, CandyColors.onDark);
      expect(theme.scaffoldBackgroundColor, CandyColors.background);
    },
  );

  test('should expose installed theme tokens when the theme is requested', () {
    final theme = buildCandyTheme();
    final tokens = theme.extension<CandyThemeTokens>();

    expect(tokens?.canvas, CandyColors.background);
    expect(tokens?.cardRadius, CandyShapes.card);
    expect(tokens?.standardMotion, CandyMotion.standard);
  });

  test('should copy selected theme tokens when overrides are supplied', () {
    const original = CandyThemeTokens(
      canvas: CandyColors.background,
      cardRadius: CandyShapes.card,
      standardMotion: CandyMotion.standard,
    );

    final copied = original.copyWith(
      canvas: CandyColors.softAccent,
      cardRadius: CandyShapes.pill,
    );

    expect(copied.canvas, CandyColors.softAccent);
    expect(copied.cardRadius, CandyShapes.pill);
    expect(copied.standardMotion, CandyMotion.standard);
  });

  test('should interpolate theme tokens when another theme is supplied', () {
    const original = CandyThemeTokens(
      canvas: CandyColors.background,
      cardRadius: CandyShapes.card,
      standardMotion: CandyMotion.standard,
    );
    const target = CandyThemeTokens(
      canvas: CandyColors.softAccent,
      cardRadius: CandyShapes.pill,
      standardMotion: Duration(milliseconds: 500),
    );

    final interpolated = original.lerp(target, 0.5);

    expect(
      interpolated.canvas,
      Color.lerp(CandyColors.background, CandyColors.softAccent, 0.5),
    );
    expect(interpolated.cardRadius, 509.5);
    expect(interpolated.standardMotion, const Duration(milliseconds: 500));
  });

  test(
    'should retain tokens when interpolation receives another extension type',
    () {
      const original = CandyThemeTokens(
        canvas: CandyColors.background,
        cardRadius: CandyShapes.card,
        standardMotion: CandyMotion.standard,
      );

      final interpolated = original.lerp(null, 0.5);

      expect(interpolated, same(original));
    },
  );
}

double _contrastRatio(Color background, Color foreground) {
  final lighter = background.computeLuminance() > foreground.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  final darker = background.computeLuminance() > foreground.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
