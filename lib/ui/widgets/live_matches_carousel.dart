import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';
import '../../../core/app_theme.dart';

// --- Live Score Screen Imports for Navigation ---
import '../screens/common/live_cricket_score_screen.dart';
import '../screens/common/live_football_score_screen.dart';
import '../screens/common/live_kabaddi_score_screen.dart';
import '../screens/common/live_volleyball_score_screen.dart';
import '../screens/common/live_chess_score_screen.dart';
import '../screens/common/live_carrom_score_screen.dart';
import '../screens/common/live_table_tennis_score_screen.dart';
import '../screens/common/live_badminton_score_screen.dart';
import '../screens/common/live_athletics_score_screen.dart';
import '../screens/common/live_basketball_score_screen.dart';

class LiveMatchesCarousel extends StatefulWidget {
  final bool isForBoys;
  final bool isAdmin;
  final Function(bool) onGenderToggle;

  const LiveMatchesCarousel({
    super.key,
    required this.isForBoys,
    required this.isAdmin,
    required this.onGenderToggle,
  });

  @override
  State<LiveMatchesCarousel> createState() => _LiveMatchesCarouselState();
}

class _LiveMatchesCarouselState extends State<LiveMatchesCarousel> {
  List<Map<String, dynamic>> _allLiveMatches = [];
  bool _isLoading = true;

  // List of all sports to check
  final List<String> _sports = [
    'Cricket', 'Football', 'Basketball', 'Kabaddi', 'Volleyball', 
    'Badminton', 'Table Tennis', 'Carrom', 'Chess', 'Athletics'
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllLiveMatches();
  }

  Future<void> _fetchAllLiveMatches() async {
    if (!mounted) return;
    
    List<Map<String, dynamic>> tempMatches = [];
    
    // Create a list of futures to fetch all simultaneously for speed
    List<Future<void>> fetchTasks = _sports.map((sport) async {
      try {
        final sportUrl = sport.toLowerCase().replaceAll(' ', '_');
        final response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/api/get_matches/$sportUrl?status=live')
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (var match in data) {
            // Add the sport name to the match object for UI/Navigation
            if (match is Map<String, dynamic>) {
              match['sportName'] = sport;
              tempMatches.add(match);
            }
          }
        }
      } catch (e) {
        // Silently fail for individual sports so one error doesn't break the whole carousel
        debugPrint('Error fetching live $sport: $e');
      }
    }).toList();

    await Future.wait(fetchTasks);

    if (mounted) {
      setState(() {
        _allLiveMatches = tempMatches;
        _isLoading = false;
      });
    }
  }

  void _navigateToLiveMatch(BuildContext context, Map<String, dynamic> match) {
    String sport = match['sportName'];
    int matchId = match['id'];
    String teamA = match['teamA'] ?? 'Team A';
    String teamB = match['teamB'] ?? 'Team B';
    
    Widget screen;

    if (sport == 'Football') {
      screen = LiveFootballScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Athletics') {
      screen = LiveAthleticsScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        teamCName: match['teamC'] ?? 'Team C',
        eventCategory: match['event_category'] ?? 'Race',
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Kabaddi') {
      screen = LiveKabaddiScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Volleyball') {
      screen = LiveVolleyballScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
        matchFormat: 'Standard', // API should provide this, default for now
      );
    } else if (sport == 'Basketball') {
      screen = LiveBasketballScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Chess') {
      screen = LiveChessScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Carrom') {
      screen = LiveCarromScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Table Tennis') {
      screen = LiveTableTennisScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Badminton') {
      screen = LiveBadmintonScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else {
      // Default to Cricket
      screen = LiveCricketScoreScreen(
        matchId: matchId, sportName: sport, teamAName: teamA, teamBName: teamB,
        isForBoys: widget.isForBoys, onGenderToggle: widget.onGenderToggle,
        isAdmin: widget.isAdmin,
      );
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen))
      .then((_) => _fetchAllLiveMatches()); // Refresh on return
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_allLiveMatches.isEmpty) {
      // Return empty if no matches
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            'Live Matches',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black.withOpacity(0.8)),
          ),
        ),
        SizedBox(
          height: 170, // Fixed height for the carousel
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _allLiveMatches.length,
            itemBuilder: (context, index) {
              final match = _allLiveMatches[index];
              return _buildLiveMatchCard(context, match);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMatchCard(BuildContext context, Map<String, dynamic> match) {
    final String sport = match['sportName'] ?? 'Sport';
    final String teamA = match['teamA'] ?? 'Team A';
    final String teamB = match['teamB'] ?? 'Team B';
    final String scoreA = match['scoreA'] ?? '';
    final String scoreB = match['scoreB'] ?? '';
    final String summary = match['summary'] ?? 'Match is live';

    return GestureDetector(
      onTap: () => _navigateToLiveMatch(context, match),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$sport • Live',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  )
                ],
              ),
              const Spacer(flex: 2),
              // Team A
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(teamA,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(scoreA,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor)),
                ],
              ),
              const SizedBox(height: 8),
              // Team B
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(teamB,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(scoreB,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor)),
                ],
              ),
              const Spacer(flex: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  summary,
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}