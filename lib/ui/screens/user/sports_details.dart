import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/app_theme.dart';
// Import the shared FetchedMatch model
import '../admin/admin_sports_details.dart' show FetchedMatch;
import 'match_details_screen.dart';
import '../common/live_cricket_score_screen.dart';

class SportsDetailsScreen extends StatefulWidget {
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const SportsDetailsScreen({
    super.key,
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<SportsDetailsScreen> createState() => _SportsDetailsScreenState();
}

class _SportsDetailsScreenState extends State<SportsDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<FetchedMatch> _liveMatches = []; // Use FetchedMatch
  List<FetchedMatch> _recentMatches = []; // Use FetchedMatch
  List<FetchedMatch> _upcomingMatches = []; // Use FetchedMatch
  bool _isLoadingLive = true;
  bool _isLoadingRecent = true;
  bool _isLoadingUpcoming = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
     _tabController.addListener(_handleTabSelection); // Add listener
    _loadAllMatches();
  }

 // --- Ensure the correct tab loads initially ---
 void _handleTabSelection() {
    // No specific action needed on tab change for now,
    // but useful if you want logic tied to tab switches later.
    if (_tabController.indexIsChanging) {
      // print("Switched to tab: ${_tabController.index}");
    }
  }


  // --- Updated fetch logic (same as admin screen) ---
  Future<void> _fetchMatches(String status) async {
    // Set loading state for the specific tab
    setState(() {
      if (status == 'live') _isLoadingLive = true;
      if (status == 'recent') _isLoadingRecent = true;
      if (status == 'upcoming') _isLoadingUpcoming = true;
      _errorMessage = ''; // Clear previous errors
    });

    try {
      final String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final sportNameUrl = widget.sportName.toLowerCase();
      // Use the status parameter directly in the URL
      final String apiUrl =
          'http://$host:5000/api/get_matches/$sportNameUrl?status=$status';

      final response = await http.get(Uri.parse(apiUrl));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          // Parse data into FetchedMatch objects
          final List<FetchedMatch> fetchedMatches =
              data.map((jsonItem) => FetchedMatch.fromJson(jsonItem)).toList();

          // Update the correct list based on status
          setState(() {
            if (status == 'live') _liveMatches = fetchedMatches;
            if (status == 'recent') _recentMatches = fetchedMatches;
            if (status == 'upcoming') _upcomingMatches = fetchedMatches;
          });
        } else {
          // Set error message only if fetching failed
          setState(() {
            _errorMessage = 'Failed to load $status matches (${response.statusCode}).';
          });
          print('Error fetching $status matches: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not connect to the server. Please ensure it is running.';
        });
        print("Connection Error ($status): $e");
      }
    } finally {
      // Set loading state to false for the specific tab when done
      if (mounted) {
        setState(() {
          if (status == 'live') _isLoadingLive = false;
          if (status == 'recent') _isLoadingRecent = false;
          if (status == 'upcoming') _isLoadingUpcoming = false;
        });
      }
    }
  }
  // --- End Updated fetch logic ---


 // --- Refreshes all match lists ---
  Future<void> _refreshAllMatches() async {
     // Fetch all categories simultaneously
    await Future.wait([
      _fetchMatches('live'),
      _fetchMatches('recent'),
      _fetchMatches('upcoming'),
    ]);
     // Optionally, switch tab after refresh if needed
    // _setInitialTab();
  }

  // --- Call _refreshAllMatches initially ---
  void _loadAllMatches() {
    _refreshAllMatches().then((_) {
       // After initial load, set the tab based on data presence
      _setInitialTab();
    });
  }

   // --- Set initial tab logic ---
   void _setInitialTab() {
     if (!mounted) return;
     if (_liveMatches.isNotEmpty) {
       _tabController.animateTo(0);
     } else if (_upcomingMatches.isNotEmpty) {
       _tabController.animateTo(2);
     } else if (_recentMatches.isNotEmpty) {
       _tabController.animateTo(1);
     } else {
       _tabController.animateTo(2); // Default to upcoming if all empty
     }
   }
   // --- End Set initial tab logic ---


  @override
  void dispose() {
     _tabController.removeListener(_handleTabSelection); // Remove listener
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          // Centering title content
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Takes minimum space needed
          children: [
            Icon(widget.sportIcon, color: Colors.white),
            const SizedBox(width: 8),
            Text('${widget.sportName} Matches'),
          ],
        ),
        // Providing an empty container in actions balances the leading back button
        actions: [Container(width: 48)],
        centerTitle: true, // This ensures the title Row is centered
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight), // Standard AppBar height
          child: _buildTabBar(context),
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator( // Added RefreshIndicator here
          onRefresh: _refreshAllMatches,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMatchList(context, 'Live', _liveMatches, _isLoadingLive),
              _buildMatchList(context, 'Recent', _recentMatches, _isLoadingRecent),
              _buildMatchList(context, 'Upcoming', _upcomingMatches, _isLoadingUpcoming),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // --- TabBar remains the same ---
  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduced vertical margin
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1), // Slightly transparent background
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor, // Color for selected tab text
        unselectedLabelColor: Colors.white.withOpacity(0.9), // Color for unselected tab text
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        indicatorSize: TabBarIndicatorSize.tab, // Indicator covers the whole tab
        indicator: BoxDecoration( // Custom indicator styling
          color: Colors.white.withOpacity(0.95), // Indicator background color
          borderRadius: BorderRadius.circular(20),
        ),
        tabs: const [
          Tab(text: 'Live'),
          Tab(text: 'Recent'),
          Tab(text: 'Upcoming')
        ],
      ),
    );
  }

  // --- Empty List Widget remains the same ---
  Widget _buildEmptyList(String category) {
     return LayoutBuilder( // Ensures it takes available space for scrolling
       builder: (context, constraints) => SingleChildScrollView(
         physics: const AlwaysScrollableScrollPhysics(), // Allows scrolling even when content fits
         child: ConstrainedBox(
           constraints: BoxConstraints(minHeight: constraints.maxHeight), // Ensures it fills height
           child: Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.hourglass_empty, size: 50, color: Colors.white.withOpacity(0.7)),
                 const SizedBox(height: 16),
                 Text(
                   'No ${category.toLowerCase()} matches to show.',
                   style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                 ),
                 if (_errorMessage.isNotEmpty) // Show error message if present
                   Padding(
                     padding: const EdgeInsets.only(top: 16.0, left: 24, right: 24),
                     child: Text(
                       _errorMessage,
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.orange.shade100, fontSize: 14),
                     ),
                   ),
               ],
             ),
           ),
         ),
       ),
     );
  }

  // --- Updated buildMatchList (same as admin screen) ---
 Widget _buildMatchList(BuildContext context, String category, List<FetchedMatch> matches, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
     // Show error only if loading is finished and list is empty
    if (_errorMessage.isNotEmpty && matches.isEmpty) {
       return LayoutBuilder(
         builder: (context, constraints) => SingleChildScrollView(
           physics: const AlwaysScrollableScrollPhysics(),
           child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
             child: Center(
               child: Padding(
                 padding: const EdgeInsets.all(24.0),
                 child: Text(
                   _errorMessage,
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Colors.orange.shade100, fontSize: 16),
                 ),
               ),
             ),
           ),
         ),
       );
    }
    if (matches.isEmpty) {
      return _buildEmptyList(category); // Show standard empty message
    }

    // Use ListView.builder when there are matches
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return GestureDetector(
          onTap: () {
            if (category == 'Live') {
              // Navigate to Live Score Screen (isAdmin: false)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LiveCricketScoreScreen(
                    matchId: match.id,
                    sportName: widget.sportName,
                    teamAName: match.teamA,
                    teamBName: match.teamB,
                    isForBoys: widget.isForBoys,
                    onGenderToggle: widget.onGenderToggle,
                    isAdmin: false, // User view
                  ),
                ),
              ).then((_) => _refreshAllMatches()); // Refresh when returning
            } else if (category == 'Upcoming') {
              // Navigate to Match Details Screen (isAdmin: false)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(
                    matchId: match.id,
                    isAdmin: false, // User view
                    sportName: widget.sportName,
                    sportIcon: widget.sportIcon,
                    isForBoys: widget.isForBoys,
                    onGenderToggle: widget.onGenderToggle,
                  ),
                ),
              ); // No refresh needed typically when just viewing details
            } else {
               // Optional: Navigation for Recent matches (e.g., summary)
                print("Tapped on Recent Match ID: ${match.id}");
            }
          },
          child: _buildMatchCard(context, match, category),
        );
      },
    );
  }
  // --- End Updated buildMatchList ---


  // --- Updated _buildMatchCard (same as admin screen) ---
  Widget _buildMatchCard(BuildContext context, FetchedMatch match, String category) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(context, category, match.status), // Pass actual status
            const SizedBox(height: 12),
            // Display content based on category
            if (category == 'Upcoming') _buildUpcomingMatchContent(context, match),
            if (category == 'Live') _buildLiveMatchContent(context, match),
            if (category == 'Recent') _buildRecentMatchContent(context, match),
          ],
        ),
      ),
    );
  }
   // --- End Updated _buildMatchCard ---


 // --- NEW: Build Recent Match Content (same as admin screen) ---
 Widget _buildRecentMatchContent(BuildContext context, FetchedMatch match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, match.teamA, match.scoreA), // Use FetchedMatch scores
        const SizedBox(height: 8),
        _buildTeamRow(context, match.teamB, match.scoreB), // Use FetchedMatch scores
        const SizedBox(height: 12),
        Text(
          match.result ?? 'Match Finished', // Use the result text from DB
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ],
    );
  }
  // --- End NEW ---

  // --- Uses FetchedMatch now (same as admin screen) ---
  Widget _buildLiveMatchContent(BuildContext context, FetchedMatch match) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Team Names Column
              Flexible( // Added Flexible
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(match.teamA, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                     const SizedBox(height: 8),
                     Text(match.teamB, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Scores Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(match.scoreA, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                   const SizedBox(height: 8),
                  Text(match.scoreB, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
            ],
          ),
        ),
         const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(match.summary ?? 'Match is live.', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor)),
        ),
      ],
    );
  }

  // --- Uses FetchedMatch now (same as admin screen) ---
  Widget _buildUpcomingMatchContent(BuildContext context, FetchedMatch match) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(widget.sportIcon, color: Theme.of(context).primaryColor, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.teamA,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text('vs',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ),
              Text(match.teamB,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(match.venue,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(match.date,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor)),
            Text(match.time, style: TextStyle(color: Colors.grey[700])),
          ],
        )
      ],
    );
  }

  // --- Updated _buildCardHeader (same as admin screen) ---
  Widget _buildCardHeader(BuildContext context, String category, String matchStatus) {
      Color headerColor;
      Color textColor;
      String displayText = category.toUpperCase(); // Default display text

      // Determine color and text based on actual match status
      switch (matchStatus) {
        case 'live':
          headerColor = Colors.red.shade100;
          textColor = Colors.red.shade800;
          displayText = 'LIVE';
          break;
        case 'upcoming':
          headerColor = Colors.blue.shade100;
          textColor = Colors.blue.shade800;
           displayText = 'UPCOMING';
          break;
         case 'finished': // Use 'finished' status for Recent
          headerColor = Colors.grey.shade200;
          textColor = Colors.grey.shade700;
           displayText = 'RECENT'; // Display as 'RECENT'
          break;
        default: // Fallback for unexpected statuses
          headerColor = Colors.grey.shade200;
          textColor = Colors.grey.shade700;
          displayText = matchStatus.toUpperCase(); // Show the actual status if unknown
      }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${widget.sportName} • League',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: headerColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            displayText, // Use the determined display text
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
 // --- End Updated _buildCardHeader ---

 // --- NEW: Build Team Row (same as admin screen) ---
 Widget _buildTeamRow(BuildContext context, String name, String score) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
          child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', // Handle empty name
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16))),
        Text(score, // Score is already formatted by backend
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary)),
      ],
    );
  }
  // --- END NEW ---

 // --- Bottom Nav Bar remains the same ---
  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0, // Default to home
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pop(); // Go back to home screen
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys); // Toggle gender
        }
        // Add navigation for Schedule or Leaderboard if needed
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
}
