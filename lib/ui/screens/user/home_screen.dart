import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/app_theme.dart';
import 'sports_details.dart'; // Import the new screen
import 'leaderboard_screen.dart'; // Import the leaderboard screen

// The main screen of the application.
class HomeScreen extends StatelessWidget {
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const HomeScreen({
    required this.isForBoys,
    required this.onGenderToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _HomeScreenView(
      isForBoys: isForBoys,
      onGenderToggle: onGenderToggle,
    );
  }
}

// Using a StatefulWidget internally to manage local state and animations.
class _HomeScreenView extends StatefulWidget {
  final bool isForBoys;
  final Function(bool) onGenderToggle;
  
  const _HomeScreenView({
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<_HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<_HomeScreenView> with TickerProviderStateMixin {
  int _bottomNavIndex = 0;
  bool _isProfileMenuOpen = false;
  
  // State to track which sports category is currently visible.
  String _selectedSportsCategory = 'Outdoor';

  late final ScrollController _scrollController;
  double _parallaxOffset = 0.0;
  
  // --- Animation Properties for the Profile Menu ---
  late final AnimationController _profileMenuController;
  late final Animation<Offset> _profileMenuSlideAnimation;
  late final Animation<double> _profileMenuFadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // --- Initializing the Animation Controller ---
    _profileMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _profileMenuSlideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero
    ).animate(CurvedAnimation(
      parent: _profileMenuController,
      curve: Curves.easeOutCubic,
    ));

    _profileMenuFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _profileMenuController,
        curve: Curves.easeOut,
      ),
    );
  }

