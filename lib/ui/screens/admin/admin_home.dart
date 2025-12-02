import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import 'admin_sports_details.dart'; 
import 'admin_leaderboard.dart';
import 'admin_schedule_screen.dart'; // Import the dedicated Admin Schedule Screen
import '../../widgets/live_matches_carousel.dart'; 

class AdminHomeScreen extends StatelessWidget {
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const AdminHomeScreen({
    super.key,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _AdminHomeScreenView(
      isForBoys: isForBoys,
      onGenderToggle: onGenderToggle,
    );
  }
}

class _AdminHomeScreenView extends StatefulWidget {
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const _AdminHomeScreenView({
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<_AdminHomeScreenView> createState() => _AdminHomeScreenViewState();
}

class _AdminHomeScreenViewState extends State<_AdminHomeScreenView>
    with TickerProviderStateMixin {
  int _bottomNavIndex = 0;
  bool _isProfileMenuOpen = false;
  String _selectedSportsCategory = 'Outdoor';
  late final ScrollController _scrollController;
  late final AnimationController _profileMenuController;
  late final Animation<Offset> _profileMenuSlideAnimation;
  late final Animation<double> _profileMenuFadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _profileMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _profileMenuSlideAnimation = Tween<Offset>(
            begin: const Offset(0.5, 0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _profileMenuController,
      curve: Curves.easeOutCubic,
    ));

    _profileMenuFadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _profileMenuController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
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

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Image.asset(
          'assets/vp_logo.png',
          height: 30,
          color: Colors.white,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.sports, color: Colors.white),
        ),
      ),
      title: const Text('Sports Mania Admin'),
      actions: [
        _buildProfileIcon(context),
      ],
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
                width: screenWidth * 0.55,
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LIVE MATCHES CAROUSEL ---
          // Passing isForBoys ensures the carousel fetches the correct gender's data
          LiveMatchesCarousel(
            isForBoys: widget.isForBoys,
            isAdmin: true, 
            onGenderToggle: widget.onGenderToggle,
          ),
          
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
                    iconColor: const Color.fromARGB(255, 255, 255, 255),
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

