import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/app_theme.dart';
// Removed mock_data import as we use backend data now
// import '../../../data/mock_data.dart';
import 'add_match.dart';
// MatchDetailsScreen is likely still needed for upcoming
import '../user/match_details_screen.dart';
import '../common/live_cricket_score_screen.dart';
import '../common/live_football_score_screen.dart'; // <-- IMPORT NEW SCREEN

// --- Data Model for Fetched Matches ---
class FetchedMatch {
  final int id;
  final String teamA;
  final String teamB;
  final String venue;
  final String date;
  final String time;
  final String status;
  final String scoreA;
  final String scoreB;
  final String? summary;
  final String? result;

  FetchedMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.venue,
    required this.date,
    required this.time,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    this.summary,
    this.result,
  });

  factory FetchedMatch.fromJson(Map<String, dynamic> json) {
    return FetchedMatch(
      id: json['id'],
      teamA: json['teamA'] ?? 'Team A',
      teamB: json['teamB'] ?? 'Team B',
      venue: json['venue'] ?? 'N/A',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      status: json['status'] ?? 'upcoming',
      scoreA: json['scoreA'] ?? '0', // Default to 0
      scoreB: json['scoreB'] ?? '0', // Default to 0
      summary: json['summary'],
      result: json['result'],
    );
  }
}

class AdminSportsDetailsScreen extends StatefulWidget {
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const AdminSportsDetailsScreen({
    super.key,
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<AdminSportsDetailsScreen> createState() =>
      _AdminSportsDetailsScreenState();
}

class _AdminSportsDetailsScreenState extends State<AdminSportsDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<FetchedMatch> _liveMatches = [];
  List<FetchedMatch> _recentMatches = [];
  List<FetchedMatch> _upcomingMatches = [];
  bool _isLoadingLive = true;
  bool _isLoadingRecent = true;
  bool _isLoadingUpcoming = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadAllMatches();
  }

