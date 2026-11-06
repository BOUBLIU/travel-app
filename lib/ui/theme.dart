import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Palette inspirée des couleurs système d'Apple.
class AppColors {
  final Color accent;
  final Color background; // fond groupé
  final Color card;
  final Color fill; // remplissage des contrôles (pastilles, champs)
  final Color label;
  final Color secondary;
  final Color tertiary;
  final Color separator;
  final Color green;
  final Color orange;
  final Color red;

  const AppColors({
    required this.accent,
    required this.background,
    required this.card,
    required this.fill,
    required this.label,
    required this.secondary,
    required this.tertiary,
    required this.separator,
    required this.green,
    required this.orange,
    required this.red,
  });

  static const light = AppColors(
    accent: Color(0xFF007AFF),
    background: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    fill: Color(0xFFE9E9EE),
    label: Color(0xFF1C1C1E),
    secondary: Color(0xFF8E8E93),
    tertiary: Color(0xFFC7C7CC),
    separator: Color(0xFFE5E5EA),
    green: Color(0xFF34C759),
    orange: Color(0xFFFF9500),
    red: Color(0xFFFF3B30),
  );

  static const dark = AppColors(
    accent: Color(0xFF0A84FF),
    background: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    fill: Color(0xFF2C2C2E),
    label: Color(0xFFFFFFFF),
    secondary: Color(0xFF98989F),
    tertiary: Color(0xFF48484A),
    separator: Color(0xFF38383A),
    green: Color(0xFF30D158),
    orange: Color(0xFFFF9F0A),
    red: Color(0xFFFF453A),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const kFont = 'Inter';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
    primary: c.accent,
    onPrimary: Colors.white,
    secondary: c.accent,
    surface: c.card,
    onSurface: c.label,
    onSurfaceVariant: c.secondary,
    surfaceContainerHighest: c.fill,
    surfaceContainerHigh: c.card,
    outline: c.tertiary,
    outlineVariant: c.separator,
    error: c.red,
    errorContainer: c.red.withValues(alpha: 0.12),
    onErrorContainer: c.red,
  );

  TextStyle t(double size, FontWeight w, {double ls = 0, double? h}) =>
      TextStyle(fontFamily: kFont, fontSize: size, fontWeight: w, letterSpacing: ls, height: h, color: c.label);

  final text = TextTheme(
    displayLarge: t(48, FontWeight.w700, ls: -1.4),
    displayMedium: t(40, FontWeight.w700, ls: -1.2),
    displaySmall: t(34, FontWeight.w700, ls: -0.9),
    headlineLarge: t(30, FontWeight.w700, ls: -0.7),
    headlineMedium: t(26, FontWeight.w700, ls: -0.6),
    headlineSmall: t(22, FontWeight.w600, ls: -0.4),
    titleLarge: t(19, FontWeight.w600, ls: -0.3),
    titleMedium: t(16, FontWeight.w600, ls: -0.2),
    titleSmall: t(14, FontWeight.w600, ls: -0.1),
    bodyLarge: t(16, FontWeight.w400, ls: -0.2, h: 1.35),
    bodyMedium: t(15, FontWeight.w400, ls: -0.15, h: 1.35),
    bodySmall: t(13, FontWeight.w400, ls: -0.05, h: 1.3).copyWith(color: c.secondary),
    labelLarge: t(15, FontWeight.w600, ls: -0.2),
    labelMedium: t(13, FontWeight.w500).copyWith(color: c.secondary),
    labelSmall: t(11, FontWeight.w500, ls: 0.2).copyWith(color: c.secondary),
  );

  const stadium = StadiumBorder();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFont,
    textTheme: text,
    scaffoldBackgroundColor: c.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.label.withValues(alpha: 0.04),
    hoverColor: c.label.withValues(alpha: 0.03),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: c.accent,
      titleTextStyle: t(17, FontWeight.w600, ls: -0.3),
      iconTheme: IconThemeData(color: c.accent, size: 22),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(CupertinoIcons.chevron_back, size: 24),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: c.separator, thickness: 0.6, space: 0.6),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: c.fill,
        disabledForegroundColor: c.secondary,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: stadium,
        elevation: 0,
        textStyle: t(16, FontWeight.w600, ls: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.accent,
        minimumSize: const Size(0, 50),
        side: BorderSide.none,
        backgroundColor: c.fill,
        shape: stadium,
        textStyle: t(16, FontWeight.w600, ls: -0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: t(15, FontWeight.w500, ls: -0.2),
        shape: stadium,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.accent)),
    chipTheme: ChipThemeData(
      backgroundColor: c.fill,
      selectedColor: c.accent,
      disabledColor: c.fill,
      side: BorderSide.none,
      shape: stadium,
      showCheckmark: false,
      labelStyle: t(14, FontWeight.w500, ls: -0.15),
      secondaryLabelStyle: t(14, FontWeight.w600, ls: -0.15).copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      iconTheme: IconThemeData(color: c.label, size: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.red, width: 1)),
      labelStyle: t(15, FontWeight.w400).copyWith(color: c.secondary),
      floatingLabelStyle: t(14, FontWeight.w500).copyWith(color: c.accent),
      hintStyle: t(15, FontWeight.w400).copyWith(color: c.tertiary),
      helperStyle: t(12, FontWeight.w400).copyWith(color: c.secondary),
      prefixIconColor: c.secondary,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.secondary,
      titleTextStyle: t(16, FontWeight.w400, ls: -0.2),
      subtitleTextStyle: t(13, FontWeight.w400).copyWith(color: c.secondary),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.fill,
      circularTrackColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xF21C1C1E),
      contentTextStyle: t(15, FontWeight.w500).copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: t(18, FontWeight.w600, ls: -0.3),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.tertiary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: stadium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: t(15, FontWeight.w400),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.card,
      headerForegroundColor: c.label,
      rangeSelectionBackgroundColor: c.accent.withValues(alpha: 0.12),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.card),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: t(15, FontWeight.w400)),
    cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.accent, brightness: brightness),
  );
}
