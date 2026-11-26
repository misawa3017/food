import 'package:flutter/material.dart';

/// 暖陽橘綠（呼應 App Icon 橘綠雙色）設計系統共用的色彩 Token。
abstract final class AppColors {
  static const accent = Color(0xFFEE6016);
  static const accentSoft = Color(0xFF83B653);
  static const accentContainer = Color(0xFFFFD8AE);

  static const paperLight = Color(0xFFFFF1E2);
  static const paperRaisedLight = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF104A4C);
  static const mutedLight = Color(0xFF527370);

  static const paperDark = Color(0xFF122627);
  static const paperRaisedDark = Color(0xFF1B3638);
  static const inkDark = Color(0xFFFFF3E6);
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.paperDark : AppColors.paperLight;
    final surface = isDark
        ? AppColors.paperRaisedDark
        : AppColors.paperRaisedLight;
    final onSurface = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muted = isDark
        ? AppColors.inkDark.withValues(alpha: 0.68)
        : AppColors.mutedLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentSoft,
      onSecondary: const Color(0xFF2C1C04),
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accentContainer,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? AppColors.accent : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(color: active ? AppColors.accent : muted);
        }),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: onSurface.withValues(alpha: 0.07)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.accent,
        secondarySelectedColor: AppColors.accent,
        labelStyle: Typography.material2021().black.labelMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: Typography.material2021().black.labelMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        side: BorderSide(color: onSurface.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: onSurface.withValues(alpha: 0.08)),
      textTheme: Typography.material2021().black
          .apply(bodyColor: onSurface, displayColor: onSurface)
          .copyWith(
            headlineSmall: Typography.material2021().black.headlineSmall
                ?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
            titleLarge: Typography.material2021().black.titleLarge?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
            titleMedium: Typography.material2021().black.titleMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
            bodySmall: Typography.material2021().black.bodySmall?.copyWith(
              color: muted,
            ),
          ),
    );
  }
}
