import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart';
import 'add_match.dart';
import '../user/match_details_screen.dart';

// --- Live Score Screen Imports ---
import '../common/live_cricket_score_screen.dart';
import '../common/live_football_score_screen.dart';
import '../common/live_kabaddi_score_screen.dart';
import '../common/live_volleyball_score_screen.dart';
import '../common/live_chess_score_screen.dart';
import '../common/live_carrom_score_screen.dart';
import '../common/live_table_tennis_score_screen.dart';
import '../common/live_badminton_score_screen.dart';
import '../common/live_athletics_score_screen.dart';
import '../common/live_basketball_score_screen.dart';
import '../common/live_dodgeball_score_screen.dart'; // Added Dodgeball

// --- Data Model for Fetched Matches ---
class FetchedMatch {
  final int id;
  final String teamA;
  final String teamB;
  final String? teamC; // For Athletics
  final String venue;
  final String date;
  final String time;
  final String status;
  String scoreA; 
  String scoreB; 
  final String? summary;
  final String? result;
  final String? matchFormat;
  final String? eventCategory; 

  FetchedMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    this.teamC,
    required this.venue,
    required this.date,
    required this.time,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    this.summary,
    this.result,
    this.matchFormat,
    this.eventCategory,
  });

  factory FetchedMatch.fromJson(Map<String, dynamic> json) {
    return FetchedMatch(
      id: json['id'],
      teamA: json['teamA'] ?? 'Team A',
      teamB: json['teamB'] ?? 'Team B',
      teamC: json['teamC'], 
      venue: json['venue'] ?? 'N/A',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      status: json['status'] ?? 'upcoming',
      scoreA: json['scoreA'] ?? '0',
      scoreB: json['scoreB'] ?? '0',
      summary: json['summary'],
      result: json.containsKey('winner') && json['winner'] != null
          ? (json['winner'] == 'Draw' ? 'Game Drawn' : '${json['winner']} Wins')
          : json['result'],
      matchFormat: json['matchFormat'],
      eventCategory: json['event_category'] ?? json['eventCategory'],
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
    _loadAllMatches();
  }

  // --- Gender Aware Fetching ---
  Future<void> _fetchMatches(String status) async {
    if (!mounted) return;
    setState(() {
      if (status == 'live') _isLoadingLive = true;
      if (status == 'recent') _isLoadingRecent = true;
      if (status == 'upcoming') _isLoadingUpcoming = true;
      _errorMessage = '';
    });

    try {
      final sportNameUrl = widget.sportName.toLowerCase().replaceAll(' ', '_');
      final String genderStr = widget.isForBoys ? 'Boys' : 'Girls';
      
      // Added gender param to query
      final String apiUrl =
          '${ApiConstants.baseUrl}/api/get_matches/$sportNameUrl?status=$status&gender=$genderStr';

      final response = await http.get(Uri.parse(apiUrl));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<FetchedMatch> fetchedMatches =
              data.map((jsonItem) => FetchedMatch.fromJson(jsonItem)).toList();

          setState(() {
            if (status == 'live') {
               _liveMatches = fetchedMatches;
               // Only fetch detailed scores if we have matches
               if(fetchedMatches.isNotEmpty) _fetchLiveScoresForList(fetchedMatches);
            }
            if (status == 'recent') _recentMatches = fetchedMatches;
            if (status == 'upcoming') _upcomingMatches = fetchedMatches;
          });
        } else {
          setState(() {
            _errorMessage =
                'Failed to load $status matches (${response.statusCode}).';
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

  // --- FIXED: Robust Fetch Real-Time Scores Individually (Handles 404) ---
  Future<void> _fetchLiveScoresForList(List<FetchedMatch> matches) async {
    for (var match in matches) {
      if (!mounted) return;
      try {
        String endpoint = '';
        String sport = widget.sportName;
        
        if (sport == 'Cricket') endpoint = 'get_live_score';
        else if (sport == 'Football') endpoint = 'get_football_live_score';
        else if (sport == 'Dodgeball') endpoint = 'get_dodgeball_live_score';
        else if (sport == 'Kabaddi') endpoint = 'get_kabaddi_live_score';
        else if (sport == 'Volleyball') endpoint = 'get_volleyball_live_score';
        else if (sport == 'Basketball') endpoint = 'get_basketball_live_score';
        else if (sport == 'Badminton') endpoint = 'get_badminton_live_score';
        else if (sport == 'Table Tennis') endpoint = 'get_table_tennis_live_score';
        
        if (endpoint.isNotEmpty) {
          final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/$endpoint/${match.id}'));
          
          if (!mounted) return; 

          // 1. Handle SUCCESS (200) or NO LIVE DATA (404)
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            String newScoreA = match.scoreA;
            String newScoreB = match.scoreB;

            if (sport == 'Cricket') {
               newScoreA = "${data['team1_runs'] ?? 0}/${data['team1_wickets'] ?? 0}";
               newScoreB = "${data['team2_runs'] ?? 0}/${data['team2_wickets'] ?? 0}";
            } else if (sport == 'Football' || sport == 'Dodgeball') {
               newScoreA = "${data['team_a_goals'] ?? data['team_a_score'] ?? 0}";
               newScoreB = "${data['team_b_goals'] ?? data['team_b_score'] ?? 0}";
            } else if (sport == 'Kabaddi') {
               newScoreA = "${data['team_a_score'] ?? 0}";
               newScoreB = "${data['team_b_score'] ?? 0}";
            } else if (sport == 'Volleyball') {
               newScoreA = "${data['team_a_sets_won'] ?? 0}";
               newScoreB = "${data['team_b_sets_won'] ?? 0}";
            } else if (sport == 'Basketball') {
               newScoreA = "${data['team1_score'] ?? 0}";
               newScoreB = "${data['team2_score'] ?? 0}";
            }
            
            // Only setState if we have valid scores and are mounted
            if (mounted) {
              setState(() {
                match.scoreA = newScoreA;
                match.scoreB = newScoreB;
              });
            }
          } 
          // 2. Handle 404/Error case: Keep default scores (0/0) or already fetched summary
          else {
              // This is usually okay; it means the match is marked 'live' but hasn't had its first score post yet.
              // We rely on the initial fetch to set generic 0/0 scores.
          }
        }
      } catch (e) {
        debugPrint("Error fetching detailed score for match ${match.id}: $e");
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
    final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

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
                    _buildMatchList(
                        context, 'Live', _liveMatches, _isLoadingLive),
                    _buildMatchList(
                        context, 'Recent', _recentMatches, _isLoadingRecent),
                    _buildMatchList(context, 'Upcoming', _upcomingMatches,
                        _isLoadingUpcoming),
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
            builder: (context) => AddMatchScreen(
              sportName: widget.sportName,
              isForBoys: widget.isForBoys, 
            ),
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

  Widget _buildMatchList(BuildContext context, String category,
      List<FetchedMatch> matches, bool isLoading) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (matches.isEmpty) {
      return Center(
        child: Text(
          'No ${category.toLowerCase()} matches.',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return GestureDetector(
          onTap: () {
            _handleMatchTap(context, match, category);
          },
          child: _buildMatchCard(context, match, category),
        );
      },
    );
  }

  void _handleMatchTap(
      BuildContext context, FetchedMatch match, String category) async {
    if (category == 'Live' || category == 'Recent') {
      Widget screen;
      String sport = widget.sportName;

      if (sport == 'Football') {
        screen = LiveFootballScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Dodgeball') {
        screen = LiveDodgeballScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Athletics') {
         screen = LiveAthleticsScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          teamCName: match.teamC ?? 'Team C', eventCategory: match.eventCategory ?? 'Race',
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Kabaddi') {
        screen = LiveKabaddiScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Volleyball') {
        screen = LiveVolleyballScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
          matchFormat: match.matchFormat ?? 'Best of 3 Sets',
        );
      } else if (sport == 'Basketball') {
        screen = LiveBasketballScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Chess') {
        screen = LiveChessScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Carrom') {
        screen = LiveCarromScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Table Tennis') {
        screen = LiveTableTennisScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else if (sport == 'Badminton') {
        screen = LiveBadmintonScoreScreen(
          matchId: match.id, teamAName: match.teamA, teamBName: match.teamB,
          isAdmin: true, isForBoys: widget.isForBoys,
        );
      } else {
        // Default to Cricket
        screen = LiveCricketScoreScreen(
          matchId: match.id, sportName: widget.sportName,
          teamAName: match.teamA, teamBName: match.teamB,
          isForBoys: widget.isForBoys, onGenderToggle: widget.onGenderToggle,
          isAdmin: true,
        );
      }

      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => screen));
      _refreshAllMatches();
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
  }

  Widget _buildMatchCard(
      BuildContext context, FetchedMatch match, String category) {
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
            if (category == 'Upcoming')
              _buildUpcomingMatchContent(context, match)
            else
              _buildLiveOrRecentMatchContent(context, match),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrRecentMatchContent(
      BuildContext context, FetchedMatch match) {
    if (widget.sportName == 'Athletics') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(match.eventCategory ?? 'Race', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             const SizedBox(height: 8),
             Text("1. ${match.teamA}"),
             Text("2. ${match.teamB}"),
             Text("3. ${match.teamC ?? 'Team C'}"),
             const SizedBox(height: 8),
             Text(match.summary ?? 'Race Status', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
          ],
        );
    }

    bool hideScores = widget.sportName == 'Carrom' || widget.sportName == 'Chess';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.teamA,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(match.teamB,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!hideScores) ...[
                  Text(match.scoreA,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary)),
                  const SizedBox(height: 8),
                  Text(match.scoreB,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary)),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          match.summary ?? (match.result ?? 'Match in progress'),
          style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor),
        ),
      ],
    );
  }

  Widget _buildUpcomingMatchContent(BuildContext context, FetchedMatch match) {
    if (widget.sportName == 'Athletics') {
         return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(widget.sportIcon,
                color: Theme.of(context).primaryColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.eventCategory ?? "Athletics Event",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("${match.teamA}, ${match.teamB}, ${match.teamC}",
                      style: TextStyle(fontSize: 14, color: Colors.grey[800])),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(widget.sportIcon,
            color: Theme.of(context).primaryColor, size: 40),
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

  Widget _buildCardHeader(
      BuildContext context, String category, String matchStatus) {
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