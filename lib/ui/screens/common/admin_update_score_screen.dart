import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
// import 'dart:math'; // Removed unused import
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // For debounce
import 'package:flutter/foundation.dart' show kIsWeb;

// --- ADD THESE IMPORTS ---
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:permission_handler/permission_handler.dart';
// --- ADD CONDITIONAL WEB IMPORT ---
import 'dart:html' as html; // Import dart:html for web downloads


// Player class (no changes needed for JSON mapping)
class Player {
  final int id;
  final String name;
  int runs = 0;
  int ballsFaced = 0;
  bool isOut = false;
  String dismissalInfo = "";
  int ballsBowled = 0;
  int runsConceded = 0;
  int wicketsTaken = 0;
  int maidens = 0; // Currently not tracked/sent in detail
  Player({required this.id, required this.name});
  String getBowlerFigures() { int overs = ballsBowled ~/ 6; int ballsPart = ballsBowled % 6; return "$wicketsTaken/$runsConceded ($overs.$ballsPart)"; }
  String getBatsmanScore() { return "$runs ($ballsFaced)"; }

  // Method to convert Player object to a Map for JSON serialization
  // --- MODIFICATION: Added currentStriker and currentNonStriker as parameters ---
  Map<String, dynamic> toJson(String currentStatus, Player? currentStriker, Player? currentNonStriker) {
     String status = "Yet to bat";
     // Determine batting status based on current state
     if (id == currentStriker?.id || id == currentNonStriker?.id) {
       status = "Not Out";
     } else if (isOut) {
       status = dismissalInfo.isNotEmpty ? dismissalInfo : "Out";
     } else if (ballsFaced > 0 || runs > 0) {
        // Only mark as 'Out' if they actually batted and are not current
        status = dismissalInfo.isNotEmpty ? dismissalInfo : "Out";
     } else if(currentStatus == 'finished' && !isOut && ballsFaced == 0 && runs == 0) {
       // If match finished and player didn't bat, keep as "Yet to bat"
       status = "Yet to bat";
     }


     return {
       "id": id,
       "name": name,
       "runs": runs,
       "ballsFaced": ballsFaced,
       "status": status, // Use calculated status
       "ballsBowled": ballsBowled,
       "runsConceded": runsConceded,
       "wicketsTaken": wicketsTaken,
       // Maidens not included in JSON currently
     };
   }
   // --- END MODIFICATION ---

   // Optional: Factory constructor to create Player from JSON (useful for loading)
   factory Player.fromJson(Map<String, dynamic> json) {
     Player player = Player(id: json['id'], name: json['name']);
     player.runs = json['runs'] ?? 0;
     player.ballsFaced = json['ballsFaced'] ?? 0;
     String status = json['status'] ?? "";
     player.isOut = (status != "Not Out" && status != "Yet to bat");
     player.dismissalInfo = player.isOut ? status : "";
     player.ballsBowled = json['ballsBowled'] ?? 0;
     player.runsConceded = json['runsConceded'] ?? 0;
     player.wicketsTaken = json['wicketsTaken'] ?? 0;
     // Maidens not loaded currently
     return player;
   }
}


class AdminUpdateScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isForBoys;

  const AdminUpdateScoreScreen({ super.key, required this.matchId, required this.teamAName, required this.teamBName, required this.isForBoys, });
  @override
  State<AdminUpdateScoreScreen> createState() => _AdminUpdateScoreScreenState();
}


enum ScoringPhase { preMatch, selectPlayers, innings1, inningsBreak, innings2, matchEnd, finished }
enum TossDecision { Bat, Bowl }
enum ExtraType { Wide, NoBall, LegBye, Bye }


class _AdminUpdateScoreScreenState extends State<AdminUpdateScoreScreen> {

  // --- MODIFICATION: Moved striker/nonStriker back into state class ---
  Player? _striker;
  Player? _nonStriker;
  // --- END MODIFICATION ---

  ScoringPhase _currentPhase = ScoringPhase.preMatch;
  List<Player> _fetchedTeamAPlayers = [];
  List<Player> _fetchedTeamBPlayers = [];
  bool _isLoadingPlayers = true;
  String _playerFetchError = '';
  int _teamARuns = 0; int _teamAWickets = 0; int _teamABalls = 0;
  int _teamBRuns = 0; int _teamBWickets = 0; int _teamBBalls = 0;
  int _targetScore = -1; int _maxOvers = 20;
  int _firstInningsValidBallsBowled = 0;
  String _matchStatusText = "Live"; String _summaryText = "Toss will happen soon.";
  String _battingTeamName = ""; String _bowlingTeamName = "";
  // Player? _striker; // Moved outside class
  // Player? _nonStriker; // Moved outside class
  Player? _currentBowler;
  List<Player> _dismissedBatsmen = []; List<Player> _bowlersUsed = [];
  int _currentOverNumber = 1; int _currentBallNumberInOver = 1;
  // int _ballsBowledThisOverRaw = 0; // Removed unused variable
  List<String> _ballsThisOverDisplay = [];
  int _extras = 0; bool _isFirstInnings = true;
  String? _tossWinner; TossDecision? _tossDecision;
  Timer? _debounceTimer; bool _isSaving = false;
  Map<String, dynamic>? _lastSentState;
  // List<String> _timeline = []; // Removed
  List<String> _team1Timeline = [];
  List<String> _team2Timeline = [];

  bool _isDownloadingPdf = false; // Added for PDF download state

  @override
  void initState() { super.initState(); _fetchMatchPlayers(); }
  @override
  void dispose() { _debounceTimer?.cancel(); super.dispose(); }

  // Fetch player lists and MAX OVERS
  Future<void> _fetchMatchPlayers() async {
     setState(() { _isLoadingPlayers = true; _playerFetchError = ''; });
    try {
      const String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final response = await http.get( Uri.parse('http://$host:5000/api/get_match_details/${widget.matchId}'));
      if (mounted) {
        if (response.statusCode == 200) {
          final matchDetails = json.decode(response.body);
          List<String> teamAPlayerNames = List<String>.from(matchDetails['team_a_players'] ?? []);
          List<String> teamBPlayerNames = List<String>.from(matchDetails['team_b_players'] ?? []);
          setState(() {
            _fetchedTeamAPlayers = teamAPlayerNames.asMap().entries.map((entry) => Player(id: 1000 + entry.key, name: entry.value)).toList();
            _fetchedTeamBPlayers = teamBPlayerNames.asMap().entries.map((entry) => Player(id: 2000 + entry.key, name: entry.value)).toList();

            var oversRaw = matchDetails['overs_per_innings'];
            _maxOvers = (oversRaw is num) ? oversRaw.toInt() : 20;
            _isLoadingPlayers = false; // Mark as done initially
          });
          // --- MODIFICATION: Re-enabled call to load live state ---
          await _loadExistingLiveState();
          // --- END MODIFICATION ---
        } else {
          setState(() { _playerFetchError = 'Failed to load player details (${response.statusCode}).'; _isLoadingPlayers = false; });
        }
      }
    } catch (e) {
      if (mounted) { setState(() { _playerFetchError = 'Could not connect to fetch match details.'; _isLoadingPlayers = false; print("Fetch Match Details Error: $e");}); }
    }
  }