 void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      // Optional tab change logic
    }
  }

  Future<void> _fetchMatches(String status) async {
    setState(() {
      if (status == 'live') _isLoadingLive = true;
      if (status == 'recent') _isLoadingRecent = true;
      if (status == 'upcoming') _isLoadingUpcoming = true;
      _errorMessage = '';
    });

    try {
      const String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final sportNameUrl = widget.sportName.toLowerCase();
      final String apiUrl =
          'http://$host:5000/api/get_matches/$sportNameUrl?status=$status';

      final response = await http.get(Uri.parse(apiUrl));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<FetchedMatch> fetchedMatches =
              data.map((jsonItem) => FetchedMatch.fromJson(jsonItem)).toList();

          setState(() {
            if (status == 'live') _liveMatches = fetchedMatches;
            if (status == 'recent') _recentMatches = fetchedMatches;
            if (status == 'upcoming') _upcomingMatches = fetchedMatches;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load $status matches (${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not connect to the server. Please ensure it is running.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (status == 'live') _isLoadingLive = false;
          if (status == 'recent') _isLoadingRecent = false;
          if (status == 'upcoming') _isLoadingUpcoming = false;
        });
      }
    }
  }

  Future<void> _refreshAllMatches() async {
    await Future.wait([
      _fetchMatches('live'),
      _fetchMatches('recent'),
      _fetchMatches('upcoming'),
    ]);
  }

  void _loadAllMatches() {
    _refreshAllMatches().then((_) {
      _setInitialTab();
    });
  }

   void _setInitialTab() {
     if (!mounted) return;
     if (_liveMatches.isNotEmpty) {
       _tabController.animateTo(0);
     } else if (_upcomingMatches.isNotEmpty) {
       _tabController.animateTo(2);
     } else if (_recentMatches.isNotEmpty) {
       _tabController.animateTo(1);
     } else {
       _tabController.animateTo(2);
     }
   }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: _buildAppBar(context),
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
        child: Column(
          children: [
            _buildTabBar(context),
            Expanded(
              child: RefreshIndicator(
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? matchAdded = await showDialog<bool>(
            context: context,
            builder: (context) => AddMatchScreen(sportName: widget.sportName),
          );

          if (matchAdded == true) {
             await _refreshAllMatches();
             _tabController.animateTo(2);
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.sportIcon, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(child: Text('${widget.sportName} Matches')),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.white.withOpacity(0.9),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
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

  Widget _buildEmptyList(String category) {
     return LayoutBuilder(
       builder: (context, constraints) => SingleChildScrollView(
         physics: const AlwaysScrollableScrollPhysics(),
         child: ConstrainedBox(
           constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                 if (_errorMessage.isNotEmpty)
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

 Widget _buildMatchList(BuildContext context, String category, List<FetchedMatch> matches, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
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
      return _buildEmptyList(category);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return GestureDetector(
          // FIXED: Added logic for 'Recent' category to open scorecard
          onTap: () async {
            if (category == 'Live' || category == 'Recent') { // Allow Recent to open scorecard
              if (widget.sportName == 'Football') {
                 Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LiveFootballScoreScreen(
                      matchId: match.id,
                      teamAName: match.teamA,
                      teamBName: match.teamB,
                      isAdmin: true, // Admins can still edit if needed, or set to false for view only
                      isForBoys: widget.isForBoys,
                    ),
                  ),
                ).then((_) => _refreshAllMatches());
              } else {
                // Default to Cricket
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LiveCricketScoreScreen(
                      matchId: match.id,
                      sportName: widget.sportName,
                      teamAName: match.teamA,
                      teamBName: match.teamB,
                      isForBoys: widget.isForBoys,
                      onGenderToggle: widget.onGenderToggle,
                      isAdmin: true,
                    ),
                  ),
                ).then((_) => _refreshAllMatches());
              }
            } else if (category == 'Upcoming') {
              final bool? refresh = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(
                    matchId: match.id,
                    isAdmin: true,
                    sportName: widget.sportName,
                    sportIcon: widget.sportIcon,
                    isForBoys: widget.isForBoys,
                    onGenderToggle: widget.onGenderToggle,
                  ),
                ),
              );
              if (refresh == true) {
                _refreshAllMatches();
              }
            }
          },
          child: _buildMatchCard(context, match, category),
        );
      },
    );
  }

  Widget _buildMatchCard(BuildContext context, FetchedMatch match, String category) {
    // --- ADDED: Material + InkWell Wrapper for Clickability ---
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias, // Ensures ripple effect respects corners
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // InkWell wraps the content to capture taps on the entire card
        onTap: () async {
            // Re-using the exact logic from the GestureDetector above
            if (category == 'Live' || category == 'Recent') {
              if (widget.sportName == 'Football') {
                 Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LiveFootballScoreScreen(
                      matchId: match.id,
                      teamAName: match.teamA,
                      teamBName: match.teamB,
                      isAdmin: true,
                      isForBoys: widget.isForBoys,
                    ),
                  ),
                ).then((_) => _refreshAllMatches());
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LiveCricketScoreScreen(
                      matchId: match.id,
                      sportName: widget.sportName,
                      teamAName: match.teamA,
                      teamBName: match.teamB,
                      isForBoys: widget.isForBoys,
                      onGenderToggle: widget.onGenderToggle,
                      isAdmin: true,
                    ),
                  ),
                ).then((_) => _refreshAllMatches());
              }
            } else if (category == 'Upcoming') {
              final bool? refresh = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(
                    matchId: match.id,
                    isAdmin: true,
                    sportName: widget.sportName,
                    sportIcon: widget.sportIcon,
                    isForBoys: widget.isForBoys,
                    onGenderToggle: widget.onGenderToggle,
                  ),
                ),
              );
              if (refresh == true) {
                _refreshAllMatches();
              }
            }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(context, category, match.status),
              const SizedBox(height: 12),
              if (category == 'Upcoming') _buildUpcomingMatchContent(context, match),
              if (category == 'Live') _buildLiveMatchContent(context, match),
              if (category == 'Recent') _buildRecentMatchContent(context, match),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildRecentMatchContent(BuildContext context, FetchedMatch match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, match.teamA, match.scoreA),
        const SizedBox(height: 8),
        _buildTeamRow(context, match.teamB, match.scoreB),
        const SizedBox(height: 12),
        Text(
          match.result ?? 'Match Finished',
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLiveMatchContent(BuildContext context, FetchedMatch match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(match.teamA, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                     const SizedBox(height: 8),
                     Text(match.teamB, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
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

  Widget _buildCardHeader(BuildContext context, String category, String matchStatus) {
      Color headerColor;
      Color textColor;
      String displayText = category.toUpperCase();

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
         case 'finished':
          headerColor = Colors.grey.shade200;
          textColor = Colors.grey.shade700;
           displayText = 'RECENT';
          break;
        default:
          headerColor = Colors.grey.shade200;
          textColor = Colors.grey.shade700;
          displayText = matchStatus.toUpperCase();
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
            displayText,
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

 Widget _buildTeamRow(BuildContext context, String name, String score) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
          child: Text(name.isNotEmpty ? name.substring(0, 1) : '?',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16))),
        Text(score,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary)),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pop();
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys);
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
}