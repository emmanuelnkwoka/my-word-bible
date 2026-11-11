import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mwb_palette.dart';
import 'mwb_themes.dart';
import 'mwb_tokens.dart';
import 'mwb_typography.dart';

/// Theme extension giving widgets access to MWB semantic tokens.
@immutable
class MwbTheme extends ThemeExtension<MwbTheme> {
  const MwbTheme({required this.themeId, required this.colors, required this.text});

  final MwbThemeId themeId;
  final MwbPalette colors;
  final MwbTypography text;

  @override
  MwbTheme copyWith({MwbThemeId? themeId, MwbPalette? colors, MwbTypography? text}) =>
      MwbTheme(themeId: themeId ?? this.themeId, colors: colors ?? this.colors, text: text ?? this.text);

  @override
  MwbTheme lerp(ThemeExtension<MwbTheme>? other, double t) {
    // Palettes switch discretely; ThemeData handles animated colour lerps of
    // Material components. Snap at the midpoint for MWB tokens.
    if (other is! MwbTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension MwbThemeContext on BuildContext {
  MwbTheme get mwb => Theme.of(this).extension<MwbTheme>()!;
}

/// Builds the Material [ThemeData] for a theme + brightness.
abstract final class AppThemeBuilder {
  static ThemeData build(MwbThemeId id, Brightness brightness) {
    final palette = MwbThemes.byId(id).paletteFor(brightness);
    return fromPalette(id, palette);
  }

  static ThemeData fromPalette(MwbThemeId id, MwbPalette p) {
    final text = MwbTypography.fromPalette(p);
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primaryStrong,
      onPrimary: p.onPrimary,
      primaryContainer: p.selected,
      onPrimaryContainer: p.textPrimary,
      secondary: p.secondary,
      onSecondary: p.onPrimary,
      tertiary: p.accent,
      onTertiary: p.onPrimary,
      error: p.error,
      onError: p.isDark ? p.background : Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceElevated,
      surfaceContainerHighest: p.surfaceElevated,
      outline: p.border,
      outlineVariant: p.divider,
      shadow: Colors.black,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.background,
      inversePrimary: p.accent,
    );

    final baseText = TextTheme(
      displayLarge: text.display,
      displayMedium: text.display.copyWith(fontSize: 36),
      displaySmall: text.pageHeading,
      headlineLarge: text.pageHeading,
      headlineMedium: text.pageHeading.copyWith(fontSize: 28),
      headlineSmall: text.sectionHeading,
      titleLarge: text.sectionHeading.copyWith(fontSize: 22),
      titleMedium: text.cardTitle,
      titleSmall: text.label.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.body.copyWith(fontSize: 16),
      bodyMedium: text.body,
      bodySmall: text.supporting,
      labelLarge: text.button,
      labelMedium: text.label,
      labelSmall: text.caption,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: baseText,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [MwbTheme(themeId: id, colors: p, text: text)],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.cardTitle.copyWith(fontSize: 17),
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: MwbRadius.lgAll,
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textPrimary,
        contentTextStyle: text.label.copyWith(color: p.background),
        actionTextColor: p.accent,
        shape: const RoundedRectangleBorder(borderRadius: MwbRadius.mdAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MwbRadius.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: MwbRadius.xlAll),
        titleTextStyle: text.sectionHeading,
        contentTextStyle: text.body.copyWith(color: p.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: text.body.copyWith(color: p.textSecondary),
        labelStyle: text.label.copyWith(color: p.textSecondary),
        floatingLabelStyle: text.label.copyWith(color: p.primary),
        errorStyle: text.caption.copyWith(color: p.error),
        border: OutlineInputBorder(
          borderRadius: MwbRadius.mdAll,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: MwbRadius.mdAll,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: MwbRadius.mdAll,
          borderSide: BorderSide(color: p.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: MwbRadius.mdAll,
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: MwbRadius.mdAll,
          borderSide: BorderSide(color: p.error, width: 1.4),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.25),
        selectionHandleColor: p.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.surfaceElevated,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primaryStrong : p.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.border,
        thumbColor: p.primaryStrong,
        overlayColor: p.primary.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.border,
        circularTrackColor: p.border,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        labelStyle: text.label.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: text.label,
        indicatorColor: p.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.divider,
        overlayColor: WidgetStateProperty.all(p.primary.withValues(alpha: 0.06)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        titleTextStyle: text.label.copyWith(fontSize: 15),
        subtitleTextStyle: text.caption,
        contentPadding: const EdgeInsets.symmetric(horizontal: MwbSpace.md),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.primary,
        collapsedIconColor: p.textSecondary,
        textColor: p.textPrimary,
        collapsedTextColor: p.textPrimary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surfaceElevated,
        dialHandColor: p.primaryStrong,
        hourMinuteColor: p.selected,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
