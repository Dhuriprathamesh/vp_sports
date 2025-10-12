import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'ui/screens/admin/admin_home.dart';
import 'ui/screens/login/login.dart';
import 'ui/screens/user/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _isForBoys = true;
  bool _isAuthenticated = false;
  String _userType = '';

  void _toggleGenderTheme(bool isForBoys) {
    setState(() {
      _isForBoys = isForBoys;
    });
  }

  void _onLoginSuccess(String userType) {
    setState(() {
      _userType = userType;
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _isForBoys ? AppTheme.boysLightTheme : AppTheme.girlsLightTheme;
    
    final systemOverlayStyle = currentTheme.appBarTheme.systemOverlayStyle ?? SystemUiOverlayStyle.light;
    SystemChrome.setSystemUIOverlayStyle(systemOverlayStyle);

    return MaterialApp(
      title: 'VP Sports Mania',
      debugShowCheckedModeBanner: false,
      theme: currentTheme,
      home: _isAuthenticated
        ? (_userType == 'Admin' 
            ? AdminHomeScreen(isForBoys: _isForBoys, onGenderToggle: _toggleGenderTheme)
            : HomeScreen(isForBoys: _isForBoys, onGenderToggle: _toggleGenderTheme))
        : LoginScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}
