import 'package:flutter/material.dart';

class AppColors {
  static const maroon = Color(0xFF8E1616);
  static const maroonDark = Color(0xFF6E0F0F);
  static const emergency = Color(0xFFB91C1C);
  static const gold = Color(0xFFE08A00);
  static const navy = Color(0xFF0B2A6F);
  static const teal = Color(0xFF2BA79A);
  static const purple = Color(0xFF7B61FF);
  static const background = Color(0xFFFAF8F6);
  static const surface = Colors.white;
  static const field = Color(0xFFF3F1F0);
  static const text = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF6B6B70);
  static const border = Color(0xFFE7E3E0);
  static const lancar = Color(0xFF2E9E5B);
  static const sedang = Color(0xFFE0B000);
  static const padat = Color(0xFFC62828);
}

class AppText {
  static const screenTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.maroon);
  static const sectionTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text);
  static const cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.text);
  static const bodyStrong = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: AppColors.textSecondary,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.maroon,
    primary: AppColors.maroon,
    surface: AppColors.surface,
    error: AppColors.emergency,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(bodyMedium: AppText.body, bodyLarge: AppText.body, titleMedium: AppText.cardTitle),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.maroon,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
  );
}
