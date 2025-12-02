import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart';

class LiveVolleyballScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;
  final String matchFormat; // "Best of 3 Sets" or "Best of 5 Sets"

  const LiveVolleyballScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
    required this.matchFormat,
  });

  @override
  State<LiveVolleyballScoreScreen> createState() => _LiveVolleyballScoreScreenState();
}

class _LiveVolleyballScoreScreenState extends State<LiveVolleyballScoreScreen> {
  // State
  int _currentSet = 1;
  int _teamASetsWon = 0;
  int _teamBSetsWon = 0;
  int _teamACurrentPoints = 0;
  int _teamBCurrentPoints = 0;
  Map<String, String> _setScores = {}; 
  String _matchStatus = "live";
  bool _isLoading = true;
  // This flag ensures the "End Match" button only appears if the user just finished the match.
  // It stays false if opening an already finished match from Recent.
  bool _showEndMatchButton = false; 
  Timer? _pollingTimer;

  // Constants determined by matchFormat
  late int _setsToWin; 
  late int _totalSetsPossible; 

  @override
  void initState() {
    super.initState();
    // Logic: Best of 5 => 3 sets to win, 5 total. Best of 3 => 2 sets to win, 3 total.
    _setsToWin = widget.matchFormat.contains("5") ? 3 : 2;
    _totalSetsPossible = widget.matchFormat.contains("5") ? 5 : 3;
    
    _fetchLiveScore();
    if (!widget.isAdmin) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchLiveScore());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveScore() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/get_volleyball_live_score/${widget.matchId}'));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        
        // Only update from server if we are NOT currently in the middle of a local optimistic update
        // or simply always update to stay in sync. 
        // For admin, we prioritize local state to avoid jumpiness, but here we sync.
        setState(() {
          _currentSet = data['current_set'];
          _teamASetsWon = data['team_a_sets_won'];
          _teamBSetsWon = data['team_b_sets_won'];
          _teamACurrentPoints = data['team_a_current_points'];
          _teamBCurrentPoints = data['team_b_current_points'];
          _setScores = Map<String, String>.from(data['set_scores'] ?? {});
          _matchStatus = data['match_status'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching volleyball score: $e");
    }
  }

  Future<void> _updateScore({bool finishSet = false, bool finishMatch = false}) async {
    
    // --- UPDATED LOGIC: Wrap in setState to update UI instantly ---
    setState(() {
      if (finishSet) {
        // Record set score history
        _setScores[_currentSet.toString()] = "$_teamACurrentPoints-$_teamBCurrentPoints";
        
        // Update sets won
        if (_teamACurrentPoints > _teamBCurrentPoints) {
          _teamASetsWon++;
        } else {
          _teamBSetsWon++;
        }
        
        // Check if Match is Won
        if (_teamASetsWon >= _setsToWin || _teamBSetsWon >= _setsToWin) {
          finishMatch = true;
        } else {
          // Move to next set AND RESET POINTS
          _currentSet++;
          _teamACurrentPoints = 0; // Reset to 0
          _teamBCurrentPoints = 0; // Reset to 0
        }
      }

      if (finishMatch) {
        _matchStatus = "finished";
        _showEndMatchButton = true; // Only show button if we just transitioned to finished
      }
    });

    final payload = {
      "current_set": _currentSet,
      "team_a_sets_won": _teamASetsWon,
      "team_b_sets_won": _teamBSetsWon,
      "team_a_current_points": _teamACurrentPoints,
      "team_b_current_points": _teamBCurrentPoints,
      "set_scores": _setScores,
      "match_status": _matchStatus
    };

    try {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_volleyball_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (finishMatch && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Match Finished!")));
      }
    } catch (e) {
      print("Error updating score: $e");
    }
  }

  void _addPoint(bool isTeamA) {
    if (_matchStatus == 'finished') return;

    setState(() {
      if (isTeamA) {
        _teamACurrentPoints++;
      } else {
        _teamBCurrentPoints++;
      }
    });
    
    // --- SCORING RULES LOGIC ---
    // Standard Sets (1-4 in Bo5, 1-2 in Bo3): First to 25, win by 2
    // Deciding Set (5th in Bo5, 3rd in Bo3): First to 15, win by 2
    
    bool isDecider = (_currentSet == _totalSetsPossible);
    int pointsToWin = isDecider ? 15 : 25;
    
    int scoreA = _teamACurrentPoints;
    int scoreB = _teamBCurrentPoints;

    // Check if someone reached target AND has a lead of >= 2
    if ((scoreA >= pointsToWin || scoreB >= pointsToWin) && (scoreA - scoreB).abs() >= 2) {
       // Auto-trigger confirmation dialog for better UX
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (_) => AlertDialog(
           title: Text("Set $_currentSet Finished?"),
           content: Text("Score: $scoreA - $scoreB.\n${scoreA > scoreB ? widget.teamAName : widget.teamBName} wins this set."),
           actions: [
             TextButton(
               onPressed: () {
                 // Option to cancel. Note: Point was already added locally.
                 // Ideally, we might want to revert the point if they cancel, but usually, they confirm.
                 Navigator.pop(context);
               }, 
               child: const Text("Cancel")
             ),
             ElevatedButton(
               onPressed: () {
                 Navigator.pop(context);
                 _updateScore(finishSet: true);
               }, 
               child: const Text("Confirm & Next Set")
             )
           ],
         )
       );
    } else {
      // Just update the points on server
      _updateScore(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;
    
    // --- UPDATED TITLE LOGIC ---
    String titleText = "Volleyball Live";
    if (_matchStatus == 'finished') {
       titleText = "Volleyball Recent";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
          children: [
             // --- Scoreboard Card ---
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Card(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 elevation: 4,
                 child: Padding(
                   padding: const EdgeInsets.all(20.0),
                   child: Column(
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                            _buildTeamColumn(widget.teamAName, _teamASetsWon, _teamACurrentPoints, true),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("VS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            _buildTeamColumn(widget.teamBName, _teamBSetsWon, _teamBCurrentPoints, false),
                         ],
                       ),
                       const Divider(height: 30),
                       Text(
                         _matchStatus == 'finished' ? "Match Finished" : "Match Format: ${widget.matchFormat}", 
                         style: const TextStyle(color: Colors.grey)
                       ),
                     ],
                   ),
                 ),
               ),
             ),

             // --- Set History List ---
             Expanded(
               child: ListView(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 children: [
                    const Text("Set Scores", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (_setScores.isEmpty) 
                      const Text("No sets completed yet.", style: TextStyle(color: Colors.white70)),
                    ..._setScores.entries.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Text(e.key, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text("Set ${e.key}"),
                        trailing: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    )),
                 ],
               ),
             ),
             
             // --- Admin Scoring Controls ---
             if (widget.isAdmin)
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: _matchStatus == 'live' 
                   ? Row(
                       children: [
                         Expanded(child: SizedBox(
                           height: 60,
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green.shade600, 
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                             ),
                             onPressed: () => _addPoint(true), 
                             child: Text("+1 ${widget.teamAName}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                           ),
                         )),
                         const SizedBox(width: 16),
                         Expanded(child: SizedBox(
                           height: 60,
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.blue.shade600,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                             ),
                             onPressed: () => _addPoint(false), 
                             child: Text("+1 ${widget.teamBName}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                           ),
                         )),
                       ],
                     )
                   : _showEndMatchButton // Check flag instead of just matchStatus
                       ? SizedBox(
                           width: double.infinity,
                           height: 60,
                           child: ElevatedButton.icon(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.red.shade700,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                             ),
                             onPressed: () => Navigator.of(context).pop(), // Return to list (Recent)
                             icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                             label: const Text("End Match", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                           ),
                         )
                       : const SizedBox.shrink(), // Hide button if already finished
               )
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String name, int sets, int points, bool isLeft) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text("Sets Won: $sets", style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Text(points.toString(), style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        ],
      ),
    );
  }
}