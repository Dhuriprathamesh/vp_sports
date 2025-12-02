import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/api_constants.dart'; // Import ApiConstants

class LiveBadmintonScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveBadmintonScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveBadmintonScoreScreen> createState() => _LiveBadmintonScoreScreenState();
}

class _LiveBadmintonScoreScreenState extends State<LiveBadmintonScoreScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _pollingTimer;

  // Static Data
  int _totalSets = 3; 
  String _category = 'singles';
  
  // Dynamic Live Score Data
  int _currentSet = 1;
  String _gameStatusText = 'Match starting soon...';
  String? _winner;
  bool _isMatchFinished = false;

  // Current set points display
  int _team1CurrentSetPoints = 0;
  int _team2CurrentSetPoints = 0;
  
  // Stored set points history
  List<Map<String, int>> _setScores = [
    {'team1': 0, 'team2': 0},
    {'team1': 0, 'team2': 0},
    {'team1': 0, 'team2': 0},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    // Poll every 10 seconds if not admin or if match is live to keep data fresh
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isMatchFinished) {
        _fetchLiveScore(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
  
  int get _currentSetIndex => _currentSet - 1;

  Future<void> _fetchLiveScore({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    
    if (!mounted) return;
    
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/get_badminton_live_score/${widget.matchId}'));
      
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final List<Map<String, int>> fetchedSets = [];
        // Extract points for Set 1, 2, and 3
        for (int i = 1; i <= 3; i++) { 
            if (data.containsKey('team1_set${i}_points')) {
              fetchedSets.add({
                'team1': data['team1_set${i}_points'] ?? 0,
                'team2': data['team2_set${i}_points'] ?? 0,
              });
            }
        }
        
        setState(() {
          _totalSets = (data['total_sets'] != null && data['total_sets'] > 0) ? data['total_sets'] : 3;
          _category = data['category'] ?? 'singles';
          _currentSet = data['current_set'] ?? 1;
          _gameStatusText = data['game_status_text'] ?? '';
          _isMatchFinished = data['match_status'] == 'finished';
          _winner = _isMatchFinished ? _determineWinnerFromScores(fetchedSets) : null;
          _setScores = fetchedSets;

          // Update the big number display based on the current set
          if (_currentSetIndex >= 0 && _currentSetIndex < _setScores.length) {
            _team1CurrentSetPoints = _setScores[_currentSetIndex]['team1']!;
            _team2CurrentSetPoints = _setScores[_currentSetIndex]['team2']!;
          } else {
            _team1CurrentSetPoints = 0;
            _team2CurrentSetPoints = 0;
          }
          
          _isLoading = false;
        });
        if (_isMatchFinished) _pollingTimer?.cancel();
      } else if (mounted) {
         setState(() { 
           _isLoading = false; 
           if (!isRefresh || _setScores.isEmpty) {
              _errorMessage = 'Failed to fetch live score.';
           }
         });
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
         _isLoading = false; 
         if (!isRefresh || _setScores.isEmpty) {
           _errorMessage = 'Connection error.';
         }
      });
      }
    }
  }

  String? _determineWinnerFromScores(List<Map<String, int>> scores) {
    int t1Wins = _calculateSetsWon(1, scores);
    int t2Wins = _calculateSetsWon(2, scores);
    if (t1Wins > t2Wins) return widget.teamAName;
    if (t2Wins > t1Wins) return widget.teamBName;
    return null;
  }

  Future<void> _updateScore({
    required int team1Set1, required int team2Set1,
    required int team1Set2, required int team2Set2,
    required int team1Set3, required int team2Set3,
    required int newCurrentSet,
    required String statusText,
    String? winner,
    required bool finishMatch,
  }) async {
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_badminton_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'team1_set1_points': team1Set1, 'team2_set1_points': team2Set1,
          'team1_set2_points': team1Set2, 'team2_set2_points': team2Set2,
          'team1_set3_points': team1Set3, 'team2_set3_points': team2Set3,
          'new_current_set': newCurrentSet,
          'status_text': statusText, 
          'winner': winner,
          'status': finishMatch ? 'finished' : 'live',
        }),
      );
      if (mounted && response.statusCode == 200) {
        _fetchLiveScore(isRefresh: true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to connect: $e"), backgroundColor: Colors.red));
    }
  }

  // --- BADMINTON SPECIFIC RULES ---
  bool _isSetWon(int s1, int s2) {
    // Hard cap at 30 (Golden point rule)
    if (s1 >= 30 || s2 >= 30) return true;
    
    // Standard win: 21 points with 2 point lead
    return (s1 >= 21 || s2 >= 21) && (s1 - s2).abs() >= 2;
  }

  int _calculateSetsWon(int teamIndex, List<Map<String, int>> scores) {
    int wins = 0;
    for (var setScore in scores) {
      int s1 = setScore['team1']!;
      int s2 = setScore['team2']!;
      if (_isSetWon(s1, s2)) {
        if (teamIndex == 1 && s1 > s2) wins++;
        if (teamIndex == 2 && s2 > s1) wins++;
      }
    }
    return wins;
  }

  void _incrementCurrentSetPoint(int team) {
    if (_isMatchFinished) return;
    
    List<Map<String, int>> updatedSetScores = List.from(_setScores);
    while (_currentSetIndex >= updatedSetScores.length) {
       updatedSetScores.add({'team1': 0, 'team2': 0});
    }

    if (_currentSetIndex >= 0) {
      int p1 = updatedSetScores[_currentSetIndex]['team1']!;
      int p2 = updatedSetScores[_currentSetIndex]['team2']!;
      
      if (team == 1) {
        p1++;
      } else {
        p2++;
      }
      updatedSetScores[_currentSetIndex] = {'team1': p1, 'team2': p2};

      int nextCurrentSet = _currentSet;
      bool matchFinished = false;
      String? matchWinner;
      String statusText = "Set $_currentSet: $p1 - $p2";

      if (_isSetWon(p1, p2)) {
        int setsToWin = (_totalSets / 2).ceil(); // Usually 2 out of 3
        
        // Check total wins including this new set
        int t1Wins = 0;
        int t2Wins = 0;
        for(var score in updatedSetScores) {
            if (_isSetWon(score['team1']!, score['team2']!)) {
                if(score['team1']! > score['team2']!) {
                  t1Wins++;
                } else {
                  t2Wins++;
                }
            }
        }

        if (t1Wins >= setsToWin) {
          matchWinner = widget.teamAName;
          matchFinished = true;
          statusText = "Winner: ${widget.teamAName}";
        } else if (t2Wins >= setsToWin) {
          matchWinner = widget.teamBName;
          matchFinished = true;
          statusText = "Winner: ${widget.teamBName}";
        } else if (_currentSet < _totalSets) {
          nextCurrentSet = _currentSet + 1;
          statusText = "Starting Set $nextCurrentSet";
        } else {
          // Max sets played
          matchFinished = true;
          matchWinner = t1Wins > t2Wins ? widget.teamAName : widget.teamBName;
          statusText = "Winner: $matchWinner";
        }
      }
      
      _updateScore(
        team1Set1: updatedSetScores.isNotEmpty ? updatedSetScores[0]['team1']! : 0,
        team2Set1: updatedSetScores.isNotEmpty ? updatedSetScores[0]['team2']! : 0,
        team1Set2: updatedSetScores.length > 1 ? updatedSetScores[1]['team1']! : 0,
        team2Set2: updatedSetScores.length > 1 ? updatedSetScores[1]['team2']! : 0,
        team1Set3: updatedSetScores.length > 2 ? updatedSetScores[2]['team1']! : 0,
        team2Set3: updatedSetScores.length > 2 ? updatedSetScores[2]['team2']! : 0,
        newCurrentSet: nextCurrentSet, 
        statusText: statusText,
        winner: matchWinner, 
        finishMatch: matchFinished,
      );
    }
  }

  void _decrementCurrentSetPoint(int team) {
    if (_isMatchFinished) return;
    
    List<Map<String, int>> updatedSetScores = List.from(_setScores);
    if (_currentSetIndex >= updatedSetScores.length) return;

    int p1 = updatedSetScores[_currentSetIndex]['team1']!;
    int p2 = updatedSetScores[_currentSetIndex]['team2']!;

    if (team == 1 && p1 > 0) p1--;
    if (team == 2 && p2 > 0) p2--;

    updatedSetScores[_currentSetIndex] = {'team1': p1, 'team2': p2};
    final String statusText = "Set $_currentSet: $p1 - $p2";

    _updateScore(
      team1Set1: updatedSetScores.isNotEmpty ? updatedSetScores[0]['team1']! : 0,
      team2Set1: updatedSetScores.isNotEmpty ? updatedSetScores[0]['team2']! : 0,
      team1Set2: updatedSetScores.length > 1 ? updatedSetScores[1]['team1']! : 0,
      team2Set2: updatedSetScores.length > 1 ? updatedSetScores[1]['team2']! : 0,
      team1Set3: updatedSetScores.length > 2 ? updatedSetScores[2]['team1']! : 0,
      team2Set3: updatedSetScores.length > 2 ? updatedSetScores[2]['team2']! : 0,
      newCurrentSet: _currentSet, 
      statusText: statusText,
      winner: null, 
      finishMatch: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = widget.isForBoys 
        ? [Colors.orange.shade50, Colors.orange.shade100] 
        : [Colors.pink.shade50, Colors.pink.shade100]; 
        
    // Dark Green to match Badminton styling
    const Color primaryColor = Color(0xFF1B5E20); 

    // --- UPDATED TITLE LOGIC ---
    String title = "Badminton Live";
    if (_isMatchFinished) title = "Badminton Recent";

    return Scaffold(
      appBar: AppBar(
        title: Text(title), 
        elevation: 0, 
        backgroundColor: primaryColor
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors, 
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter
          )
        ),
        child: _buildBody(primaryColor), 
      ),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoading && _setScores.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.black54));
    }
    
    if (_errorMessage.isNotEmpty && _setScores.isEmpty) {
       return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.black54)));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
             onRefresh: () => _fetchLiveScore(isRefresh: true),
             child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildMainScoreCard(primaryColor),
                  const SizedBox(height: 16),
                  _buildStatusCard(primaryColor),
                  const SizedBox(height: 24),
                  _buildSetHistory(primaryColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainScoreCard(Color primaryColor) {
    int t1Wins = _calculateSetsWon(1, _setScores);
    int t2Wins = _calculateSetsWon(2, _setScores);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildTeamScoreSection(widget.teamAName, t1Wins, _team1CurrentSetPoints, isTeam1: true, primaryColor: primaryColor)),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  Icon(Icons.sports_tennis, color: Colors.grey[400], size: 30), 
                  const SizedBox(height: 8),
                  if (!_isMatchFinished)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text("Set $_currentSet", style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            Expanded(child: _buildTeamScoreSection(widget.teamBName, t2Wins, _team2CurrentSetPoints, isTeam1: false, primaryColor: primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreSection(String name, int setsWon, int points, {required bool isTeam1, required Color primaryColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name, 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$setsWon Sets", 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ),
        const SizedBox(height: 16),

        Text(
           "$points", 
           style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const Text("Points", style: TextStyle(fontSize: 12, color: Colors.grey)),
        
        const SizedBox(height: 16),

        if (widget.isAdmin && !_isMatchFinished)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               _buildCircleButton(Icons.remove, () => _decrementCurrentSetPoint(isTeam1 ? 1 : 2), isMinus: true),
               const SizedBox(width: 24),
               _buildCircleButton(Icons.add, () => _incrementCurrentSetPoint(isTeam1 ? 1 : 2)),
            ],
          ),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {bool isMinus = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMinus ? Colors.red.shade50 : Colors.green.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: isMinus ? Colors.red.shade200 : Colors.green.shade200),
        ),
        child: Icon(icon, color: isMinus ? Colors.red : Colors.green, size: 24),
      ),
    );
  }

  Widget _buildStatusCard(Color primaryColor) {
    String statusMessage = _winner != null 
      ? "Winner: $_winner" 
      : "Selected: ${widget.teamAName} vs ${widget.teamBName}";

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text("Match Status", style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: TextStyle(color: _winner != null ? primaryColor : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold), 
              textAlign: TextAlign.center
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSetHistory(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text("Set History", style: TextStyle(color: Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: List.generate(_totalSets, (index) {
                if (index >= 3) return const SizedBox.shrink(); // UI limit to 3 for now

                final score = (index < _setScores.length) ? _setScores[index] : {'team1': 0, 'team2': 0};
                
                bool isFuture = index + 1 > _currentSet && !_isMatchFinished;
                bool isCurrent = index + 1 == _currentSet && !_isMatchFinished;
                bool isCompleted = _isSetWon(score['team1']!, score['team2']!) || (index + 1 < _currentSet);

                String scoreText = isFuture ? "0 - 0" : "${score['team1']} - ${score['team2']}";
                String status = isFuture ? "Upcoming" : (isCurrent ? "Live" : "Completed");
                Color statusColor = isCurrent ? Colors.orange : (isFuture ? Colors.grey : Colors.green);
                Color bgColor = isCurrent ? Colors.orange.shade50 : (isCompleted ? Colors.green.shade50 : Colors.transparent);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    border: index < _totalSets - 1 ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null,
                    color: bgColor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Set ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      Text(scoreText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}