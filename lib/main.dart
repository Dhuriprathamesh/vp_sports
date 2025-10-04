import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'ui/screens/user/home_screen.dart';

void main() {
  // Ensures that widget binding is initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setting preferred orientations for a consistent look.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // State to track whether the boys or girls theme is active.
  bool _isForBoys = true;

  // This function is called from the HomeScreen to update the theme.
  void _toggleGenderTheme(bool isForBoys) {
    setState(() {
      _isForBoys = isForBoys;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically select the theme based on the current state.
    final currentTheme = _isForBoys ? AppTheme.boysLightTheme : AppTheme.girlsLightTheme;
    
    // Set the status bar color to match the AppBar of the current theme.
    SystemChrome.setSystemUIOverlayStyle(currentTheme.appBarTheme.systemOverlayStyle!);

    return MaterialApp(
      title: 'VP Sports',
      debugShowCheckedModeBanner: false,
      
      // The theme is dynamically selected based on the _isForBoys flag.
      theme: currentTheme,
      
      // Pass the current state and the callback function to the HomeScreen.
      home: HomeScreen(
        isForBoys: _isForBoys,
        onGenderToggle: _toggleGenderTheme,
      ),
    );
  }
}

