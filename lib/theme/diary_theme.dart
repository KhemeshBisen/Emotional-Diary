// lib/theme/diary_theme.dart
import 'package:flutter/material.dart';

class DiaryTheme {
  // Emotion-based colors
  static const Color emotionHappy = Color(0xFF10B981); // Green
  static const Color emotionSad = Color(0xFF6366F1); // Indigo
  static const Color emotionAngry = Color(0xFFEF4444); // Red
  static const Color emotionAnxious = Color(0xFFF59E0B); // Amber
  static const Color emotionCalm = Color(0xFF8B5CF6); // Purple

  // Primary colors
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFFA78BFA); // Light purple

  // Neutral colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Gradients
  static final primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final diaryGradient = LinearGradient(
    colors: [
      Color(0xFF6366F1).withOpacity(0.9),
      Color(0xFF8B5CF6).withOpacity(0.6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        background: background,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Emotion color map
  static Color getEmotionColor(String emotion) {
    final e = emotion.toLowerCase();
    if (e.contains('happy') || e.contains('joy')) return emotionHappy;
    if (e.contains('sad') || e.contains('blue')) return emotionSad;
    if (e.contains('angry') || e.contains('rage')) return emotionAngry;
    if (e.contains('anx') || e.contains('stress') || e.contains('worry')) {
      return emotionAnxious;
    }
    if (e.contains('calm') || e.contains('peace') || e.contains('relax')) {
      return emotionCalm;
    }
    return primary;
  }

  // Emotion icon map
  static IconData getEmotionIcon(String emotion) {
    final e = emotion.toLowerCase();
    if (e.contains('happy') || e.contains('joy'))
      return Icons.sentiment_very_satisfied_rounded;
    if (e.contains('sad') || e.contains('blue'))
      return Icons.sentiment_very_dissatisfied_rounded;
    if (e.contains('angry') || e.contains('rage'))
      return Icons.mood_bad_rounded;
    if (e.contains('anx') || e.contains('stress') || e.contains('worry')) {
      return Icons.sentiment_neutral_rounded;
    }
    if (e.contains('calm') || e.contains('peace') || e.contains('relax'))
      return Icons.spa_rounded;
    return Icons.sentiment_satisfied_rounded;
  }
}