  Widget _buildCategoryButton(BuildContext context, String label, IconData icon,
      bool isSelected, VoidCallback onPressed) {
    final primaryColor = Theme.of(context).primaryColor;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon:
          Icon(icon, size: 20, color: isSelected ? Colors.white : primaryColor),
      label: Text(label,
          style: TextStyle(
              fontSize: 16,
              color: isSelected ? Colors.white : primaryColor)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isSelected ? 4 : 1,
        backgroundColor:
            isSelected ? primaryColor : Colors.white.withOpacity(0.8),
        side: isSelected
            ? BorderSide.none
            : BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildSportsGrid(BuildContext context,
      {required Key key,
      required String title,
      required List<Map<String, dynamic>> sports,
      required Color iconColor}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black.withOpacity(0.8))),
          const SizedBox(height: 12),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: sports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final sport = sports[index];
              final String? sportName = sport['name'];
              final IconData? sportIcon = sport['icon'];

              if (sportName == null) return const SizedBox();

              // Get the background image asset for this sport
              final String? bgImage = _getAssetImage(sportName);

              return FadeInAnimation(
                delay: Duration(milliseconds: 150 + index * 60),
                child: _SportCard(
                  name: sportName,
                  icon: sportIcon!,
                  iconColor: iconColor,
                  backgroundImage: bgImage, // Pass the image here
                  onTap: () => _navigateToDetails(context, sportName, sportIcon),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Helper to Map Sport Name to Asset Image ---
  String? _getAssetImage(String sportName) {
    if (widget.isForBoys) {
      return _getBoysAssetImage(sportName);
    } else {
      return _getGirlsAssetImage(sportName);
    }
  }

  String? _getBoysAssetImage(String sportName) {
    switch (sportName) {
      case 'Cricket': return 'assets/cricket.png';
      case 'Football': return 'assets/football.png';
      case 'Volleyball': return 'assets/volleyball.png';
      case 'Kabaddi': return 'assets/kabaddi.jpeg';
      case 'Basketball': return 'assets/basketball.png';
      case 'Athletics': return 'assets/athletics.png';
      case 'Chess': return 'assets/chess.png';
      case 'Carrom': return 'assets/carrom.png';
      case 'Table Tennis': return 'assets/table_tennis.png';
      case 'Badminton': return 'assets/badminton.png';
      default: return null;
    }
  }

  // --- GIRLS SPECIFIC IMAGES ---
  String? _getGirlsAssetImage(String sportName) {
    switch (sportName) {
      case 'Cricket': return 'assets/girls_cricket.png'; 
      case 'Dodgeball': return 'assets/dodgeball.png';
      case 'Volleyball': return 'assets/girls_volleyball.png';
      case 'Kabaddi': return 'assets/girls_kabaddi.jpeg';
      case 'Basketball': return 'assets/girls_basketball.png';
      case 'Athletics': return 'assets/girls_athletics.png';
      case 'Chess': return 'assets/girls_chess.png';
      case 'Carrom': return 'assets/girls_carrom.png';
      case 'Table Tennis': return 'assets/girls_table_tennis.png';
      case 'Badminton': return 'assets/girls_badminton.png';
      default: return null;
    }
  }

  void _navigateToDetails(BuildContext context, String name, IconData icon) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => AdminSportsDetailsScreen(
        sportName: name,
        sportIcon: icon,
        isForBoys: widget.isForBoys,
        onGenderToggle: widget.onGenderToggle,
      ),
    ));
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) {
        if (index == 1) { // SCHEDULE PAGE
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AdminScheduleScreen(isForBoys: widget.isForBoys)));
        } else if (index == 2) {
          // Leaderboard is at index 2
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AdminLeaderboardScreen(
                isForBoys: widget.isForBoys,
                onGenderToggle: widget.onGenderToggle,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.ease;
                final tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
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
          setState(() {
            _bottomNavIndex = index;
          });
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.schedule), label: 'Schedule'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
        BottomNavigationBarItem(
          icon: Icon(widget.isForBoys ? Icons.male : Icons.female),
          label: widget.isForBoys ? 'Boys' : 'Girls',
        ),
      ],
    );
  }

  // --- DYNAMIC SPORT LIST LOGIC ---
  List<Map<String, dynamic>> _getOutdoorSports() {
    return widget.isForBoys ? _getBoysOutdoorSports() : _getGirlsOutdoorSports();
  }

  List<Map<String, dynamic>> _getIndoorSports() {
    return widget.isForBoys ? _getBoysIndoorSports() : _getGirlsIndoorSports();
  }

  // --- Separate Functions for Boys ---
  List<Map<String, dynamic>> _getBoysOutdoorSports() {
    return [
      {'name': 'Cricket', 'icon': Icons.sports_cricket},
      {'name': 'Football', 'icon': Icons.sports_soccer},
      {'name': 'Volleyball', 'icon': Icons.sports_volleyball},
      {'name': 'Kabaddi', 'icon': Icons.sports_kabaddi},
      {'name': 'Athletics', 'icon': Icons.directions_run},
      {'name': 'Basketball', 'icon': Icons.sports_basketball},
    ];
  }

  List<Map<String, dynamic>> _getBoysIndoorSports() {
    return [
      {'name': 'Chess', 'icon': Icons.gamepad_outlined},
      {'name': 'Table Tennis', 'icon': Icons.sports_tennis},
      {'name': 'Carrom', 'icon': Icons.album},
      {'name': 'Badminton', 'icon': Icons.filter_vintage},
    ];
  }

  // --- Separate Functions for Girls ---
  List<Map<String, dynamic>> _getGirlsOutdoorSports() {
    return [
      {'name': 'Cricket', 'icon': Icons.sports_cricket},
      {'name': 'Dodgeball', 'icon': Icons.sports_handball},
      {'name': 'Volleyball', 'icon': Icons.sports_volleyball},
      {'name': 'Kabaddi', 'icon': Icons.sports_kabaddi},
      {'name': 'Athletics', 'icon': Icons.directions_run},
      {'name': 'Basketball', 'icon': Icons.sports_basketball},
    ];
  }

  List<Map<String, dynamic>> _getGirlsIndoorSports() {
    return [
      {'name': 'Chess', 'icon': Icons.gamepad_outlined},
      {'name': 'Table Tennis', 'icon': Icons.sports_tennis},
      {'name': 'Carrom', 'icon': Icons.album},
      {'name': 'Badminton', 'icon': Icons.filter_vintage},
    ];
  }
}

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeInAnimation(
      {required this.child, this.delay = Duration.zero, super.key});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with TickerProviderStateMixin {
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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
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

// --- Shared Sport Card Component ---
class _SportCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final String? backgroundImage;

  const _SportCard({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: iconColor.withOpacity(0.2),
        highlightColor: iconColor.withOpacity(0.1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image logic
            if (backgroundImage != null)
              Opacity(
                opacity: 0.6, // Reduced opacity for background effect
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    backgroundImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback safely if image is missing
                      return const SizedBox();
                    },
                  ),
                ),
              ),

            // Foreground Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: iconColor),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}