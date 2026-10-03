import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: Colors.blue.shade800,
      secondary: Colors.blue.shade600,
      tertiary: Colors.teal.shade400,
      surface: Colors.white,
      background: Colors.grey.shade100,
      error: Colors.red.shade700,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.blue.shade100,
      onSurface: Colors.black,
      onBackground: Colors.black,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.blue.shade800,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
  );
}
