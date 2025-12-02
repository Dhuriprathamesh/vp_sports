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
import '../screens/common/live_dodgeball_score_screen.dart'; 
import 'dart:async'; // Added for Timer

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
  Timer? _fetchTimer; // Timer for continuous polling

  @override
  void initState() {
    super.initState();
    _fetchAllLiveMatches();
    // Start continuous polling for lively updates (Changed to 5 seconds)
    _fetchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _fetchAllLiveMatches(isBackground: true);
      }
    });
  }

  // Reload data when gender toggle changes
  @override
  void didUpdateWidget(covariant LiveMatchesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isForBoys != widget.isForBoys) {
      _fetchAllLiveMatches();
    }
  }
  
  @override
  void dispose() {
    _fetchTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllLiveMatches({bool isBackground = false}) async {
    if (!mounted) return;
    if (!isBackground) setState(() => _isLoading = true);
    
    List<Map<String, dynamic>> tempMatches = [];
    
    // 1. Define Base Sports List
    List<String> sportsToCheck = [
      'Cricket', 'Basketball', 'Kabaddi', 'Volleyball', 
      'Badminton', 'Table Tennis', 'Carrom', 'Chess', 'Athletics'
    ];

    // 2. Dynamic Sport Swap based on Gender
    if (widget.isForBoys) {
      sportsToCheck.add('Football');
    } else {
      sportsToCheck.add('Dodgeball');
    }

    String genderStr = widget.isForBoys ? 'Boys' : 'Girls';

    // 3. Fetch Matches for all sports in parallel
    List<Future<void>> fetchTasks = sportsToCheck.map((sport) async {
      try {
        final sportUrl = sport.toLowerCase().replaceAll(' ', '_');
        // Add gender parameter to API call
        final response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/api/get_matches/$sportUrl?status=live&gender=$genderStr')
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (var match in data) {
            if (match is Map<String, dynamic>) {
              match['sportName'] = sport; // Tag the sport name for UI
              tempMatches.add(match);
            }
          }
        }
      } catch (e) {
        // Silently fail for individual sports
        debugPrint('Error fetching live data for $sport: $e');
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

    // --- Navigation Logic ---
    if (sport == 'Football') {
      screen = LiveFootballScoreScreen(
        matchId: matchId, teamAName: teamA, teamBName: teamB,
        isAdmin: widget.isAdmin, isForBoys: widget.isForBoys,
      );
    } else if (sport == 'Dodgeball') { 
      screen = LiveDodgeballScoreScreen(
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
        matchFormat: 'Standard', 
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
    // Determine height based on whether content exists
    final double carouselHeight = _allLiveMatches.isEmpty && !_isLoading ? 100 : 170;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Row(
            children: [
              const Icon(Icons.live_tv, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                'Live Matches',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black.withOpacity(0.8),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // --- RESERVED SPACE CONTAINER (FIX) ---
        SizedBox(
          height: carouselHeight, 
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_allLiveMatches.isEmpty) {
      // Show empty message when no matches are live
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer, size: 40, color: Colors.black.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              'No live matches currently.',
              style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _allLiveMatches.length,
      itemBuilder: (context, index) {
        final match = _allLiveMatches[index];
        return _buildLiveMatchCard(context, match);
      },
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
        // FIXED: Reduced vertical margin to reduce card height and prevent overflow
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), 
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
                  Text('$sport',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade100)
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.fiber_manual_record, size: 8, color: Colors.red),
                        SizedBox(width: 4),
                        Text('LIVE',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                      ],
                    ),
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
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontStyle: FontStyle.italic),
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