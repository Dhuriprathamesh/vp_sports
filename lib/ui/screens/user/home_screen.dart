import 'package:flutter/material.dart';

// The main screen of the application.
class HomeScreen extends StatelessWidget {
  // State and callback are now passed from the parent widget (MyApp)
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const HomeScreen({
    required this.isForBoys,
    required this.onGenderToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // We use a separate StatefulWidget to manage local state like the scroll controller
    // and bottom nav index, while the theme state is managed by the parent.
    return _HomeScreenView(
      isForBoys: isForBoys,
      onGenderToggle: onGenderToggle,
    );
  }
}

// Using a StatefulWidget internally to manage local state.
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


class _HomeScreenViewState extends State<_HomeScreenView> {
  int _bottomNavIndex = 0;

  // GlobalKeys are used to scroll to specific widgets.
  final GlobalKey _outdoorKey = GlobalKey();
  final GlobalKey _indoorKey = GlobalKey();

  // Function to handle scrolling to a specific section.
  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildMainContent(context),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // Builds the top application bar.
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: _buildProfileMenu(context),
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_rounded, color: Colors.white, size: 28),
          SizedBox(width: 8),
          Text('VP Sports'),
        ],
      ),
      // This empty container balances the title when a leading widget is present.
      actions: [Container(width: 56)],
      centerTitle: true,
    );
  }

  // Builds the profile icon and dropdown menu.
  Widget _buildProfileMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected: $value')),
          );
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'account',
            child: ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('My Account'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log Out'),
            ),
          ),
        ],
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Theme.of(context).appBarTheme.backgroundColor),
        ),
      ),
    );
  }

  // Builds the main scrollable content of the page.
  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveMatchesSection(context),
          _buildCategoryToggle(context),
          _buildSportsGrid(
            context,
            key: _outdoorKey,
            title: 'Outdoor Sports',
            sports: _getOutdoorSports(),
            iconColor: Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildSportsGrid(
            context,
            key: _indoorKey,
            title: 'Indoor Sports',
            sports: _getIndoorSports(),
            iconColor: Colors.indigo,
          ),
        ],
      ),
    );
  }

  // Builds the horizontally scrollable "Live Matches" section.
  Widget _buildLiveMatchesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            'Live Matches',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 5, // Example count
            itemBuilder: (context, index) {
              return _buildLiveMatchCard(context, index);
            },
          ),
        ),
      ],
    );
  }
  
  // Builds a single card for the live match list.
  Widget _buildLiveMatchCard(BuildContext context, int index) {
      return Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cricket • T20 Match ${index + 1}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TEAM A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('172/5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
              const SizedBox(height: 4),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TEAM B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('140/8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
              const Spacer(),
              Text(
                'Team A leads by 32 runs.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ],
          ),
        ),
      );
  }

  // Builds the toggle buttons for "Outdoor" and "Indoor".
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
              () => _scrollToSection(_outdoorKey),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildCategoryButton(
              context,
              'Indoor',
              Icons.roofing,
              () => _scrollToSection(_indoorKey),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for creating a single category button.
  Widget _buildCategoryButton(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
      ),
    );
  }
  
  // A generic builder for creating a grid of sports.
  Widget _buildSportsGrid(
    BuildContext context, {
    required GlobalKey key,
    required String title,
    required List<Map<String, dynamic>> sports,
    required Color iconColor,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: sports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final sport = sports[index];
              return _buildSportCard(
                context,
                name: sport['name'],
                icon: sport['icon'],
                iconColor: iconColor,
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Builds a single card for the sports grid.
  Widget _buildSportCard(BuildContext context, {String? name, IconData? icon, required Color iconColor}) {
    // If the card is empty
    if (name == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.5)
        ),
      );
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name selected')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the bottom navigation bar.
  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) {
        if (index == 3) {
          // This is the toggle button. It calls the function passed from MyApp.
          widget.onGenderToggle(!widget.isForBoys);
        } else {
          setState(() {
            _bottomNavIndex = index;
          });
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
  
  // --- DATA HELPERS ---
  
  List<Map<String, dynamic>> _getOutdoorSports() {
    return [
      {'name': 'Cricket', 'icon': Icons.sports_cricket},
      {'name': 'Football', 'icon': Icons.sports_soccer},
      {'name': 'Volleyball', 'icon': Icons.sports_volleyball},
      {'name': 'Kabaddi', 'icon': Icons.sports_kabaddi},
      {'name': 'Athletics', 'icon': Icons.directions_run},
      {'name': null, 'icon': null}, // Empty box
    ];
  }
  
  List<Map<String, dynamic>> _getIndoorSports() {
    return [
      {'name': 'Chess', 'icon': Icons.gamepad},
      {'name': 'Table Tennis', 'icon': Icons.sports_tennis},
      {'name': 'Carrom', 'icon': Icons.album},
      {'name': 'Badminton', 'icon': Icons.sports},
    ];
  }
}