  void _onScroll() {
    setState(() {
      _parallaxOffset = _scrollController.offset * 0.25;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _profileMenuController.dispose();
    super.dispose();
  }
  
  void _toggleProfileMenu() {
    setState(() {
      _isProfileMenuOpen = !_isProfileMenuOpen;
    });
    if (_isProfileMenuOpen) {
      _profileMenuController.forward();
    } else {
      _profileMenuController.reverse();
    }
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys
      ? AppTheme.boysGradientColors
      : AppTheme.girlsGradientColors;

    return Stack(
      children: [
        Scaffold(
          appBar: _buildAppBar(context),
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _buildMainContent(context),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(context),
        ),
        if (_isProfileMenuOpen)
          FadeTransition(
            opacity: _profileMenuFadeAnimation,
            child: GestureDetector(
              onTap: _toggleProfileMenu,
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
        _buildAnimatedProfileMenu(),
      ],
    );
  }

  // --- MODIFIED ---
  // The AppBar now places the logo on the left and resolves the overflow.
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      // Use the leading property for the logo on the far left.
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Image.asset(
          'assets/vp_logo.png', // Ensure this path is correct in your pubspec.yaml
          height: 30,
          color: Colors.white,
        ),
      ),
      // The title is now just the text, which will align next to the leading widget.
      title: const Text('Sports Mania'),
      // Actions remain on the right.
      actions: [
        _buildProfileIcon(context),
      ],
      // This is false by default when a leading widget is present.
      centerTitle: false, 
    );
  }

  Widget _buildProfileIcon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
        onPressed: _toggleProfileMenu,
        icon: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: Icon(Icons.person, color: Theme.of(context).primaryColor),
        ),
        splashRadius: 24,
      ),
    );
  }

  Widget _buildAnimatedProfileMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Positioned(
      right: 16,
      top: 60,
      child: FadeTransition(
        opacity: _profileMenuFadeAnimation,
        child: SlideTransition(
          position: _profileMenuSlideAnimation,
          child: IgnorePointer(
            ignoring: !_isProfileMenuOpen,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: screenWidth * 0.55, // Slightly wider for better text fit
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuItem(Icons.account_circle, 'My Account', () {}),
                    _buildMenuItem(Icons.settings, 'Settings', () {}),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildMenuItem(Icons.logout, 'Log Out', () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        _toggleProfileMenu();
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: $title')),
        );
      },
      borderRadius: title == 'My Account' 
        ? const BorderRadius.vertical(top: Radius.circular(12)) 
        : title == 'Log Out'
        ? const BorderRadius.vertical(bottom: Radius.circular(12))
        : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[700]),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveMatchesSection(context),
          _buildCategoryToggle(context),
          
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _selectedSportsCategory == 'Outdoor'
                ? _buildSportsGrid(
                    context,
                    key: const ValueKey('outdoor'),
                    title: 'Outdoor Sports',
                    sports: _getOutdoorSports(),
                    iconColor: Colors.orange.shade700,
                  )
                : _buildSportsGrid(
                    context,
                    key: const ValueKey('indoor'),
                    title: 'Indoor Sports',
                    sports: _getIndoorSports(),
                    iconColor: Colors.indigo.shade600,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildCategoryButton(
              context,
              'Outdoor',
              Icons.wb_sunny,
              _selectedSportsCategory == 'Outdoor',
              () => setState(() => _selectedSportsCategory = 'Outdoor'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildCategoryButton(
              context,
              'Indoor',
              Icons.roofing,
              _selectedSportsCategory == 'Indoor',
              () => setState(() => _selectedSportsCategory = 'Indoor'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, String label, IconData icon, bool isSelected, VoidCallback onPressed) {
    final primaryColor = Theme.of(context).primaryColor;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: isSelected ? Colors.white : primaryColor),
      label: Text(label, style: TextStyle(fontSize: 16, color: isSelected ? Colors.white : primaryColor)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isSelected ? 4 : 1,
        backgroundColor: isSelected ? primaryColor : Colors.white.withOpacity(0.8),
        side: isSelected ? BorderSide.none : BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildLiveMatchesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            'Live Matches',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black.withOpacity(0.8)),
          ),
        ),
        SizedBox(
          height: 160, // Increased height for better padding
          child: Transform.translate(
            offset: Offset(-_parallaxOffset, 0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12 + _parallaxOffset),
              itemCount: 5,
              itemBuilder: (context, index) {
                return FadeInAnimation(
                  delay: Duration(milliseconds: 100 + index * 50),
                  child: _buildLiveMatchCard(context, index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLiveMatchCard(BuildContext context, int index) {
      return Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cricket • T20 Match ${index + 1}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(20)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                  )
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('TEAM A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text('172/5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
              const SizedBox(height: 8), // Increased spacing
               Row(
                children: [
                  const Text('TEAM B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text('140/8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
              const Spacer(),
              Text('Team A leads by 32 runs.', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor)),
            ],
          ),
        ),
      );
  }
  
  Widget _buildSportsGrid(BuildContext context, { required Key key, required String title, required List<Map<String, dynamic>> sports, required Color iconColor }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black.withOpacity(0.8))),
          const SizedBox(height: 12),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05,
            ),
            itemCount: sports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final sport = sports[index];
              return FadeInAnimation(
                delay: Duration(milliseconds: 150 + index * 60),
                child: _buildSportCard(context, name: sport['name'], icon: sport['icon'], iconColor: iconColor),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSportCard(BuildContext context, {String? name, IconData? icon, required Color iconColor}) {
    if (name == null || icon == null) {
      return const SizedBox.shrink(); // Use SizedBox.shrink() instead of a placeholder container
    }
    
    return Material(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => SportsDetailsScreen(
              sportName: name,
              sportIcon: icon,
              isForBoys: widget.isForBoys,
              onGenderToggle: widget.onGenderToggle,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.ease;

              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(tween),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ));
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: iconColor.withOpacity(0.2),
        highlightColor: iconColor.withOpacity(0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 10),
            Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) {
        if (index == 2) { // Leaderboard is at index 2
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => LeaderboardScreen(isForBoys: widget.isForBoys),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.ease;
                final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys);
        } else {
          setState(() { _bottomNavIndex = index; });
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
        const BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
        BottomNavigationBarItem(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              widget.isForBoys ? Icons.male : Icons.female,
              key: ValueKey<bool>(widget.isForBoys),
            ),
          ),
          label: widget.isForBoys ? 'Boys' : 'Girls',
        ),
      ],
    );
  }
  
  List<Map<String, dynamic>> _getOutdoorSports() => [
    {'name': 'Cricket', 'icon': Icons.sports_cricket}, {'name': 'Football', 'icon': Icons.sports_soccer},
    {'name': 'Volleyball', 'icon': Icons.sports_volleyball}, {'name': 'Kabaddi', 'icon': Icons.sports_kabaddi},
    {'name': 'Athletics', 'icon': Icons.directions_run}, {'name': null, 'icon': null},
  ];
  
  List<Map<String, dynamic>> _getIndoorSports() => [
    {'name': 'Chess', 'icon': Icons.gamepad_outlined}, {'name': 'Table Tennis', 'icon': Icons.sports_tennis},
    {'name': 'Carrom', 'icon': Icons.album}, {'name': 'Badminton', 'icon': Icons.sports},
  ];
}

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  
  const FadeInAnimation({required this.child, this.delay = Duration.zero, super.key});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

