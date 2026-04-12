import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: AppColors.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHighest,
        hintStyle: const TextStyle(color: AppColors.inverseOnSurface),
        prefixIconColor: AppColors.outline,
        suffixIconColor: AppColors.outline,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
