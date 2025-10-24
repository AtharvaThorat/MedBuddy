import 'package:flutter/material.dart';

class AppTheme {
  static const Color lightGreen = Color(0xFFE1F7D5);
  static const Color lightPurple = Color(0xFFC9C9FF);
  static const Color darkPurple = Color(0xFFF1CBFF);
  static const Color lightPink = Color(0xFFFFBDBD);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: lightPurple,
        secondary: darkPurple,
        tertiary: lightPink,
        background: lightGreen,
        surface: Colors.white,
        onPrimary: Colors.black87,
        onSecondary: Colors.black87,
        onTertiary: Colors.black87,
        onBackground: Colors.black87,
        onSurface: Colors.black87,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        bodySmall: TextStyle(fontSize: 14, color: Colors.black87),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        labelStyle: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkPurple,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPurple,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: lightPurple, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.black26,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightPurple,
        foregroundColor: Colors.black87,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        iconTheme: IconThemeData(
          color: Colors.black87,
          size: 28,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: lightPurple.withOpacity(0.5),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: MaterialStateProperty.all(
          const IconThemeData(
            size: 28,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkPurple,
        contentTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.black87,
        size: 24,
      ),
      fontFamily: 'Roboto',
    );
  }
}
