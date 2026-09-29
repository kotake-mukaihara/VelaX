import 'package:flutter/material.dart';

/// Neutral wardrobe surfaces with blue reserved for actions and selection.
ThemeData wardrobeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3267D6),
        brightness: brightness,
      ).copyWith(
        primary: Color(dark ? 0xFFA8C5FF : 0xFF3267D6),
        onPrimary: Color(dark ? 0xFF143365 : 0xFFFFFFFF),
        primaryContainer: Color(dark ? 0xFF243C62 : 0xFFEAF1FF),
        onPrimaryContainer: Color(dark ? 0xFFD9E6FF : 0xFF2855AB),
        secondary: Color(dark ? 0xFFA8C5FF : 0xFF3267D6),
        secondaryContainer: Color(dark ? 0xFF243C62 : 0xFFEAF1FF),
        onSecondaryContainer: Color(dark ? 0xFFD9E6FF : 0xFF2855AB),
        surface: Color(dark ? 0xFF191B20 : 0xFFFFFFFF),
        surfaceContainerLowest: Color(dark ? 0xFF14161A : 0xFFFFFFFF),
        surfaceContainerLow: Color(dark ? 0xFF202329 : 0xFFFFFFFF),
        surfaceContainer: Color(dark ? 0xFF272B32 : 0xFFF5F6F8),
        surfaceContainerHigh: Color(dark ? 0xFF2E333B : 0xFFEEF0F3),
        surfaceContainerHighest: Color(dark ? 0xFF373D47 : 0xFFE7EAF0),
        onSurface: Color(dark ? 0xFFEDF0F5 : 0xFF252A34),
        onSurfaceVariant: Color(dark ? 0xFFB1B8C4 : 0xFF687180),
        outline: Color(dark ? 0xFF828B9B : 0xFF838C9B),
        outlineVariant: Color(dark ? 0xFF363C46 : 0xFFE5E8EE),
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const [
      'PingFang SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
    ],
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Color(dark ? 0xFF191B20 : 0xFFF5F6F8),
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: scheme.onSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(dark ? 0xFF191B20 : 0xFFF5F6F8),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'Segoe UI',
        color: scheme.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'Segoe UI',
        color: scheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 2,
      hoverElevation: 2,
      shape: const StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primaryContainer,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(color: scheme.onPrimaryContainer),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: rounded,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: rounded,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