  // Load Existing State from Backend
  Future<void> _loadExistingLiveState() async {
     // --- MODIFICATION: Re-enabled with JSONB parsing ---
     setState(() => _isLoadingPlayers = true); // Show loading indicator while fetching state
     const String host = kIsWeb ? 'localhost' : '10.0.2.2';
     final String apiUrl = 'http://$host:5000/api/get_live_updates/${widget.matchId}';

     try {
        final response = await http.get(Uri.parse(apiUrl));
        if (mounted && response.statusCode == 200) {
            final loadedData = json.decode(response.body);
             _lastSentState = loadedData; // Store the raw loaded state

            // Helper to find a player in the fetched lists by ID
            Player? findFetchedPlayerById(int? playerId) {
                if (playerId == null) return null;
                try {
                    if (playerId >= 1000 && playerId < 2000) {
                        // Use firstWhereOrNull for safety
                        return _fetchedTeamAPlayers.firstWhere((p) => p.id == playerId);
                    } else if (playerId >= 2000 && playerId < 3000) {
                         // Use firstWhereOrNull for safety
                        return _fetchedTeamBPlayers.firstWhere((p) => p.id == playerId);
                    }
                } catch (e) { print("Load State Warning: Player ID $playerId not found in fetched lists."); }
                return null;
            }

            // Helper to update local Player object from JSON stats
            void updateLocalPlayerStatsFromJson(int playerId, Map<String, dynamic> stats) {
                Player? player = findFetchedPlayerById(playerId);
                if (player != null) {
                    player.runs = stats['runs'] ?? 0;
                    player.ballsFaced = stats['ballsFaced'] ?? 0;
                    String status = stats['status'] ?? "";
                    player.isOut = (status != "Not Out" && status != "Yet to bat");
                    player.dismissalInfo = player.isOut ? status : "";
                    player.ballsBowled = stats['ballsBowled'] ?? 0;
                    player.runsConceded = stats['runsConceded'] ?? 0;
                    player.wicketsTaken = stats['wicketsTaken'] ?? 0;

                    // Add to dismissed list if loaded as out and not already present
                    if (player.isOut && !_dismissedBatsmen.any((p) => p.id == player.id)) {
                       _dismissedBatsmen.add(player);
                    }
                    // Add to bowlers used list if loaded with balls bowled and not already present
                     if (player.ballsBowled > 0 && !_bowlersUsed.any((p) => p.id == player.id)) {
                       _bowlersUsed.add(player);
                    }
                } else {
                     print("Load State Warning: Could not find local player object for ID $playerId to update stats.");
                }
            }


            setState(() {
                // Load core match state
                _tossWinner = loadedData['toss_winner'];
                _tossDecision = loadedData['toss_decision'] == 'Bat' ? TossDecision.Bat : (loadedData['toss_decision'] == 'Bowl' ? TossDecision.Bowl : null);
                _matchStatusText = loadedData['current_status'] ?? "Live";
                _summaryText = loadedData['summary_text'] ?? "Match in progress.";
                _isFirstInnings = loadedData['is_first_innings'] ?? true;
                _targetScore = loadedData['target_score'] ?? -1;
                _firstInningsValidBallsBowled = loadedData['first_innings_balls'] ?? 0;
                _teamARuns = loadedData['team1_runs'] ?? 0; _teamAWickets = loadedData['team1_wickets'] ?? 0; _teamABalls = loadedData['team1_balls'] ?? 0;
                _teamBRuns = loadedData['team2_runs'] ?? 0; _teamBWickets = loadedData['team2_wickets'] ?? 0; _teamBBalls = loadedData['team2_balls'] ?? 0;

                // Load timelines
                _team1Timeline = List<String>.from(loadedData['team1_timeline'] ?? []);
                _team2Timeline = List<String>.from(loadedData['team2_timeline'] ?? []);

                // Determine batting/bowling team based on loaded state
                 if (_tossWinner != null && _tossDecision != null) {
                    bool teamABatsFirst = (_tossWinner == widget.teamAName && _tossDecision == TossDecision.Bat) || (_tossWinner == widget.teamBName && _tossDecision == TossDecision.Bowl);
                    if (_isFirstInnings) { _battingTeamName = teamABatsFirst ? widget.teamAName : widget.teamBName; _bowlingTeamName = teamABatsFirst ? widget.teamBName : widget.teamAName; }
                    else { _battingTeamName = teamABatsFirst ? widget.teamBName : widget.teamAName; _bowlingTeamName = teamABatsFirst ? widget.teamAName : widget.teamBName; }
                 } else { _battingTeamName = ""; _bowlingTeamName = ""; }

                 // Find and assign current players
                 _striker = findFetchedPlayerById(loadedData['striker_id']);
                 _nonStriker = findFetchedPlayerById(loadedData['non_striker_id']);
                 _currentBowler = findFetchedPlayerById(loadedData['bowler_id']);

                 // Load extras for the correct team
                 if (_battingTeamName.isNotEmpty) {
                    _extras = (_battingTeamName == widget.teamAName) ? (loadedData['team1_extras'] ?? 0) : (loadedData['team2_extras'] ?? 0);
                 } else { _extras = 0; }

                // --- Parse JSONB player stats ---
                // Ensure the loaded data is treated as List<dynamic>
                List<dynamic> team1BatStats = loadedData['team1_batting'] ?? [];
                List<dynamic> team2BowlStats = loadedData['team2_bowling'] ?? [];
                List<dynamic> team2BatStats = loadedData['team2_batting'] ?? [];
                List<dynamic> team1BowlStats = loadedData['team1_bowling'] ?? [];

                // Reset dismissed/bowlers lists before reloading from stats
                _dismissedBatsmen.clear();
                _bowlersUsed.clear();

                // Update local player objects
                for (var stats in team1BatStats) { if (stats is Map<String, dynamic> && stats['id'] != null) updateLocalPlayerStatsFromJson(stats['id'], stats); }
                for (var stats in team2BowlStats) { if (stats is Map<String, dynamic> && stats['id'] != null) updateLocalPlayerStatsFromJson(stats['id'], stats); }
                for (var stats in team2BatStats) { if (stats is Map<String, dynamic> && stats['id'] != null) updateLocalPlayerStatsFromJson(stats['id'], stats); }
                for (var stats in team1BowlStats) { if (stats is Map<String, dynamic> && stats['id'] != null) updateLocalPlayerStatsFromJson(stats['id'], stats); }


                 // --- Calculate current over/ball ---
                 int currentInningsBalls = (_battingTeamName == widget.teamAName) ? _teamABalls : _teamBBalls;
                 if (currentInningsBalls >= 0) { // Check >= 0 instead of > 0
                    _currentOverNumber = (currentInningsBalls ~/ 6) + 1;
                    _currentBallNumberInOver = (currentInningsBalls % 6) + 1;

                    // Handle edge case where over just completed (e.g., 6 balls = start of 2nd over, ball 1)
                     // A ball count that's a multiple of 6 (and not 0) means the over just finished.
                     // The *next* ball will be the start of the next over.
                    if (currentInningsBalls > 0 && currentInningsBalls % 6 == 0) {
                         // Over just finished. Next ball is start of new over.
                         _currentOverNumber = (currentInningsBalls ~/ 6) + 1;
                         _currentBallNumberInOver = 1;
                          print("Load State: Detected start of new over ($_currentOverNumber) as previous over just finished.");
                         _ballsThisOverDisplay = []; // Clear display for new over
                         // UI should prompt for bowler if _currentBowler is null here.
                    } else {
                         // Over is in progress
                         _currentOverNumber = (currentInningsBalls ~/ 6) + 1;
                         _currentBallNumberInOver = (currentInningsBalls % 6) + 1;
                    }


                 } else { _currentOverNumber = 1; _currentBallNumberInOver = 1; }

                 // Determine current phase based on loaded data
                 if (_matchStatusText == 'finished') {
                   _currentPhase = ScoringPhase.finished;
                 } else if (_matchStatusText == 'upcoming') _currentPhase = ScoringPhase.preMatch;
                 else if (loadedData['break_status'] != null) _currentPhase = ScoringPhase.inningsBreak;
                 else if (_tossWinner != null && _striker == null && _nonStriker == null && _currentBowler == null && _matchStatusText == 'live') _currentPhase = ScoringPhase.selectPlayers;
                 else if (_tossWinner == null) _currentPhase = ScoringPhase.preMatch; // Still waiting for toss
                 else if (_isFirstInnings) _currentPhase = ScoringPhase.innings1;
                 else _currentPhase = ScoringPhase.innings2;

                 // Update summary text based on loaded state and calculated phase
                 if (_currentPhase == ScoringPhase.innings2 && _targetScore > 0) {
                      int currentBattingRuns = (_battingTeamName == widget.teamAName) ? _teamARuns : _teamBRuns;
                      int runsNeeded = _targetScore - currentBattingRuns;
                      int maxBallsForChase = _firstInningsValidBallsBowled > 0 ? _firstInningsValidBallsBowled : _maxOvers * 6;
                      int ballsBowledInChase = (_battingTeamName == widget.teamAName) ? _teamABalls : _teamBBalls;
                      int ballsRemaining = maxBallsForChase - ballsBowledInChase;
                      runsNeeded = runsNeeded < 0 ? 0 : runsNeeded;
                      ballsRemaining = ballsRemaining < 0 ? 0 : ballsRemaining;
                      _summaryText = "$_battingTeamName need $runsNeeded runs from $ballsRemaining balls.";
                 } else if (_currentPhase == ScoringPhase.finished || _currentPhase == ScoringPhase.matchEnd) {
                      _summaryText = loadedData['live_result'] ?? _summaryText; // Use final result if available
                 } else if (_currentPhase == ScoringPhase.inningsBreak && _targetScore > 0){
                      // Determine who batted first MORE reliably
                      String teamBattedFirstName = "";
                       if (_tossWinner != null && _tossDecision != null) {
                         bool teamABatsFirstLoad = (_tossWinner == widget.teamAName && _tossDecision == TossDecision.Bat) || (_tossWinner == widget.teamBName && _tossDecision == TossDecision.Bowl);
                         teamBattedFirstName = teamABatsFirstLoad ? widget.teamAName : widget.teamBName;
                       } else {
                         // Fallback if toss info missing somehow (shouldn't happen)
                         teamBattedFirstName = _isFirstInnings ? _battingTeamName : _bowlingTeamName;
                       }

                      String teamToChaseName = (teamBattedFirstName == widget.teamAName) ? widget.teamBName : widget.teamAName;
                      String inningsLimitDisplay = _formatOversLimit(_firstInningsValidBallsBowled);
                      _summaryText = "End of 1st Innings. Target for $teamToChaseName: $_targetScore in $inningsLimitDisplay overs";

                 } else if (_currentPhase == ScoringPhase.selectPlayers && _tossWinner != null) {
                     String decisionStr = _tossDecision == TossDecision.Bat ? "bat" : "bowl";
                     _summaryText = "$_tossWinner won the toss and chose to $decisionStr.";
                 } else if (_currentPhase == ScoringPhase.preMatch && _tossWinner == null) {
                     _summaryText = "Toss will happen soon.";
                 } else if ((_currentPhase == ScoringPhase.innings1 || _currentPhase == ScoringPhase.innings2) && currentInningsBalls == 0) {
                      // If starting innings 1 or 2 with 0 balls bowled
                     _summaryText = "$_battingTeamName is batting.";
                 }


                 print("Loaded existing live state successfully. Phase: $_currentPhase");
            });
        } else if (mounted && response.statusCode == 404) {
            print("No existing live update data found for match ${widget.matchId}. Starting fresh.");
             // Check actual match status to decide phase
             const String host = kIsWeb ? 'localhost' : '10.0.2.2';
             final statusResponse = await http.get(Uri.parse('http://$host:5000/api/get_match_details/${widget.matchId}'));
             if (mounted && statusResponse.statusCode == 200) {
                 final details = json.decode(statusResponse.body);
                 setState(() {
                      _matchStatusText = details['match_status'] ?? 'upcoming';
                      if (_matchStatusText == 'live') {
                        _currentPhase = ScoringPhase.preMatch; // Match started, but no scoring yet -> go to toss
                      } else if (_matchStatusText == 'finished') _currentPhase = ScoringPhase.finished;
                      else _currentPhase = ScoringPhase.preMatch; // Still upcoming
                 });
             } else { setState(() => _currentPhase = ScoringPhase.preMatch); } // Default to preMatch if details fail
        } else if (mounted) {
             _playerFetchError = 'Failed to load existing live state (${response.statusCode}). Starting fresh.';
             setState(() => _currentPhase = ScoringPhase.preMatch); print("$_playerFetchError Body: ${response.body}");
        }
     } catch(e) {
         if (mounted) { _playerFetchError = 'Error connecting to load live state. Starting fresh.'; setState(() => _currentPhase = ScoringPhase.preMatch); print("Error loading live state: $e"); }
     } finally {
         if (mounted) setState(() => _isLoadingPlayers = false); // Stop loading indicator
     }
     // --- END MODIFICATION ---
  }

