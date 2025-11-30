import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:simple_animations/simple_animations.dart';
import 'package:video_player/video_player.dart'; // Ensure you ran 'flutter pub add video_player'

enum AuthState { roleSelection, authentication }

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

  // --- Video Controller (Nullable for safety) ---
  VideoPlayerController? _videoController;

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

    // --- Initialize Video Safely ---
    _initializeVideo();
  }

  void _initializeVideo() {
    // Use standard asset path. Ensure 'assets/login_bg.mp4' exists and is in pubspec.yaml
    _videoController = VideoPlayerController.asset('assets/vd.mp4')
      ..initialize().then((_) {
        if (mounted) {
          _videoController?.play();
          _videoController?.setLooping(true);
          _videoController?.setVolume(0); // Mute is often required for web autoplay
          setState(() {});
        }
      }).catchError((error) {
        debugPrint("Video load failed (showing fallback): $error");
        // If video fails (codec error or 404), set to null to show gradient background
        if (mounted) {
          setState(() => _videoController = null);
        }
      });
  }

  @override
  void dispose() {
    _authFormController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _videoController?.dispose();
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
      backgroundColor: const Color(0xFF073A30),
      body: Stack(
        children: [
          // --- Layer 1: Video Background ---
          if (_videoController != null && _videoController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: Opacity(
                    opacity: 0.4,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ),

          // --- Layer 2: Gradient Overlay ---
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF073A30).withOpacity(0.45),
                  const Color(0xFF0A4F43).withOpacity(0.4),
                ],
              ),
            ),
          ),

          // --- Layer 3: Content ---
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
    return SizedBox(
      width: double.infinity,
      child: Column(
        key: const ValueKey('role_selection'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/vp_logo.png',
            height: 60,
            color: Colors.white,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.sports_soccer, size: 60, color: Colors.white);
            },
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
      filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
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