import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- Custom Color Palettes ---

// Shared color for AppBar, keeping it green as requested.
const Color _appBarColor = Color(0xFF0A4F43); 

// --- Original Boys Theme Colors (Now for Girls) ---
const Color _blueGradientStart = Color(0xFFE3F2FD); // Light Blue
const Color _purpleGradientEnd = Color(0xFFE1BEE7);   // Light Purple
const Color _blueAccentColor = Color(0xFF42A5F5);   // A brighter blue for accents

// --- Original Girls Theme Colors (Now for Boys) ---
const Color _redGradientStart = Color(0xFFFFEBEE); // Light Red/Pink
const Color _peachGradientEnd = Color(0xFFFFE0B2);   // Light Orange/Peach
const Color _pinkAccentColor = Color(0xFFEC407A);   // A brighter pink for accents

const Color _cardColor = Colors.white;

class AppTheme {

  // --- THEMES ARE SWAPPED HERE ---
  // Static color lists to be used for the gradients in the UI.
  static const List<Color> boysGradientColors = [_redGradientStart, _peachGradientEnd];
  static const List<Color> girlsGradientColors = [_blueGradientStart, _purpleGradientEnd];

  // --- Boys Theme Definition (Using Red/Peach Gradient) ---
  static final ThemeData boysLightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _appBarColor,
    scaffoldBackgroundColor: _redGradientStart, // Sets the base color for screen transitions
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: _appBarColor,
      elevation: 0, // Set elevation to 0 for a flatter look
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF073A30), // A darker shade of the green AppBar
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      // Reduced font size to prevent overflow issues
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), 
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _appBarColor, // Match the selected item with the AppBar color
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
    ),
    cardColor: _cardColor,
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
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: _pinkAccentColor),
  );

  // --- Girls Theme Definition (Using Blue/Purple Gradient) ---
  static final ThemeData girlsLightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _appBarColor,
    scaffoldBackgroundColor: _blueGradientStart, // Base color for the gradient
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: _appBarColor,
      elevation: 0, // Set elevation to 0 for a flatter look
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF073A30), // Same dark green status bar
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      // Reduced font size to prevent overflow issues
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _appBarColor,
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
    ),
    cardColor: _cardColor,
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
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: _blueAccentColor),
  );
}