  // --- Send Score Update to Backend ---
  Future<void> _sendScoreUpdateToBackend() async {
    // --- MODIFICATION: Re-enabled HTTP POST with JSON player data ---
    if (_isSaving) return;
    setState(() => _isSaving = true);
    print("Sending update for phase: $_currentPhase");

    const String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final String apiUrl = 'http://$host:5000/api/update_live_score/${widget.matchId}';

    // --- MODIFICATION: Pass current striker/nonStriker to toJson ---
    List<Map<String, dynamic>> team1BattingData = _fetchedTeamAPlayers.map((p) => p.toJson(_matchStatusText, _striker, _nonStriker)).toList();
    List<Map<String, dynamic>> team2BowlingData = _fetchedTeamBPlayers.map((p) => p.toJson(_matchStatusText, _striker, _nonStriker)).toList();
    List<Map<String, dynamic>> team2BattingData = _fetchedTeamBPlayers.map((p) => p.toJson(_matchStatusText, _striker, _nonStriker)).toList();
    List<Map<String, dynamic>> team1BowlingData = _fetchedTeamAPlayers.map((p) => p.toJson(_matchStatusText, _striker, _nonStriker)).toList();
    // --- END MODIFICATION ---


    // Determine current extras based on last sent state (or 0 if none)
    int currentTeam1Extras = _lastSentState?['team1_extras'] ?? 0;
    int currentTeam2Extras = _lastSentState?['team2_extras'] ?? 0;
    if (_battingTeamName == widget.teamAName) {
        currentTeam1Extras = _extras; // Update Team 1's extras
    } else if (_battingTeamName == widget.teamBName) {
        currentTeam2Extras = _extras; // Update Team 2's extras
    }

    final Map<String, dynamic> payload = {
        "toss_winner": _tossWinner,
        "toss_decision": _tossDecision?.toString().split('.').last, // "Bat" or "Bowl"
        "current_status": _matchStatusText,
        "live_result": (_currentPhase == ScoringPhase.matchEnd || _currentPhase == ScoringPhase.finished) ? _summaryText : null,
        "break_status": _currentPhase == ScoringPhase.inningsBreak ? "Innings Break" : null,
        "team1_name": widget.teamAName,
        "team2_name": widget.teamBName,
        "team1_runs": _teamARuns, "team1_wickets": _teamAWickets, "team1_balls": _teamABalls,
        "team2_runs": _teamBRuns, "team2_wickets": _teamBWickets, "team2_balls": _teamBBalls,
        "team1_extras": currentTeam1Extras, // Send updated extras count
        "team2_extras": currentTeam2Extras, // Send updated extras count
        "summary_text": _summaryText,
        "striker_id": _striker?.id,
        "non_striker_id": _nonStriker?.id,
        "bowler_id": _currentBowler?.id,
        "is_first_innings": _isFirstInnings,
        "target_score": _targetScore > 0 ? _targetScore : null, // Send null if not set
        "first_innings_balls": _firstInningsValidBallsBowled > 0 ? _firstInningsValidBallsBowled : null, // Send null if not set
        // "timeline": _timeline, // Removed
        "team1_timeline": _team1Timeline, // Added
        "team2_timeline": _team2Timeline, // Added
        // Send the JSON lists
        "team1_batting": team1BattingData,
        "team2_bowling": team2BowlingData,
        "team2_batting": team2BattingData,
        "team1_bowling": team1BowlingData,
    };
     _lastSentState = payload; // Keep track of the last sent state

    try {
      final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: json.encode(payload), // Encode the payload as JSON
      );
      if (mounted) {
          if (response.statusCode == 200) {
            print('Score update sent successfully.');
          } else {
            print('Error sending score update: ${response.statusCode} ${response.body}');
            ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error saving update: ${response.statusCode}'), backgroundColor: Colors.orange),);
          }
      }
    } catch (e) {
        if (mounted) {
          print('Failed to connect to server for score update: $e');
          ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Connection error saving update.'), backgroundColor: Colors.red),);
        }
    } finally {
        if (mounted) setState(() => _isSaving = false);
    }
    // --- END MODIFICATION ---
  }

 // Debounce function
  void _debounceAndSendUpdate() {
    // --- MODIFICATION: Re-enabled ---
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
        // Only send if not currently saving
        if (!_isSaving) {
            _sendScoreUpdateToBackend();
        } else {
            print("Debouncer skipped send: Already saving.");
        }
    });
    // Removed direct call: _sendScoreUpdateToBackend();
    // --- END MODIFICATION ---
 }

 // --- NO CHANGES NEEDED below this line for DB connection ---
 // (Logic remains the same, state variables are updated locally,
 //  and _debounceAndSendUpdate handles sending to backend)

  // Format overs (e.g., (2.1))
  String _formatOvers(int validBalls) {
    int overs = validBalls ~/ 6;
    int remainingBalls = validBalls % 6;
    return "($overs.$remainingBalls)";
  }

  // Format overs limit (e.g., 2.0)
  String _formatOversLimit(int validBalls) { if (validBalls <= 0) return "0.0"; int overs = validBalls ~/ 6; int remainingBalls = validBalls % 6; if (remainingBalls == 0 && overs >= 0) {
    return "$overs.0";
  } else if (overs == 0) return "0.$remainingBalls"; else return "$overs.$remainingBalls"; }

  // Swap strike
  void _swapStrike() { final temp = _striker; _striker = _nonStriker; _nonStriker = temp; }

  // Handle Ball Completion
  void _handleBallCompletion(String ballOutcomeDisplay, {bool countsAsBall = true, int runsScored = 0, bool isExtra = false, int extraRuns = 0, ExtraType? extraType}) {
      if (_currentPhase == ScoringPhase.matchEnd || _currentPhase == ScoringPhase.finished) return;
      _ballsThisOverDisplay.add(ballOutcomeDisplay);
      // _timeline.add(ballOutcomeDisplay); // Removed

      // Add to correct timeline
      if (_battingTeamName == widget.teamAName) {
        _team1Timeline.add(ballOutcomeDisplay);
      } else if (_battingTeamName == widget.teamBName) {
        _team2Timeline.add(ballOutcomeDisplay);
      }

      bool targetReached = false; int currentBattingTeamRuns = 0; int currentBallsBowledSecondInnings = 0;
      if (_battingTeamName == widget.teamAName) { _teamARuns += runsScored + extraRuns; currentBattingTeamRuns = _teamARuns; if(countsAsBall) _teamABalls++; if (!_isFirstInnings) { currentBallsBowledSecondInnings = _teamABalls; if (_targetScore != -1 && _teamARuns >= _targetScore) targetReached = true; } }
      else if (_battingTeamName == widget.teamBName) { _teamBRuns += runsScored + extraRuns; currentBattingTeamRuns = _teamBRuns; if(countsAsBall) _teamBBalls++; if (!_isFirstInnings) { currentBallsBowledSecondInnings = _teamBBalls; if (_targetScore != -1 && _teamBRuns >= _targetScore) targetReached = true; } }
      _extras += extraRuns;

      if (_striker != null && !isExtra) _striker!.runs += runsScored; if (_striker != null && countsAsBall) _striker!.ballsFaced++; if (_currentBowler != null) { _currentBowler!.runsConceded += runsScored + extraRuns; if (countsAsBall) _currentBowler!.ballsBowled++; }
      bool shouldSwap = false; int runsRunAsExtrasCalc = 0;
      if (countsAsBall) { if (!isExtra && runsScored % 2 != 0) {
        shouldSwap = true;
      } else if (isExtra && extraType != null && (extraType == ExtraType.LegBye || extraType == ExtraType.Bye)) { runsRunAsExtrasCalc = int.tryParse(ballOutcomeDisplay.replaceAll(RegExp(r'[a-zA-Z]'), '')) ?? 0; if (runsRunAsExtrasCalc % 2 != 0) shouldSwap = true; } }
      else if (extraType != null && (extraType == ExtraType.Wide || extraType == ExtraType.NoBall)) { int baseExtra = 1; runsRunAsExtrasCalc = (runsScored + extraRuns) - runsScored - baseExtra; runsRunAsExtrasCalc = runsRunAsExtrasCalc < 0 ? 0 : runsRunAsExtrasCalc; if (runsRunAsExtrasCalc % 2 != 0) shouldSwap = true; }
      bool isOverComplete = false; bool maxBallsReachedSecondInnings = false;
      if (countsAsBall) { if (_currentBallNumberInOver >= 6) { isOverComplete = true; } else { _currentBallNumberInOver++; } if (!_isFirstInnings && _firstInningsValidBallsBowled > 0) { if (currentBallsBowledSecondInnings >= _firstInningsValidBallsBowled) { maxBallsReachedSecondInnings = true; } } }
      if (shouldSwap && !isOverComplete) _swapStrike();

      // *** Refined End Condition Logic Order & Dead Code Fix ***
      bool matchEndedThisBall = false;
      if (targetReached) {
          _summaryText = "$_battingTeamName won the match.";
          _currentPhase = ScoringPhase.matchEnd;
           _matchStatusText = "Finished"; // Update status
          matchEndedThisBall = true;
      } else if (maxBallsReachedSecondInnings) {
          String bowlingTeamName = (_battingTeamName == widget.teamAName) ? widget.teamBName : widget.teamAName;
          if (currentBattingTeamRuns < _targetScore - 1) { int runsMargin = (_targetScore - 1) - currentBattingTeamRuns; _summaryText = "$bowlingTeamName won by $runsMargin runs."; }
          else if (currentBattingTeamRuns == _targetScore - 1) { _summaryText = "Match Tied."; }
          _currentPhase = ScoringPhase.matchEnd;
           _matchStatusText = "Finished"; // Update status
          if (_battingTeamName == widget.teamAName) {
            _teamABalls = _firstInningsValidBallsBowled;
          } else {
            _teamBBalls = _firstInningsValidBallsBowled;
          }
          matchEndedThisBall = true;
      }

      // Only handle over completion or summary update if the match didn't end on this ball
      if (!matchEndedThisBall) {
          if (isOverComplete) {
              _handleOverComplete(); // Normal over completion
          }
           // *** Corrected: Update summary text *unless* over is complete (handled in _handleOverComplete) ***
          else if (!_isFirstInnings && _targetScore != -1) {
              int runsNeeded = _targetScore - currentBattingTeamRuns;
              int maxBallsForChase = _firstInningsValidBallsBowled > 0 ? _firstInningsValidBallsBowled : _maxOvers * 6;
              int ballsBowled = currentBallsBowledSecondInnings;
              int ballsRemaining = maxBallsForChase - ballsBowled;
              runsNeeded = runsNeeded < 0 ? 0 : runsNeeded;
              ballsRemaining = ballsRemaining < 0 ? 0 : ballsRemaining;
              _summaryText = "$_battingTeamName need $runsNeeded runs from $ballsRemaining balls.";
          }
      }
      // If the match ended this ball AND it was the 6th ball, call handleOverComplete with flag
      else if (matchEndedThisBall && isOverComplete) {
           _handleOverComplete(matchJustEnded: true);
      }
   }

  // Record Run
  void _recordRun(int runs) { if (_currentPhase == ScoringPhase.matchEnd || _currentPhase == ScoringPhase.finished) return; _handleBallCompletion(runs.toString(), runsScored: runs); _debounceAndSendUpdate(); setState(() {}); }

  // Prompt for Extra Runs
  Future<int?> _promptForExtraRuns(BuildContext context, ExtraType extraType) async { String title = ''; List<int> possibleRuns = [0, 1, 2, 3, 4, 6]; switch(extraType) { case ExtraType.Wide: title = 'Runs run on Wide?'; possibleRuns = [0, 1, 2, 3, 4]; break; case ExtraType.NoBall: title = 'Runs scored off No Ball? (off bat)'; break; case ExtraType.LegBye: title = 'Leg Byes taken?'; possibleRuns = [1, 2, 3, 4]; break; case ExtraType.Bye: title = 'Byes taken?'; possibleRuns = [1, 2, 3, 4]; break; } int? selectedValue = await showDialog<int>( context: context, builder: (BuildContext context) { int? currentlySelected; return AlertDialog( title: Text(title), content: DropdownButton<int>( value: currentlySelected, hint: const Text("Select runs"), items: possibleRuns.map((run) => DropdownMenuItem(value: run, child: Text('$run'))).toList(), onChanged:(value) { currentlySelected = value; Navigator.of(context).pop(currentlySelected); }, ), actions: [ TextButton( onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel'),)]); },); return selectedValue ?? 0; }

  // Record Extra
  void _recordExtra(ExtraType extraType) async { if (_currentPhase == ScoringPhase.matchEnd || _currentPhase == ScoringPhase.finished) return; int baseExtraRuns = 0; int runsScoredOffBat = 0; int runsRunAsExtras = 0; String outcomePrefix = ""; bool countsAsBall = true; int? selectedRuns; switch(extraType) { case ExtraType.Wide: baseExtraRuns = 1; outcomePrefix = "Wd"; countsAsBall = false; selectedRuns = await _promptForExtraRuns(context, extraType); runsRunAsExtras = selectedRuns ?? 0; break; case ExtraType.NoBall: baseExtraRuns = 1; outcomePrefix = "Nb"; countsAsBall = false; selectedRuns = await _promptForExtraRuns(context, extraType); runsScoredOffBat = selectedRuns ?? 0; break; case ExtraType.LegBye: outcomePrefix = "Lb"; countsAsBall = true; selectedRuns = await _promptForExtraRuns(context, extraType); runsRunAsExtras = selectedRuns ?? 0; if (runsRunAsExtras == 0) return; outcomePrefix = "${runsRunAsExtras}Lb"; break; case ExtraType.Bye: outcomePrefix = "B"; countsAsBall = true; selectedRuns = await _promptForExtraRuns(context, extraType); runsRunAsExtras = selectedRuns ?? 0; if (runsRunAsExtras == 0) return; outcomePrefix = "${runsRunAsExtras}B"; break; } String displayOutcome = outcomePrefix; int totalRunsForBall = baseExtraRuns + runsRunAsExtras + runsScoredOffBat; if (extraType == ExtraType.NoBall) {
    displayOutcome = "${totalRunsForBall > 1 ? "$totalRunsForBall" : ""}Nb";
  } else if (extraType == ExtraType.Wide) displayOutcome = "${totalRunsForBall > 1 ? "$totalRunsForBall" : ""}Wd"; _handleBallCompletion( displayOutcome, countsAsBall: countsAsBall, runsScored: runsScoredOffBat, extraRuns: baseExtraRuns + runsRunAsExtras, isExtra: true, extraType: extraType ); _debounceAndSendUpdate(); setState(() {}); }

  // Prompt for Next Batsman
  Future<Player?> _promptForNextBatsman(BuildContext context) async { List<Player> battingTeamPlayers = (_battingTeamName == widget.teamAName) ? _fetchedTeamAPlayers : _fetchedTeamBPlayers; List<Player> availableBatsmen = battingTeamPlayers.where((p) => !p.isOut && p.id != _striker?.id && p.id != _nonStriker?.id).toList(); if (availableBatsmen.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All batsmen are out!"))); return null; } Player? selectedBatsman; return await showDialog<Player>( context: context, barrierDismissible: false, builder: (BuildContext context) { return StatefulBuilder( builder: (context, setDialogState) { return AlertDialog( title: const Text('Select Next Batsman'), content: DropdownButtonFormField<Player>( initialValue: selectedBatsman, hint: const Text("Choose batsman"), items: availableBatsmen.map((p) => DropdownMenuItem( value: p, child: Text(p.name))).toList(), onChanged:(value) { setDialogState(() { selectedBatsman = value; }); },), actions: [ TextButton( onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')), TextButton( onPressed: selectedBatsman == null ? null : () => Navigator.of(context).pop(selectedBatsman), child: const Text('Confirm')),] );});},); }

  // Record Wicket
  void _recordWicket() async { if (_currentPhase == ScoringPhase.matchEnd || _currentPhase == ScoringPhase.finished) return; bool wicketCountsAsBall = true; int runsOnWicketBall = 0; String dismissalDesc = "Wicket"; Player? dismissedBatsman = _striker; /* TODO: Wicket Dialog */ if (dismissedBatsman == null && _nonStriker == null) return; dismissedBatsman ??= _nonStriker; dismissedBatsman!.isOut = true; dismissedBatsman.dismissalInfo = dismissalDesc; if (!_dismissedBatsmen.any((p) => p.id == dismissedBatsman!.id)) { _dismissedBatsmen.add(dismissedBatsman); } if (_battingTeamName == widget.teamAName) { if (_teamAWickets < 10) _teamAWickets++; } else if (_battingTeamName == widget.teamBName) { if (_teamBWickets < 10) _teamBWickets++; } if(_currentBowler != null) { _currentBowler!.wicketsTaken++; } _handleBallCompletion("W", countsAsBall: wicketCountsAsBall, runsScored: runsOnWicketBall); if (_currentPhase == ScoringPhase.matchEnd || _currentPhase == ScoringPhase.finished) { _debounceAndSendUpdate(); setState((){}); return; } bool inningsEndedByWickets = (_battingTeamName == widget.teamAName && _teamAWickets >= 10) || (_battingTeamName == widget.teamBName && _teamBWickets >= 10); bool inningsEndedByTarget = !_isFirstInnings && _targetScore != -1 && ((_battingTeamName == widget.teamAName && _teamARuns >= _targetScore) || (_battingTeamName == widget.teamBName && _teamBRuns >= _targetScore)); bool inningsEnded = inningsEndedByWickets || inningsEndedByTarget; Player? nextBatsman; if (!inningsEnded) { nextBatsman = await _promptForNextBatsman(context); if (nextBatsman == null) print("Warning: Wicket recorded, but no next batsman selected."); } setState(() { bool crossed = false; if (dismissedBatsman?.id == _striker?.id) { _striker = crossed ? _nonStriker : nextBatsman; if (crossed) _nonStriker = nextBatsman; } else { _nonStriker = nextBatsman; if(crossed) _swapStrike(); } if (_striker == null && _nonStriker != null) _striker = _nonStriker; if (_striker != null && _nonStriker != null && _striker!.id == _nonStriker!.id) _nonStriker = null; if (_striker == null && _nonStriker == null && nextBatsman != null) _striker = nextBatsman; inningsEnded = (_battingTeamName == widget.teamAName && _teamAWickets >= 10) || (_battingTeamName == widget.teamBName && _teamBWickets >= 10) || inningsEndedByTarget; if (inningsEnded) { if(_isFirstInnings) { _currentPhase = ScoringPhase.inningsBreak; _matchStatusText = "Innings Break"; } // Update status
 else { _currentPhase = ScoringPhase.matchEnd; _matchStatusText = "Finished"; } // Update status
 if (inningsEndedByTarget) { _summaryText = "$_battingTeamName won the match."; } else { if (_isFirstInnings) { _summaryText = "End of 1st Innings"; } else { int battingTeamRuns = (_battingTeamName == widget.teamAName) ? _teamARuns : _teamBRuns; String bowlingTeamName = (_battingTeamName == widget.teamAName) ? widget.teamBName : widget.teamAName; if (battingTeamRuns < _targetScore - 1) { int runsMargin = (_targetScore - 1) - battingTeamRuns; _summaryText = "$bowlingTeamName won by $runsMargin runs."; } else if (battingTeamRuns == _targetScore - 1) { _summaryText = "Match Tied."; } } } } _debounceAndSendUpdate(); }); }

  // Handle Over Complete
  void _handleOverComplete({bool matchJustEnded = false}) {
      if (matchJustEnded) { if (_currentBowler != null && _currentBowler!.ballsBowled > 0 && !_bowlersUsed.any((b) => b.id == _currentBowler!.id)) { _bowlersUsed.add(_currentBowler!); } return; }
      if (_currentBowler != null && _currentBowler!.ballsBowled > 0 && !_bowlersUsed.any((b) => b.id == _currentBowler!.id)) { _bowlersUsed.add(_currentBowler!); }

      int currentInningsBalls = (_battingTeamName == widget.teamAName) ? _teamABalls : _teamBBalls;
      bool maxOversReached = false;
      if (_isFirstInnings) {
         maxOversReached = currentInningsBalls >= _maxOvers * 6;
      } else {
         int maxBallsForChase = _firstInningsValidBallsBowled > 0 ? _firstInningsValidBallsBowled : _maxOvers * 6;
         maxOversReached = currentInningsBalls >= maxBallsForChase;
      }


      if (maxOversReached) {
           if(_isFirstInnings) {
               _firstInningsValidBallsBowled = currentInningsBalls;
               _targetScore = (_battingTeamName == widget.teamAName ? _teamARuns : _teamBRuns) + 1;
               _summaryText = "End of 1st Innings. Target: $_targetScore";
                setState(() {
                  _currentPhase = ScoringPhase.inningsBreak;
                   _matchStatusText = "Innings Break";
                 });
           } else {
               int battingTeamRuns = (_battingTeamName == widget.teamAName) ? _teamARuns : _teamBRuns;
               String bowlingTeamName = (_battingTeamName == widget.teamAName) ? widget.teamBName : widget.teamAName;
               if (_targetScore == -1) { _summaryText = "Match Ended (Incomplete)"; }
               else if (battingTeamRuns >= _targetScore) { _summaryText = "$_battingTeamName won the match."; }
               else if (battingTeamRuns < _targetScore - 1) { int runsMargin = (_targetScore - 1) - battingTeamRuns; _summaryText = "$bowlingTeamName won by $runsMargin runs."; }
               else { _summaryText = "Match Tied."; }
               setState(() {
                 _currentPhase = ScoringPhase.matchEnd;
                  _matchStatusText = "Finished";
                });
           }
           _debounceAndSendUpdate(); // Send final state after max overs reached
           return; // Don't proceed to next over logic
      }


      _currentOverNumber++; _currentBallNumberInOver = 1; _ballsThisOverDisplay = []; _swapStrike();
      if (_currentPhase != ScoringPhase.matchEnd && _currentPhase != ScoringPhase.finished) {
         ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text('Over $_currentOverNumber starting. Select next bowler.'), backgroundColor: Colors.blueGrey,),);
         _currentBowler = null;
         _debounceAndSendUpdate();
         setState((){});
      }
   }

  // Build method
  @override
  Widget build(BuildContext context) { final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors; bool showLoadingIndicator = _isLoadingPlayers || _isSaving; return Scaffold( appBar: AppBar( title: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('Update Live Score'), if (showLoadingIndicator) const Padding( padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),) else const SizedBox(width: 36),],), backgroundColor: Theme.of(context).primaryColor,), body: AnimatedContainer( duration: const Duration(milliseconds: 500), decoration: BoxDecoration( gradient: LinearGradient( colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter,),), child: SingleChildScrollView( padding: const EdgeInsets.all(16.0), child: Column( children: [ _buildScoreDisplay(), const SizedBox(height: 16), _buildScoringInterface(), ],),),),); }

  // Score Display Widget
  Widget _buildScoreDisplay() { String currentTeamAScore = "$_teamARuns/$_teamAWickets"; String currentTeamAOvers = _formatOvers(_teamABalls); String currentTeamBScore = "$_teamBRuns/$_teamBWickets"; String currentTeamBOvers = _formatOvers(_teamBBalls); return Card( elevation: 2, shadowColor: Colors.black.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Column( children: [ _buildAdminScoreboardContent( teamA: widget.teamAName, teamB: widget.teamBName, teamAScore: currentTeamAScore, teamAOvers: currentTeamAOvers, teamBScore: currentTeamBScore, teamBOvers: currentTeamBOvers, matchStatus: _matchStatusText,), Padding( padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0), child: Text( _summaryText, style: const TextStyle( color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center,),), const Padding( padding: EdgeInsets.symmetric(horizontal: 16.0), child: Divider(height: 1),), _buildAdminPlayerDetailsContent( bowlingTeamName: _bowlingTeamName, battingTeamName: _battingTeamName, bowlerOnStrikeName: _currentBowler?.name ?? "N/A", bowlerOnStrikeFigures: _currentBowler?.getBowlerFigures() ?? "-", bowlerOffStrikeName: "N/A", bowlerOffStrikeFigures: "-", strikerPlayer: _striker, nonStrikerPlayer: _nonStriker,), const SizedBox(height: 12),],),); }

  // --- SCORECARD PREVIEW WIDGETS ---
  Widget _buildAdminScoreboardContent({ required String teamA, required String teamB, required String teamAScore, required String teamAOvers, required String teamBScore, required String teamBOvers, required String matchStatus, }) { return Container( padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded( child: Column( children: [ Text(teamA, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 6), Text(teamAScore, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), Text(teamAOvers, style: const TextStyle(fontSize: 11, color: Colors.black54)), ],),), Padding( padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text( matchStatus, style: TextStyle( fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.bold),),), Expanded( child: Column( children: [ Text(teamB, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 6), Text(teamBScore, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), Text(teamBOvers, style: const TextStyle(fontSize: 11, color: Colors.black54)), ],),), ],),); }
  Widget _buildAdminPlayerDetailsContent({ required String bowlingTeamName, required String battingTeamName, required String bowlerOnStrikeName, required String bowlerOnStrikeFigures, required String bowlerOffStrikeName, required String bowlerOffStrikeFigures, Player? strikerPlayer, Player? nonStrikerPlayer, }) { const Color textColor = Colors.black87; final Color titleColor = Colors.grey[700]!; String bowlingTitle = bowlingTeamName.isNotEmpty ? '$bowlingTeamName Bowling' : 'Bowling'; String battingTitle = battingTeamName.isNotEmpty ? '$battingTeamName Batting' : 'Batting'; String batsmanOnStrikeName = strikerPlayer?.name ?? "N/A"; String batsmanOnStrikeScore = strikerPlayer?.getBatsmanScore() ?? "-"; String batsmanOffStrikeName = nonStrikerPlayer?.name ?? "N/A"; String batsmanOffStrikeScore = nonStrikerPlayer?.getBatsmanScore() ?? "-"; if (strikerPlayer != null) batsmanOnStrikeName += "*"; return Container( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [ Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(bowlingTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 10), _buildPlayerStat(context: context, name: bowlerOnStrikeName, stat: bowlerOnStrikeFigures, isBatting: false, textColor: textColor), const SizedBox(height: 6), _buildPlayerStat(context: context, name: bowlerOffStrikeName, stat: bowlerOffStrikeFigures, isBatting: false, textColor: textColor),],),), const SizedBox(width: 16), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.end, children: [ Text(battingTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 10), _buildPlayerStat(context: context, name: batsmanOnStrikeName, stat: batsmanOnStrikeScore, isBatting: true, textColor: textColor), const SizedBox(height: 6), _buildPlayerStat(context: context, name: batsmanOffStrikeName, stat: batsmanOffStrikeScore, isBatting: true, textColor: textColor),],),),],),); }
  Widget _buildPlayerStat({ required BuildContext context, required String name, required String stat, required bool isBatting, required Color textColor}) { String combinedText = "$name: $stat"; if (name == 'N/A' || name.isEmpty || name == "N/A*") combinedText = "-"; return Row( mainAxisAlignment: isBatting ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.start, children: [ Flexible( child: Text( combinedText, style: TextStyle(fontSize: 11, color: textColor), softWrap: false, overflow: TextOverflow.ellipsis,),),],); }
  Widget _buildBallWidget(String ballOutcome) { Color bgColor; Color textColor = Colors.white; bool isEmpty = ballOutcome.isEmpty; if (isEmpty) { bgColor = Colors.grey.shade300; ballOutcome = ''; } else { String lowerOutcome = ballOutcome.toLowerCase(); bool isWicket = lowerOutcome == 'w'; bool isBoundary = lowerOutcome.startsWith('4') || lowerOutcome.startsWith('6'); bool isExtraIndicator = lowerOutcome.endsWith('wd') || lowerOutcome.endsWith('nb') || lowerOutcome.endsWith('lb') || lowerOutcome.endsWith('b'); if (isWicket) {
    bgColor = Colors.red.shade700;
  } else if (isBoundary && !isExtraIndicator) bgColor = Colors.green.shade700; else if (isExtraIndicator) bgColor = Colors.blueGrey.shade400; else bgColor = (lowerOutcome == '0') ? Colors.grey.shade500 : Colors.grey.shade700;} return Container( padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), margin: const EdgeInsets.symmetric(horizontal: 2.5), decoration: BoxDecoration( color: bgColor, borderRadius: BorderRadius.circular(4), border: isEmpty ? Border.all(color: Colors.grey.shade500, width: 0.5) : null, ), constraints: const BoxConstraints(minWidth: 24, minHeight: 24), alignment: Alignment.center, child: Text( ballOutcome, style: TextStyle( color: isEmpty ? Colors.transparent : textColor, fontWeight: FontWeight.bold, fontSize: 12,),),); }
  // --- END SCORECARD PREVIEW WIDGETS ---

  // Main UI switcher
  Widget _buildScoringInterface() { bool showSavingIndicator = _isSaving && !_isLoadingPlayers; return Stack( children: [ if (_isLoadingPlayers) Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)) else if (_playerFetchError.isNotEmpty) Center(child: Padding( padding: const EdgeInsets.all(16.0), child: Text(_playerFetchError, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center,))) else AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _buildPhaseSpecificWidget(),), if (showSavingIndicator) Positioned.fill( child: Container( color: Colors.black.withOpacity(0.1), child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),),),],); }

   // Helper to return widget for current phase
   Widget _buildPhaseSpecificWidget() {
       switch (_currentPhase) {
          case ScoringPhase.preMatch: return _buildTossSection(key: const ValueKey('toss'));
          case ScoringPhase.selectPlayers: return _buildPlayerSelectionSection(key: const ValueKey('selectPlayers'));
          case ScoringPhase.innings1: case ScoringPhase.innings2: return _buildBallByBallSection(key: const ValueKey('scoring'));
          case ScoringPhase.inningsBreak: return _buildInningsBreakSection(key: const ValueKey('break'));
          // --- FIX: Added case for matchEnd to call the missing function ---
          case ScoringPhase.matchEnd: return _buildMatchResultSection(key: const ValueKey('result'));
          // --- END FIX ---
          case ScoringPhase.finished: return Center( key: const ValueKey('finished'), child: Card( child: Padding( padding: const EdgeInsets.all(16.0), child: Text('Match Finished: $_summaryText'), )));
          // No default needed and no fallback return needed as all cases are covered.
       }
   }


  // --- Widgets for each phase ---
  Widget _buildTossSection({Key? key}) { return Card( key: key, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [ Text('Toss Details', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)), const SizedBox(height: 20), DropdownButtonFormField<String>( initialValue: _tossWinner, hint: const Text('Select Toss Winner'), decoration: InputDecoration( labelText: 'Toss Winner', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.military_tech_outlined),), items: [widget.teamAName, widget.teamBName].map((team) => DropdownMenuItem(value: team, child: Text(team))).toList(), onChanged: (value) { setState(() { _tossWinner = value; }); },), const SizedBox(height: 16), const Text('Toss Decision', style: TextStyle(fontWeight: FontWeight.w500)), Row( children: [ Expanded( child: RadioListTile<TossDecision>( title: const Text('Bat'), value: TossDecision.Bat, groupValue: _tossDecision, onChanged: (value) { setState(() { _tossDecision = value; }); }, ),), Expanded( child: RadioListTile<TossDecision>( title: const Text('Bowl'), value: TossDecision.Bowl, groupValue: _tossDecision, onChanged: (value) { setState(() { _tossDecision = value; }); }, ),), ],), const SizedBox(height: 20), ElevatedButton.icon( icon: const Icon(Icons.arrow_forward), label: const Text('Confirm Toss & Select Players'), style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12),), onPressed: () { if (_tossWinner == null || _tossDecision == null) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Please select toss winner and decision.'), backgroundColor: Colors.red,),); return; } setState(() { String decisionStr = _tossDecision == TossDecision.Bat ? "bat" : "bowl"; _summaryText = "$_tossWinner won the toss and chose to $decisionStr."; if ((_tossWinner == widget.teamAName && _tossDecision == TossDecision.Bat) || (_tossWinner == widget.teamBName && _tossDecision == TossDecision.Bowl)) { _battingTeamName = widget.teamAName; _bowlingTeamName = widget.teamBName; } else { _battingTeamName = widget.teamBName; _bowlingTeamName = widget.teamAName; } _currentPhase = ScoringPhase.selectPlayers; _sendScoreUpdateToBackend(); }); },) ],),),); }
  Widget _buildPlayerDropdown({ required Player? value, required String label, required IconData icon, required List<Player> players, required ValueChanged<Player?> onChanged, Player? disabledPlayer, }) { return DropdownButtonFormField<Player>( initialValue: value, hint: Text(label), decoration: InputDecoration( labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(icon),), items: players .map((player) => DropdownMenuItem( value: player, enabled: (!player.isOut && (disabledPlayer == null || player.id != disabledPlayer.id)), child: Text( player.name + (player.isOut ? " (Out)" : ""), style: TextStyle( color: (player.isOut || (disabledPlayer != null && player.id == disabledPlayer.id)) ? Colors.grey : null,),),)).toList(), onChanged: onChanged,); }
  Widget _buildPlayerSelectionSection({Key? key}) { final battingPlayers = (_battingTeamName == widget.teamAName) ? _fetchedTeamAPlayers : _fetchedTeamBPlayers; final bowlingPlayers = (_bowlingTeamName == widget.teamAName) ? _fetchedTeamAPlayers : _fetchedTeamBPlayers; final availableBatsmen = battingPlayers.where((p) => !p.isOut).toList(); final availableBowlers = bowlingPlayers.where((p) => !p.isOut).toList(); return Card( key: key, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [ Text('Select Opening Players', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)), const SizedBox(height: 20), Text('Batting Team: $_battingTeamName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 16), _buildPlayerDropdown( value: _striker, label: 'Select Striker (Batsman 1)', icon: Icons.sports_cricket, players: availableBatsmen, disabledPlayer: _nonStriker, onChanged: (player) { setState(() { _striker = player; }); },), const SizedBox(height: 16), _buildPlayerDropdown( value: _nonStriker, label: 'Select Non-Striker (Batsman 2)', icon: Icons.sports_cricket, players: availableBatsmen, disabledPlayer: _striker, onChanged: (player) { setState(() { _nonStriker = player; }); },), const SizedBox(height: 24), Text('Bowling Team: $_bowlingTeamName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 16), _buildPlayerDropdown( value: _currentBowler, label: 'Select Opening Bowler', icon: Icons.sports, players: availableBowlers, onChanged: (player) { setState(() { _currentBowler = player; }); },), const SizedBox(height: 24), ElevatedButton.icon( icon: const Icon(Icons.play_arrow), label: Text(_isFirstInnings ? 'Start 1st Innings' : 'Start 2nd Innings'), style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12),), onPressed: () { if (_striker == null || _nonStriker == null || _currentBowler == null) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Please select all three players.'), backgroundColor: Colors.red,),); return; } if (_striker!.id == _nonStriker!.id) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Striker and Non-Striker cannot be the same player.'), backgroundColor: Colors.red,),); return; } setState(() { if (_isFirstInnings) { _teamARuns = 0; _teamAWickets = 0; _teamABalls = 0; _teamBRuns = 0; _teamBWickets = 0; _teamBBalls = 0; _targetScore = -1; _firstInningsValidBallsBowled = 0; for (var p in _fetchedTeamAPlayers) { p.runs=0; p.ballsFaced=0; p.ballsBowled=0; p.runsConceded=0; p.wicketsTaken=0; p.isOut=false; p.dismissalInfo="";} for (var p in _fetchedTeamBPlayers) { p.runs=0; p.ballsFaced=0; p.ballsBowled=0; p.runsConceded=0; p.wicketsTaken=0; p.isOut=false; p.dismissalInfo="";} } else { List<Player> newBattingTeamPlayers = (_battingTeamName == widget.teamAName) ? _fetchedTeamAPlayers : _fetchedTeamBPlayers; for (var p in newBattingTeamPlayers) { p.runs=0; p.ballsFaced=0; p.isOut = false; p.dismissalInfo=""; } List<Player> newBowlingTeamPlayers = (_bowlingTeamName == widget.teamAName) ? _fetchedTeamAPlayers : _fetchedTeamBPlayers; for (var p in newBowlingTeamPlayers) { p.ballsBowled=0; p.runsConceded=0; p.wicketsTaken=0;} } _currentOverNumber = 1; _currentBallNumberInOver = 1; /* _ballsBowledThisOverRaw = 0; */ _ballsThisOverDisplay = []; _extras = 0; _dismissedBatsmen = []; _bowlersUsed = [];
    // Clear timelines only on 1st innings start
    if (_isFirstInnings) {
      _team1Timeline = [];
      _team2Timeline = [];
    }
    _summaryText = "$_battingTeamName is batting.";
    _matchStatusText = "Live";
 if (!_isFirstInnings && _targetScore > 0) { // Check target score > 0
 int ballsRemaining = _firstInningsValidBallsBowled > 0 ? _firstInningsValidBallsBowled : _maxOvers * 6;
 _summaryText = "$_battingTeamName need $_targetScore runs from $ballsRemaining balls."; } _currentPhase = _isFirstInnings ? ScoringPhase.innings1 : ScoringPhase.innings2; _sendScoreUpdateToBackend(); }); },) ],),),); }
  Widget _buildBallByBallSection({Key? key}) { final theme = Theme.of(context); final bool bowlerNeeded = _currentBowler == null; final ButtonStyle outcomeButtonStyle = ElevatedButton.styleFrom( minimumSize: const Size(45, 45), padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), backgroundColor: theme.primaryColor.withOpacity(0.15), foregroundColor: theme.primaryColor, side: BorderSide(color: theme.primaryColor.withOpacity(0.4)), elevation: 1,); final ButtonStyle wicketButtonStyle = ElevatedButton.styleFrom( minimumSize: const Size(45, 45), padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, elevation: 2,); return Card( key: key, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ Text( _isFirstInnings ? '1st Innings Scoring' : '2nd Innings Scoring', textAlign: TextAlign.center, style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)), const SizedBox(height: 12), Text('Bowler: ${_currentBowler?.name ?? 'Select Next Bowler'}'), const SizedBox(height: 4), RichText( textAlign: TextAlign.center, text: TextSpan( style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12), children: <TextSpan>[ TextSpan( text: '${_striker?.name ?? "N/A"}*', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan( text: ' (${_striker?.runs ?? 0}/${_striker?.ballsFaced ?? 0})', style: TextStyle(color: Colors.grey[700])), const TextSpan(text: '  |  '), TextSpan( text: '${_nonStriker?.name ?? "N/A"} ', style: const TextStyle(fontWeight: FontWeight.normal)), TextSpan( text: '(${_nonStriker?.runs ?? 0}/${_nonStriker?.ballsFaced ?? 0})', style: TextStyle(color: Colors.grey[700])),],),), const Divider(height: 20), Text('Over $_currentOverNumber | Ball $_currentBallNumberInOver', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), SingleChildScrollView( scrollDirection: Axis.horizontal, child: Row( children: _ballsThisOverDisplay.map((outcome) => _buildBallWidget(outcome)).toList(),),), const Divider(height: 20), if (bowlerNeeded) _buildNextBowlerSelector() else Column( children: [ const Text('Enter Ball Outcome:', textAlign: TextAlign.center), const SizedBox(height: 12), Wrap( spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.center, children: [0, 1, 2, 3, 4, 6].map((runs) => ElevatedButton( onPressed: () => _recordRun(runs), style: outcomeButtonStyle, child: Text('$runs'),)).toList(),), const SizedBox(height: 12), Wrap( spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.center, children: [ ElevatedButton(onPressed: () => _recordExtra(ExtraType.Wide), style: outcomeButtonStyle, child: const Text('Wd')), ElevatedButton(onPressed: () => _recordExtra(ExtraType.NoBall), style: outcomeButtonStyle, child: const Text('Nb')), ElevatedButton(onPressed: () => _recordExtra(ExtraType.LegBye), style: outcomeButtonStyle, child: const Text('Lb')), ElevatedButton(onPressed: _recordWicket, style: wicketButtonStyle, child: const Text('W')),],),],), const SizedBox(height: 20), if (_dismissedBatsmen.isNotEmpty) ...[ const Text("Fall of Wickets", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Column( crossAxisAlignment: CrossAxisAlignment.start, children: _dismissedBatsmen.map((p) => Padding( padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text( "${_dismissedBatsmen.indexOf(p)+1}. ${p.name} ${p.dismissalInfo} ${p.runs}(${p.ballsFaced})", style: TextStyle(fontSize: 11, color: Colors.grey[700]),),)).toList()), const Divider(height: 16),], if (_bowlersUsed.isNotEmpty) ...[ const Text("Bowlers", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Column( crossAxisAlignment: CrossAxisAlignment.start, children: _bowlersUsed.map((p) => Padding( padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text( "${p.name}: ${p.getBowlerFigures()}", style: TextStyle(fontSize: 11, color: Colors.grey[700]),),)).toList()), const Divider(height: 16),], const SizedBox(height: 10), ElevatedButton( style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.blueGrey,), onPressed: () { showDialog( context: context, barrierDismissible: false, builder: (BuildContext context) { return AlertDialog( title: const Text('End Innings?'), content: Text('Are you sure you want to end the ${ _isFirstInnings ? "1st" : "2nd"} innings?'), actions: <Widget>[ TextButton( child: const Text('Cancel'), onPressed: () { Navigator.of(context).pop(); },), TextButton( child: const Text('End Innings'), onPressed: () { Navigator.of(context).pop(); if (_isFirstInnings) { _firstInningsValidBallsBowled = (_battingTeamName == widget.teamAName) ? _teamABalls : _teamBBalls; _targetScore = (_battingTeamName == widget.teamAName ? _teamARuns : _teamBRuns) + 1; _summaryText = "End of 1st Innings. Target: $_targetScore"; setState(() { _currentPhase = ScoringPhase.inningsBreak; _matchStatusText = "Innings Break"; }); } else { int battingTeamRuns = (_battingTeamName == widget.teamAName) ? _teamARuns : _teamBRuns; String bowlingTeamName = (_battingTeamName == widget.teamAName) ? widget.teamBName : widget.teamAName; if (_targetScore == -1) { _summaryText = "Match Ended (Incomplete)"; } else if (battingTeamRuns >= _targetScore) { _summaryText = "$_battingTeamName won the match."; } else if (battingTeamRuns < _targetScore - 1) { int runsMargin = (_targetScore - 1) - battingTeamRuns; _summaryText = "$bowlingTeamName won by $runsMargin runs."; } else { _summaryText = "Match Tied."; } setState(() { _currentPhase = ScoringPhase.matchEnd; _matchStatusText = "Finished"; }); } _sendScoreUpdateToBackend(); },),],);},);}, child: Text(_isFirstInnings ? 'End 1st Innings' : 'End 2nd Innings'),), ],),),); }
  Widget _buildNextBowlerSelector() { final bowlingPlayers = (_battingTeamName == widget.teamAName) ? _fetchedTeamAPlayers : _fetchedTeamBPlayers; Player? previousBowler; if (_bowlersUsed.isNotEmpty) { previousBowler = _bowlersUsed.last; } final availableBowlers = bowlingPlayers.where((p) => !p.isOut).toList(); return Padding( padding: const EdgeInsets.only(bottom: 16.0), child: _buildPlayerDropdown( value: _currentBowler, label: 'Select Bowler for Over $_currentOverNumber', icon: Icons.sports, players: availableBowlers, disabledPlayer: previousBowler, onChanged: (player) { if (previousBowler != null && player?.id == previousBowler.id) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot select the same bowler for consecutive overs."), duration: Duration(seconds: 2),)); return; } setState(() { _currentBowler = player; _debounceAndSendUpdate(); }); },),); }

  // --- FIX: Corrected typo and added status update in _buildInningsBreakSection ---
  Widget _buildInningsBreakSection({Key? key}) {
    String chasingTeamName = (_battingTeamName == widget.teamAName) ? widget.teamBName : widget.teamAName;
    String teamToChase = (chasingTeamName == widget.teamAName) ? widget.teamBName : widget.teamAName;
    String inningsLimitDisplay = _formatOversLimit(_firstInningsValidBallsBowled);
    return Card(
        key: key,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Innings Break',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 20),
                  Text(
                    'Target for $teamToChase: $_targetScore runs in $inningsLimitDisplay overs',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Start 2nd Innings'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                      onPressed: () {
                        setState(() {
                          _isFirstInnings = false;
                          _currentPhase = ScoringPhase.selectPlayers;
                          // --- FIX: Update match status text ---
                          _matchStatusText = "Live";
                          // --- END FIX ---
                          final tempTeam = _battingTeamName;
                          _battingTeamName = _bowlingTeamName;
                          _bowlingTeamName = tempTeam; // Corrected typo was here
                          _striker = null;
                          _nonStriker = null;
                          _currentBowler = null;
                          _dismissedBatsmen = [];
                          _bowlersUsed = [];
                          _currentOverNumber = 1;
                          _currentBallNumberInOver = 1;
                          _ballsThisOverDisplay = [];
                          _extras = 0;
                          // Recalculate balls remaining for the summary
                          int ballsRemaining = _firstInningsValidBallsBowled > 0 ? _firstInningsValidBallsBowled : _maxOvers * 6;
                          _summaryText = "$_battingTeamName need $_targetScore runs from $ballsRemaining balls.";
                          _sendScoreUpdateToBackend();
                        });
                      },
                  ),
                ],
            ),
        ),
    );
  }
  // --- END FIX ---

  // --- NEW FUNCTION: PDF DOWNLOAD LOGIC ---
  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting download...'), backgroundColor: Colors.blue),
    );

    const String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final String apiUrl = 'http://$host:5000/api/download_scorecard_pdf/${widget.matchId}';
    final String downloadFileName = 'scorecard_match_${widget.matchId}.pdf';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (mounted) {
        if (response.statusCode == 200) {
          final pdfBytes = response.bodyBytes;

          if (kIsWeb) {
            // --- WEB DOWNLOAD LOGIC ---
            final blob = html.Blob([pdfBytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute("download", downloadFileName)
              ..click();
            html.Url.revokeObjectUrl(url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download started in browser.'), backgroundColor: Colors.green),
            );
            // --- END WEB LOGIC ---
          } else {
            // --- MOBILE DOWNLOAD LOGIC (Existing) ---
            var status = await Permission.storage.request();
            if (!status.isGranted) {
              if (await Permission.storage.isPermanentlyDenied) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permission denied. Please enable storage permission in app settings.'), backgroundColor: Colors.red),
                );
                await openAppSettings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Storage permission is required to download files.'), backgroundColor: Colors.red),
                );
              }
              setState(() => _isDownloadingPdf = false);
              return;
            }

            Directory? dir = await getDownloadsDirectory();
            if (dir == null) {
              throw Exception('Could not find downloads directory.');
            }
            final String savePath = "${dir.path}/$downloadFileName";

            File file = File(savePath);
            await file.writeAsBytes(pdfBytes);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved to ${dir.path.split('/').last}'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    OpenFile.open(savePath);
                  },
                ),
              ),
            );
            await OpenFile.open(savePath);
            // --- END MOBILE LOGIC ---
          }
        } else {
          final error = json.decode(response.body)['message'] ?? 'Unknown error';
          throw Exception('Failed to download PDF: $error');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }
  // --- END NEW FUNCTION ---

  // --- MODIFICATION: Add button to _buildMatchResultSection ---
  Widget _buildMatchResultSection({Key? key}) {
    String resultText = _summaryText; // Use the summary text which should hold the result
    return Card(
        key: key,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Match Result',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 20),
                  Text(resultText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Confirm & Save Result'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          ),
                      onPressed: () {
                        // Ensure status is Finished before final save
                        _matchStatusText = "Finished";
                        // Send the final state to the backend
                        _sendScoreUpdateToBackend();
                        // Update UI to finished state
                        setState(() {
                          _currentPhase = ScoringPhase.finished;
                        });
                        // Optional: Pop back or show confirmation
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Match result saved!'), backgroundColor: Colors.green),
                         );
                      },
                  ),
                  
                  // --- ADD THIS BUTTON ---
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: _isDownloadingPdf
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: const Text('Download Scorecard (PDF)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blueGrey, // A different color
                    ),
                    onPressed: _isDownloadingPdf ? null : _downloadPdf,
                  ),
                  // --- END ADDED BUTTON ---

                ],
            ),
        ),
    );
  }
 // --- END FIX ---
} // End of _AdminUpdateScoreScreenState class

