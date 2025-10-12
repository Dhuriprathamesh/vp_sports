import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:simple_animations/simple_animations.dart';

enum AuthState { roleSelection, authentication }

// Enum for animated properties in the background
enum _AniProps { color1, color2 }

class LoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  AuthState _authState = AuthState.roleSelection;
  String _userType = '';

  late final AnimationController _authFormController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authFormController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _authFormController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _authFormController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _authFormController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _userType = role;
      _authState = AuthState.authentication;
      _authFormController.forward();
      _errorMessage = null;
      _usernameController.clear();
      _passwordController.clear();
    });
  }

  void _goBackToRoleSelection() {
    // Animate the form out, then change the state once the animation is complete.
    _authFormController.reverse().whenComplete(() {
      if (mounted) {
        setState(() {
          _authState = AuthState.roleSelection;
          _userType = '';
        });
      }
    });
  }

  void _login() {
    final username = _usernameController.text;
    final password = _passwordController.text;

    bool isAdmin = _userType == 'Admin';
    bool isUser = _userType == 'User';

    if ((isAdmin && username == 'admin1' && password == 'admin@123') ||
        (isUser && username == 'user1' && password == 'user@123')) {
      widget.onLoginSuccess(_userType);
    } else {
      setState(() {
        _errorMessage = 'Invalid username or password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _authState == AuthState.roleSelection
                ? _buildRoleSelection()
                : _buildAuthForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    // Wrapped in a SizedBox to ensure the Column takes the full width, allowing proper centering.
    return SizedBox(
      width: double.infinity,
      child: Column(
        key: const ValueKey('role_selection'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, // Center children horizontally
        children: [
          Image.asset(
            'assets/vp_logo.png',
            height: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          LoopAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.02),
            duration: const Duration(seconds: 3),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: const Text(
              'VP Sports Mania',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(blurRadius: 10.0, color: Colors.black38),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
          _buildRoleButton(
            'Continue as User',
            Icons.person,
            () => _selectRole('User'),
          ),
          const SizedBox(height: 20),
          _buildRoleButton(
            'Continue as Admin',
            Icons.admin_panel_settings,
            () => _selectRole('Admin'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    return BackdropFilter(
      key: const ValueKey('auth_form'),
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_userType Login',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please enter your details.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildTextField(
                    controller: _usernameController,
                    hint: 'Username',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 48),
                  _buildLoginButton(),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _goBackToRoleSelection,
                    child: const Text(
                      'Go Back',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Theme.of(context).primaryColor),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.white,
        minimumSize: const Size(250, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _login,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: const Text('Login'),
      ),
    );
  }
}

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final tween = MovieTween()
      ..scene(
              begin: Duration.zero,
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut)
          .tween(_AniProps.color1,
              ColorTween(begin: const Color(0xFF073A30), end: const Color(0xFF0A4F43)))
      ..scene(
              begin: Duration.zero,
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut)
          .tween(_AniProps.color2,
              ColorTween(begin: Theme.of(context).primaryColor, end: const Color(0xFF1E8272)));

    return MirrorAnimationBuilder<Movie>(
      tween: tween,
      duration: const Duration(seconds: 4),
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                value.get(_AniProps.color1),
                value.get(_AniProps.color2),
              ],
            ),
          ),
        );
      },
    );
  }
}

