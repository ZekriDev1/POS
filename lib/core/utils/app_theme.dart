import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFFF7A00);
  static const Color primaryHover = Color(0xFFFF9433);
  static const Color primarySelected = Color(0xFFE06E00);
  static const Color bgColor = Color(0xFFF5F3F2);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color sidebarBg = Color(0xFF1A2B49);
  static const Color textMain = Color(0xFF1A2B49);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFE74C3C);

  static ThemeData get theme => ThemeData(
        useMaterial3: false,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: bgColor,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        appBarTheme: const AppBarTheme(
          backgroundColor: cardBg,
          foregroundColor: textMain,
          elevation: 0,
        ),
      );

  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: 16,
        offset: const Offset(0, 4),
      );
}
