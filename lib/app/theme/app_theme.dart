import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/app_icons.dart';
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
      secondary: c.gold,
      onSecondary: c.onGold,
      secondaryContainer: c.goldSoft,
      onSecondaryContainer: c.ink,
      tertiary: c.live,
      onTertiary: c.onLive,
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
      inversePrimary: c.gold,
    );

    TextStyle sans(double size, double weight, {double height = 1.45, double spacing = 0}) => TextStyle(
      fontFamily: Fonts.family,
      fontSize: size,
      fontWeight: Fonts.weightOf(weight),
      height: height,
      letterSpacing: spacing,
      color: c.ink,
    );
    TextStyle display(double size, double weight, {double height = 1.08, double spacing = -0.4}) => Fonts.display(
      sans(size, 700, height: height, spacing: spacing),
      weight: weight,
    );

    final text = TextTheme(
      displayLarge: display(42, 680, height: 1.02, spacing: -1),
      displayMedium: display(34, 680, height: 1.05, spacing: -0.8),
      displaySmall: display(29, 660, height: 1.08, spacing: -0.6),
      headlineLarge: display(27, 660, height: 1.1, spacing: -0.5),
      headlineMedium: display(23, 640, height: 1.14, spacing: -0.3),
      headlineSmall: sans(20, 720, height: 1.2, spacing: -0.3),
      titleLarge: sans(18, 700, height: 1.25, spacing: -0.2),
      titleMedium: sans(16, 620, height: 1.3, spacing: -0.1),
      titleSmall: sans(14.5, 620, height: 1.3),
      bodyLarge: sans(16, 420, height: 1.55),
      bodyMedium: sans(14.5, 420, height: 1.5),
      bodySmall: sans(12.5, 440, height: 1.4).copyWith(color: c.muted),
      labelLarge: sans(15, 640, spacing: 0.1),
      labelMedium: sans(12.5, 620, spacing: 0.1),
      labelSmall: Fonts.label(sans(11.5, 620)),
    );

    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
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
      // A plain ripple: InkSparkle compiles a shader on first tap, which costs
      // a dropped frame on slower phones.
      splashFactory: InkRipple.splashFactory,
      splashColor: c.ink.withValues(alpha: 0.06),
      highlightColor: c.ink.withValues(alpha: 0.04),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: c.ink, size: 22),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(AppIcons.arrowLeft, size: 22),
        closeButtonIconBuilder: (_) => const Icon(AppIcons.x, size: 22),
        drawerButtonIconBuilder: (_) => const Icon(AppIcons.list, size: 22),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.gold.withValues(alpha: 0.3),
        selectionHandleColor: c.gold,
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
        titleSpacing: Space.xs,
        toolbarHeight: 60,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: c.ink, size: 22),
        actionsIconTheme: IconThemeData(color: c.ink, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: brightness,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.goldSoft,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        selectedIconTheme: IconThemeData(color: c.ink),
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
          borderRadius: BorderRadius.circular(Radii.lg),
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
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
          shape: controlShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.surface,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
          side: BorderSide(color: c.line, width: 1.2),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
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
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 17),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 1.6)),
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
        selectedColor: c.accent,
        secondarySelectedColor: c.accent,
        disabledColor: c.surfaceMuted,
        checkmarkColor: c.onAccent,
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(color: c.ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onAccent),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.line,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? c.accent : c.surfaceRaised,
        contentTextStyle: text.bodyMedium?.copyWith(color: isLight ? c.onAccent : c.ink),
        actionTextColor: c.gold,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
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
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStatePropertyAll(BorderSide(color: c.line)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? c.accent : c.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? c.onAccent : c.ink,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onAccent : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.line,
        ),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(c.accent)),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onAccent),
        side: BorderSide(color: c.muted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xs)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceMuted,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
      ),
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
        elevation: 0,
        highlightElevation: 0,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Radii.xs)),
        textStyle: text.bodySmall?.copyWith(color: c.paper),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: c.line),
        ),
        textStyle: text.bodyMedium,
      ),
    );
  }
}
