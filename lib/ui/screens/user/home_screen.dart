import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import 'sports_details.dart'; 
import 'leaderboard_screen.dart'; 
import '../../widgets/live_matches_carousel.dart'; 

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

class _HomeScreenViewState extends State<_HomeScreenView>
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

    _profileMenuFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
              child: Container(color: Colors.black.withOpacity(0.4)),
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
      title: const Text('Sports Mania'),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LIVE MATCHES CAROUSEL ---
          // Passing isForBoys ensures the carousel fetches the correct gender's data
          LiveMatchesCarousel(
            isForBoys: widget.isForBoys,
            isAdmin: false, // User Mode
            onGenderToggle: widget.onGenderToggle,
          ),
          
          _buildCategoryToggle(context),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
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

  Widget _buildCategoryButton(BuildContext context, String label, IconData icon,
      bool isSelected, VoidCallback onPressed) {
    final primaryColor = Theme.of(context).primaryColor;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: isSelected ? Colors.white : primaryColor),
      label: Text(label,
          style: TextStyle(fontSize: 16, color: isSelected ? Colors.white : primaryColor)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isSelected ? 4 : 1,
        backgroundColor: isSelected ? primaryColor : Colors.white.withOpacity(0.8),
        side: isSelected ? BorderSide.none : BorderSide(color: primaryColor.withOpacity(0.5)),
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
              return FadeInAnimation(
                delay: Duration(milliseconds: 150 + index * 60),
                child: _SportCard(
                  name: sport['name'],
                  icon: sport['icon'],
                  iconColor: iconColor,
                  backgroundImage: _getAssetImage(sport['name']),
                  onTap: () => _navigateToDetails(context, sport['name'], sport['icon']),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- DYNAMIC SPORT LIST LOGIC ---
  List<Map<String, dynamic>> _getOutdoorSports() {
    List<Map<String, dynamic>> list = [
        {'name': 'Cricket', 'icon': Icons.sports_cricket},
        {'name': 'Volleyball', 'icon': Icons.sports_volleyball},
        {'name': 'Kabaddi', 'icon': Icons.sports_kabaddi},
        {'name': 'Athletics', 'icon': Icons.directions_run},
        {'name': 'Basketball', 'icon': Icons.sports_basketball}, 
    ];

    // Conditional insertion: Football for Boys, Dodgeball for Girls
    if (widget.isForBoys) {
       list.insert(1, {'name': 'Football', 'icon': Icons.sports_soccer});
    } else {
       list.insert(1, {'name': 'Dodgeball', 'icon': Icons.sports_handball}); // Uses Handball icon for Dodgeball
    }
    
    return list;
  }

  List<Map<String, dynamic>> _getIndoorSports() => [
        {'name': 'Chess', 'icon': Icons.gamepad_outlined},
        {'name': 'Table Tennis', 'icon': Icons.sports_tennis}, 
        {'name': 'Carrom', 'icon': Icons.album},
        {'name': 'Badminton', 'icon': Icons.filter_vintage}, 
      ];

  String? _getAssetImage(String sportName) {
    switch (sportName) {
      case 'Cricket': return 'assets/cricket.png';
      case 'Football': return 'assets/football.png';
      case 'Volleyball': return 'assets/volleyball.png';
      case 'Kabaddi': return 'assets/kabaddi.jpeg';
      // No specific asset for Dodgeball, will use default card style
      default: return null;
    }
  }

  void _navigateToDetails(BuildContext context, String name, IconData icon) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SportsDetailsScreen(
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
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ));
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) {
        if (index == 2) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => LeaderboardScreen(isForBoys: widget.isForBoys)));
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys);
        } else {
          setState(() => _bottomNavIndex = index);
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
        const BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
        BottomNavigationBarItem(
          icon: Icon(widget.isForBoys ? Icons.male : Icons.female),
          label: widget.isForBoys ? 'Boys' : 'Girls',
        ),
      ],
    );
  }
}

class FadeInAnimation extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const FadeInAnimation({required this.child, this.delay = Duration.zero, super.key});
  
  @override
  Widget build(BuildContext context) {
    return child; 
  }
}

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
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backgroundImage != null)
              Opacity(
                opacity: 0.3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(backgroundImage!, fit: BoxFit.cover, errorBuilder: (c,e,s) => const SizedBox()),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: iconColor),
                const SizedBox(height: 10),
                Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}