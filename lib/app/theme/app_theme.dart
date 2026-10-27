import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/motion.dart';
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
      primaryContainer: c.surfaceMuted,
      onPrimaryContainer: c.ink,
      secondary: c.live,
      onSecondary: c.onLive,
      secondaryContainer: Color.alphaBlend(c.live.withValues(alpha: 0.12), c.surface),
      onSecondaryContainer: c.live,
      tertiary: c.gold,
      onTertiary: c.onGold,
      error: c.danger,
      onError: Colors.white,
      errorContainer: Color.alphaBlend(c.danger.withValues(alpha: 0.12), c.surface),
      onErrorContainer: c.danger,
      surface: c.paper,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.surface,
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
      inversePrimary: c.paper,
    );

    TextStyle base(double size, FontWeight weight, {double height = 1.45, double spacing = 0}) => TextStyle(
      fontFamily: Fonts.family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: c.ink,
    );
    TextStyle display(double size, double weight, {double height = 1.08, double spacing = -0.5}) => Fonts.display(
      base(size, FontWeight.w700, height: height, spacing: spacing),
      weight: weight,
    );

    final text = TextTheme(
      displayLarge: display(44, 800, height: 1.02, spacing: -1.4),
      displayMedium: display(36, 800, height: 1.04, spacing: -1.1),
      displaySmall: display(30, 780, height: 1.06, spacing: -0.8),
      headlineLarge: display(28, 760, spacing: -0.7),
      headlineMedium: display(24, 760, spacing: -0.5),
      headlineSmall: display(21, 740, spacing: -0.4),
      titleLarge: display(18, 700, height: 1.18, spacing: -0.2),
      titleMedium: base(16, FontWeight.w600, height: 1.25),
      titleSmall: base(14.5, FontWeight.w600, height: 1.3),
      bodyLarge: base(16, FontWeight.w400, height: 1.55),
      bodyMedium: base(14.5, FontWeight.w400),
      bodySmall: base(12.5, FontWeight.w400, height: 1.4).copyWith(color: c.muted),
      labelLarge: base(15, FontWeight.w600, spacing: 0.1),
      labelMedium: base(12.5, FontWeight.w600, spacing: 0.1),
      labelSmall: Fonts.label(base(11.5, FontWeight.w600)),
    );

    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm + 2));
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide(color: c.line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Fonts.family,
      textTheme: text,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.live.withValues(alpha: 0.25),
        selectionHandleColor: c.live,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SoftSlidePageTransitionsBuilder(),
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
        titleTextStyle: text.headlineSmall,
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
        indicatorColor: c.ink,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontSize: 11.5,
            color: states.contains(WidgetState.selected) ? c.ink : c.muted,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.paper : c.muted, size: 22),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.ink,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        selectedIconTheme: IconThemeData(color: c.paper),
        unselectedIconTheme: IconThemeData(color: c.muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: c.ink, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: c.muted),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: c.line),
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
          side: BorderSide(color: c.ink.withValues(alpha: 0.22), width: 1.2),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge?.copyWith(decoration: TextDecoration.underline, decorationThickness: 1.4),
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
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.ink, width: 1.6)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 1.6)),
        labelStyle: text.bodyMedium?.copyWith(color: c.muted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.ink, fontWeight: FontWeight.w600),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        secondarySelectedColor: c.ink,
        disabledColor: c.surfaceMuted,
        checkmarkColor: c.paper,
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(color: c.ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.paper),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
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
        actionTextColor: c.live,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        insetPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
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
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStatePropertyAll(BorderSide(color: c.line)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? c.ink : c.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? c.paper : c.ink,
          ),
        ),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(c.ink)),
      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.muted,
        indicatorColor: c.ink,
        dividerColor: c.line,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.ink,
        foregroundColor: c.paper,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Radii.xs)),
        textStyle: text.bodySmall?.copyWith(color: c.paper),
      ),
    );
  }
}
