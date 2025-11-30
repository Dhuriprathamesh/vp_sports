import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart';
import '../admin/admin_sports_details.dart' show FetchedMatch;
import 'match_details_screen.dart';

// --- Live Score Screens ---
import '../common/live_cricket_score_screen.dart';
import '../common/live_football_score_screen.dart';
import '../common/live_kabaddi_score_screen.dart';
import '../common/live_volleyball_score_screen.dart';
import '../common/live_chess_score_screen.dart';
import '../common/live_carrom_score_screen.dart';
import '../common/live_table_tennis_score_screen.dart';
import '../common/live_badminton_score_screen.dart';
import '../common/live_athletics_score_screen.dart'; 
import '../common/live_basketball_score_screen.dart'; // Added Basketball Import

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
    _loadAllMatches();
  }

  Future<void> _fetchMatches(String status) async {
    setState(() {
      if (status == 'live') _isLoadingLive = true;
      if (status == 'recent') _isLoadingRecent = true;
      if (status == 'upcoming') _isLoadingUpcoming = true;
      _errorMessage = '';
    });

    try {
      final String baseUrl = ApiConstants.baseUrl;
      final sportNameUrl = widget.sportName.toLowerCase().replaceAll(' ', '_');
      final String apiUrl = '$baseUrl/api/get_matches/$sportNameUrl?status=$status';

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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.sportIcon, color: Colors.white),
            const SizedBox(width: 8),
            Text('${widget.sportName} Matches'),
          ],
        ),
        actions: [Container(width: 48)],
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
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
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.white)));
    }
    if (matches.isEmpty) {
      return _buildEmptyList(category);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return GestureDetector(
          onTap: () {
            if (category == 'Live' || category == 'Recent') {
              Widget screen;
              // Handle Navigation based on sport
              if (widget.sportName == 'Athletics') {
                 // --- UPDATED ROUTING FOR ATHLETICS ---
                 screen = LiveAthleticsScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  teamCName: match.teamC ?? 'Team C',
                  eventCategory: match.eventCategory ?? 'Race',
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Football') {
                screen = LiveFootballScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Kabaddi') {
                screen = LiveKabaddiScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Volleyball') {
                screen = LiveVolleyballScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                  matchFormat: match.matchFormat ?? 'Best of 3 Sets',
                );
              } else if (widget.sportName == 'Basketball') { // Added Basketball
                screen = LiveBasketballScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Chess') {
                screen = LiveChessScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Carrom') {
                screen = LiveCarromScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Table Tennis') {
                screen = LiveTableTennisScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else if (widget.sportName == 'Badminton') {
                screen = LiveBadmintonScoreScreen(
                  matchId: match.id,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isAdmin: false,
                  isForBoys: widget.isForBoys,
                );
              } else {
                // Default to Cricket
                screen = LiveCricketScoreScreen(
                  matchId: match.id,
                  sportName: widget.sportName,
                  teamAName: match.teamA,
                  teamBName: match.teamB,
                  isForBoys: widget.isForBoys,
                  onGenderToggle: widget.onGenderToggle,
                  isAdmin: false,
                );
              }
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) => _refreshAllMatches());
            } else if (category == 'Upcoming') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(
                    matchId: match.id,
                    isAdmin: false,
                    sportName: widget.sportName,
                    sportIcon: widget.sportIcon,
                    isForBoys: widget.isForBoys,
                    onGenderToggle: widget.onGenderToggle,
                  ),
                ),
              );
            }
          },
          child: _buildMatchCard(context, match, category),
        );
      },
    );
  }

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
            _buildCardHeader(context, category, match.status),
            const SizedBox(height: 12),
            if (category == 'Upcoming') _buildUpcomingMatchContent(context, match),
            if (category == 'Live' || category == 'Recent') _buildLiveOrRecentMatchContent(context, match),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrRecentMatchContent(BuildContext context, FetchedMatch match) {
    // --- SPECIAL UI FOR ATHLETICS ---
    if (widget.sportName == 'Athletics') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(match.eventCategory ?? 'Race', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             const SizedBox(height: 8),
             Text("1. ${match.teamA}"),
             Text("2. ${match.teamB}"),
             if (match.teamC != null) Text("3. ${match.teamC}"),
             const SizedBox(height: 12),
             Text(match.summary ?? 'Race Status', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
          ],
        );
    }

    bool hideScores = widget.sportName == 'Carrom' || 
                      widget.sportName == 'Table Tennis' || 
                      widget.sportName == 'Badminton' || 
                      widget.sportName == 'Chess';

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
                  if (!hideScores) ...[
                    Text(match.scoreA, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                    const SizedBox(height: 8),
                    Text(match.scoreB, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(match.summary ?? (match.result ?? 'Match is live.'), style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor)),
        ),
      ],
    );
  }

  Widget _buildUpcomingMatchContent(BuildContext context, FetchedMatch match) {
    if (widget.sportName == 'Athletics') {
         return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(widget.sportIcon, color: Theme.of(context).primaryColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.eventCategory ?? "Athletics Event", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("${match.teamA}, ${match.teamB}, ${match.teamC ?? 'Team C'}", style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                  const SizedBox(height: 4),
                  Text(match.venue, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(match.date, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                Text(match.time, style: TextStyle(color: Colors.grey[700])),
              ],
            )
          ],
        );
    }

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

    switch (matchStatus.toLowerCase()) {
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