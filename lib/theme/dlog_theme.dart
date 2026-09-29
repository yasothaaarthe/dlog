import 'package:flutter/material.dart';

import 'dlog_colors.dart';
import 'dlog_text_styles.dart';

class DLogTheme {
  DLogTheme._();

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DLogColors.black,

    colorScheme: const ColorScheme.dark(
      primary: DLogColors.burgundyBright,
      secondary: DLogColors.silver,
      surface: DLogColors.card,
      error: DLogColors.warningRed,
      onPrimary: DLogColors.white,
      onSecondary: DLogColors.black,
      onSurface: DLogColors.white,
      onError: DLogColors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: DLogColors.transparent,
      foregroundColor: DLogColors.white,
      elevation: 0,
      centerTitle: false,
    ),

    textTheme: const TextTheme(
      displayLarge: DLogTextStyles.display,
      headlineLarge: DLogTextStyles.heading,
      titleLarge: DLogTextStyles.subheading,
      bodyLarge: DLogTextStyles.body,
      bodyMedium: DLogTextStyles.bodyMuted,
      labelLarge: DLogTextStyles.button,
      labelSmall: DLogTextStyles.label,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DLogColors.card,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: DLogColors.darkGrey,
          width: 0.7,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: DLogColors.burgundyBright,
          width: 1.2,
        ),
      ),

      hintStyle: DLogTextStyles.bodyMuted,
      labelStyle: DLogTextStyles.bodyMuted,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DLogColors.silverLight,
        foregroundColor: DLogColors.black,
        minimumSize: const Size(double.infinity, 54),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: DLogTextStyles.button,
      ),
    ),
  );
}