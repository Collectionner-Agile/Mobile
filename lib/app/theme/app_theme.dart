import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(BrandColors.light, Brightness.light);
  static ThemeData dark() => _build(BrandColors.dark, Brightness.dark);

  static ThemeData _build(BrandColors c, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: Color.alphaBlend(c.accent.withValues(alpha: 0.14), c.surfaceRaised),
      onPrimaryContainer: c.accentStrong,
      secondary: c.gold,
      onSecondary: c.onGold,
      secondaryContainer: Color.alphaBlend(c.gold.withValues(alpha: 0.18), c.surfaceRaised),
      onSecondaryContainer: isLight ? const Color(0xFF7A4D00) : c.gold,
      tertiary: c.info,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      errorContainer: Color.alphaBlend(c.danger.withValues(alpha: 0.12), c.surfaceRaised),
      onErrorContainer: c.danger,
      surface: c.paper,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.surfaceRaised,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceMuted,
      outline: c.muted,
      outlineVariant: c.line,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: c.ink,
      onInverseSurface: c.paper,
      inversePrimary: c.accentStrong,
    );

    TextStyle display(double size, FontWeight weight, {double height = 1.12, double spacing = -0.4}) => TextStyle(
      fontFamily: Fonts.display,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: c.ink,
    );
    TextStyle body(double size, FontWeight weight, {double height = 1.45, double spacing = 0}) => TextStyle(
      fontFamily: Fonts.body,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: c.ink,
    );

    final text = TextTheme(
      displayLarge: display(44, FontWeight.w700, height: 1.05, spacing: -1.2),
      displayMedium: display(38, FontWeight.w700, height: 1.06, spacing: -1),
      displaySmall: display(32, FontWeight.w700, height: 1.08, spacing: -0.8),
      headlineLarge: display(30, FontWeight.w700, spacing: -0.7),
      headlineMedium: display(26, FontWeight.w700, spacing: -0.6),
      headlineSmall: display(22, FontWeight.w700, spacing: -0.4),
      titleLarge: display(19, FontWeight.w600, height: 1.2, spacing: -0.2),
      titleMedium: display(16, FontWeight.w600, height: 1.25, spacing: -0.1),
      titleSmall: body(14.5, FontWeight.w600, height: 1.3),
      bodyLarge: body(16, FontWeight.w400, height: 1.55),
      bodyMedium: body(14.5, FontWeight.w400),
      bodySmall: body(12.5, FontWeight.w400, height: 1.4).copyWith(color: c.muted),
      labelLarge: body(15, FontWeight.w600, spacing: 0.1),
      labelMedium: body(12.5, FontWeight.w600, spacing: 0.1),
      labelSmall: body(11, FontWeight.w700, spacing: 1.1),
    );

    const controlShape = StadiumBorder();
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide(color: c.line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Fonts.body,
      textTheme: text,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall?.copyWith(fontSize: 21),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: brightness,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        indicatorColor: Color.alphaBlend(c.accent.withValues(alpha: 0.16), c.surface),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontSize: 11.5,
            color: states.contains(WidgetState.selected) ? c.ink : c.muted,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.accent : c.muted, size: 24),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: Color.alphaBlend(c.accent.withValues(alpha: 0.16), c.surface),
        selectedIconTheme: IconThemeData(color: c.accent),
        unselectedIconTheme: IconThemeData(color: c.muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: c.ink, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: c.muted),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        elevation: isLight ? 2 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: isLight ? BorderSide.none : BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceMuted,
          disabledForegroundColor: c.muted,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
          shape: controlShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
          side: BorderSide(color: c.line, width: 1.4),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.ink, minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 1.8)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 1.8)),
        labelStyle: text.bodyMedium?.copyWith(color: c.muted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.accent,
        secondarySelectedColor: c.accent,
        disabledColor: c.surfaceMuted,
        checkmarkColor: c.onAccent,
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(color: c.ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onAccent),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? c.ink : c.surfaceMuted,
        contentTextStyle: text.bodyMedium?.copyWith(color: isLight ? c.paper : c.ink),
        actionTextColor: c.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        insetPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        minVerticalPadding: Space.sm,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: c.line)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? c.accent : c.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? c.onAccent : c.ink,
          ),
        ),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(c.accent)),
      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.muted,
        indicatorColor: c.accent,
        dividerColor: c.line,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 3,
        highlightElevation: 6,
        extendedTextStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Radii.xs)),
        textStyle: text.bodySmall?.copyWith(color: c.paper),
      ),
    );
  }
}
