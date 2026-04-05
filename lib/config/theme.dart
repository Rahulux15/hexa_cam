import 'package:flutter/material.dart';

class AppTheme {
  // Colors - Exact from specification
  static const Color primary = Color(0xFF6366F1);      // #6366f1
  static const Color primaryDark = Color(0xFF4F46E5);  // #4f46e5
  static const Color primaryLight = Color(0xFF818CF8); // #818cf8
  static const Color secondary = Color(0xFF8B5CF6);    // #8b5cf6
  static const Color accent = Color(0xFF06B6D4);       // #06b6d4
  static const Color success = Color(0xFF10B981);      // #10b981
  static const Color warning = Color(0xFFF59E0B);      // #f59e0b
  static const Color danger = Color(0xFFEF4444);       // #ef4444

  // Background colors
  static const Color bgPrimary = Color(0xFF060824);    // deep navy
  static const Color bgSecondary = Color(0xFF0A0F32);  // indigo navy
  static const Color bgTertiary = Color(0xFF111842);   // elevated navy
  static const Color bgCard = Color(0xFF181C4A);       // card navy
  static const Color bgCardSoft = Color(0xFF232454);
  static const Color bgCardMuted = Color(0xFF1A2348);
  static const Color bgOverlay = Color(0xF20A0F32);    // overlay navy

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);   // #f8fafc
  static const Color textSecondary = Color(0xFFCBD5E1); // #cbd5e1
  static const Color textMuted = Color(0xFF94A3B8);     // #94a3b8
  static const Color textDisabled = Color(0xFF64748B);  // #64748b

  // Border colors
  static const Color borderColor = Color(0xFF3A4178);
  static const Color borderLight = Color(0xFF5963A8);
  static const Color borderActive = primary;            // var(--color-primary)

  // Gradients - Exact from specification
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
    stops: [0.0, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF060824), Color(0xFF0A0F32), Color(0xFF16285A)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF21B2154), Color(0xF2141A46)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient folderIconGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
    stops: [0.0, 1.0],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient saveDialogGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    stops: [0.0, 1.0],
  );

  // Shadows - Exact from specification
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x33200000),
    offset: Offset(0, 1),
    blurRadius: 2,
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x4C000000),
    offset: Offset(0, 4),
    blurRadius: 6,
  );

  static const BoxShadow shadowLg = BoxShadow(
    color: Color(0x59000000),
    offset: Offset(0, 10),
    blurRadius: 15,
  );

  static const BoxShadow shadowXl = BoxShadow(
    color: Color(0x66000000),
    offset: Offset(0, 20),
    blurRadius: 25,
  );

  static const BoxShadow shadowGlow = BoxShadow(
    color: Color(0x4D6366F1),
    offset: Offset(0, 0),
    blurRadius: 20,
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x4C060824),
      offset: Offset(0, 14),
      blurRadius: 28,
    ),
  ];

  // Border radius - Exact from specification
  static const double radiusSm = 6.0;   // 0.375rem
  static const double radiusMd = 8.0;   // 0.5rem
  static const double radiusLg = 12.0;  // 0.75rem
  static const double radiusXl = 16.0;  // 1rem
  static const Radius radiusFull = Radius.circular(9999);

  // Transitions - Exact timings from specification
  static const Duration transitionFast = Duration(milliseconds: 150);
  static const Duration transitionBase = Duration(milliseconds: 250);
  static const Duration transitionSlow = Duration(milliseconds: 350);

  // Typography - Exact from specification
  static const TextStyle heading1 = TextStyle(
    fontSize: 32, // 2rem
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24, // 1.5rem
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20, // 1.25rem
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: textPrimary,
  );

  static const TextStyle heading4 = TextStyle(
    fontSize: 18, // 1.125rem
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16, // 1rem
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: textSecondary,
  );

  // Icon sizes - Matching specification
  static const double iconXs = 12.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 28.0;
  static const double icon2Xl = 32.0;
  static const double icon3Xl = 40.0;

  // Spacing - Exact from specification
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // Camera action button styling
  static ButtonStyle cameraActionButtonStyle({bool isActive = false, bool isCapture = false, bool isRecording = false}) {
    Color backgroundColor;
    Color borderColor;

    if (isRecording) {
      backgroundColor = const Color(0x23EF4444);
      borderColor = const Color(0x72F87171);
    } else if (isCapture) {
      backgroundColor = const Color(0x0DFFFFFF);
      borderColor = const Color(0x82FFFFFF);
    } else if (isActive) {
      backgroundColor = const Color(0x23A78BFA);
      borderColor = const Color(0x60945CFA);
    } else {
      backgroundColor = Colors.transparent;
      borderColor = const Color(0x24FFFFFF);
    }

    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(backgroundColor),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      side: WidgetStateProperty.all(BorderSide(color: borderColor, width: isCapture ? 3 : 1)),
      shape: WidgetStateProperty.all(const CircleBorder()),
      padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
      shadowColor: WidgetStateProperty.all(isRecording ? danger : Colors.black),
      elevation: WidgetStateProperty.all(isRecording ? 6 : 4),
    );
  }

  // Panel decoration with backdrop blur
  static BoxDecoration panelDecoration({
    LinearGradient? gradient,
    Color? backgroundColor,
    double borderRadius = 20,
    Color? borderColor,
  }) {
    return BoxDecoration(
      gradient: gradient ?? cardGradient,
      backgroundBlendMode: BlendMode.overlay,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? const Color(0x338B5CF6),
        width: 1,
      ),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration softCardDecoration({
    BorderRadius? borderRadius,
    Color? color,
    Color? border,
  }) {
    return BoxDecoration(
      color: color ?? bgCardSoft,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(color: border ?? const Color(0xFF343B7A)),
      boxShadow: cardShadow,
    );
  }

  // Dark theme - Updated with specification colors
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: bgCard,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgOverlay,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textSecondary,
        side: const BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: const BorderSide(color: primary),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
    ),
    textTheme: const TextTheme(
      headlineLarge: heading1,
      headlineMedium: heading2,
      headlineSmall: heading3,
      titleLarge: heading4,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textSecondary,
      ),
    ),
  );
}
