import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- Custom Color Palettes ---

// Shared color for AppBar, keeping it green as requested.
const Color _appBarColor = Color(0xFF0A4F43); 

// --- Boys Theme Colors ---
const Color _boyGradientStart = Color(0xFFE3F2FD); // Light Blue
const Color _boyGradientEnd = Color(0xFFE1BEE7);   // Light Purple
const Color _boyAccentColor = Color(0xFF42A5F5);   // A brighter blue for accents
const Color _boyCardColor = Colors.white;

// --- Girls Theme Colors ---
const Color _girlGradientStart = Color(0xFFFFEBEE); // Light Red/Pink
const Color _girlGradientEnd = Color(0xFFFFE0B2);   // Light Orange/Peach
const Color _girlAccentColor = Color(0xFFEC407A);   // A brighter pink for accents
const Color _girlCardColor = Colors.white;

class AppTheme {

  // Static color lists to be used for the gradients in the UI.
  static const List<Color> boysGradientColors = [_boyGradientStart, _boyGradientEnd];
  static const List<Color> girlsGradientColors = [_girlGradientStart, _girlGradientEnd];

  // --- Boys Theme Definition ---
  static final ThemeData boysLightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _appBarColor,
    scaffoldBackgroundColor: _boyGradientStart, // Sets the base color for screen transitions
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: _appBarColor,
      elevation: 4,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF073A30), // A darker shade of the green AppBar
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _appBarColor, // Match the selected item with the AppBar color
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
    ),
    cardColor: _boyCardColor,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
      )
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black87),
    ),
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: _boyAccentColor),
  );

  // --- Girls Theme Definition ---
  static final ThemeData girlsLightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _appBarColor,
    scaffoldBackgroundColor: _girlGradientStart, // Base color for the gradient
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: _appBarColor,
      elevation: 4,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF073A30), // Same dark green status bar
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _appBarColor,
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
    ),
    cardColor: _girlCardColor,
     elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
      )
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black87),
    ),
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: _girlAccentColor),
  );
}

