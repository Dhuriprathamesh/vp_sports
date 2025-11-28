import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../../core/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LiveFootballScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveFootballScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveFootballScoreScreen> createState() => _LiveFootballScoreScreenState();
}

class _LiveFootballScoreScreenState extends State<LiveFootballScoreScreen> {
  int _teamAGoals = 0;
  int _teamBGoals = 0;
  
  // New Stats
  int _teamAFouls = 0;
  int _teamBFouls = 0;
  int _teamAFreeKicks = 0;
  int _teamBFreeKicks = 0;
  int _teamAPenalties = 0;
  int _teamBPenalties = 0;

  // Player Lists
  List<String> _teamAPlayers = [];
  List<String> _teamBPlayers = [];

  // Goal Details: [{ 'player': 'Name', 'time': '12:30' }]
  List<Map<String, dynamic>> _teamAGoalDetails = [];
  List<Map<String, dynamic>> _teamBGoalDetails = [];

  String _matchTime = "00:00";
  String _currentHalf = "1st Half";
  bool _isMatchFinished = false;
  Timer? _pollingTimer;
  Timer? _gameTimer;
  bool _isUpdating = false;
  bool _showAdminControls = false;
  int _totalSeconds = 0;
  int _matchDuration = 90;
  
  // Pause State
  bool _isGamePaused = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    if (!widget.isAdmin) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchLiveScore());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _parseTimeAndStartTimer() {
    if (_gameTimer != null && _gameTimer!.isActive) return;
    
    try {
      final parts = _matchTime.split(':');
      if (parts.length == 2) {
        _totalSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (e) {
      _totalSeconds = 0;
    }

    _startLocalTimer();
  }

  void _startLocalTimer() {
    if (_isGamePaused) return;

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_totalSeconds >= _matchDuration * 60) {
        timer.cancel();
        _updateScore(manualSync: true);
        return;
      }

      setState(() {
        _totalSeconds++;
        _matchTime = _formatTime(_totalSeconds);
      });

      int halfDuration = (_matchDuration * 60) ~/ 2;
      if (_currentHalf == '1st Half' && _totalSeconds >= halfDuration) {
        _gameTimer?.cancel();
        _updateScore(manualSync: true);
      }

      if (_totalSeconds % 30 == 0) {
        _updateScore(manualSync: false);
      }
    });
  }

  void _togglePauseMatch() {
    setState(() {
      _isGamePaused = !_isGamePaused;
    });

    if (_isGamePaused) {
      _gameTimer?.cancel();
    } else {
      _startLocalTimer();
    }
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _fetchLiveScore() async {
    if (_isUpdating) return;
    const String host = kIsWeb ? 'localhost' : '172.16.253.246';
    try {
      final response = await http.get(Uri.parse('http://$host:5000/api/get_football_live_score/${widget.matchId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
             _teamAGoals = data['team_a_goals'];
             _teamBGoals = data['team_b_goals'];
             _teamAFouls = data['team_a_fouls'] ?? 0;
             _teamBFouls = data['team_b_fouls'] ?? 0;
             _teamAFreeKicks = data['team_a_freekicks'] ?? 0;
             _teamBFreeKicks = data['team_b_freekicks'] ?? 0;
             _teamAPenalties = data['team_a_penalties'] ?? 0;
             _teamBPenalties = data['team_b_penalties'] ?? 0;

             // Fetch Players
             _teamAPlayers = List<String>.from(data['team_a_players'] ?? []);
             _teamBPlayers = List<String>.from(data['team_b_players'] ?? []);

             // Fetch Goal Details
             _teamAGoalDetails = List<Map<String, dynamic>>.from(data['team_a_goal_details'] ?? []);
             _teamBGoalDetails = List<Map<String, dynamic>>.from(data['team_b_goal_details'] ?? []);

             if (!widget.isAdmin || _gameTimer == null) {
                 _matchTime = data['match_time'];
                 if (!widget.isAdmin) {
                    final parts = _matchTime.split(':');
                    if (parts.length == 2) {
                      _totalSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                    }
                 }
             }
             _currentHalf = data['current_half'];
             _isMatchFinished = data['match_status'] == 'finished';
             if (data['match_duration'] != null) {
               _matchDuration = data['match_duration'];
             }
          });
        }
      }
    } catch (e) {
      print("Error fetching football score: $e");
    }
  }

  Future<void> _updateScore({bool finishMatch = false, bool manualSync = true}) async {
    if (!widget.isAdmin) return;
    if (_isGamePaused && !finishMatch) return; 

    if (manualSync) setState(() => _isUpdating = true);
    
    const String host = kIsWeb ? 'localhost' : '172.16.253.246';
    try {
      await http.post(
        Uri.parse('http://$host:5000/api/update_football_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'team_a_goals': _teamAGoals,
          'team_b_goals': _teamBGoals,
          'team_a_fouls': _teamAFouls,
          'team_b_fouls': _teamBFouls,
          'team_a_freekicks': _teamAFreeKicks,
          'team_b_freekicks': _teamBFreeKicks,
          'team_a_penalties': _teamAPenalties,
          'team_b_penalties': _teamBPenalties,
          'team_a_goal_details': _teamAGoalDetails,
          'team_b_goal_details': _teamBGoalDetails,
          'match_time': _matchTime,
          'current_half': _currentHalf,
          'status': finishMatch ? 'finished' : 'live'
        }),
      );
      if (finishMatch && mounted) {
        _gameTimer?.cancel();
        setState(() => _isMatchFinished = true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if(manualSync && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating score: $e")));
    } finally {
      if (manualSync && mounted) setState(() => _isUpdating = false);
    }
  }

  // --- Player Selection Dialog ---
  Future<void> _showGoalScorerDialog(String teamName, bool isTeamA) async {
    List<String> players = isTeamA ? _teamAPlayers : _teamBPlayers;
    
    if (players.isEmpty) {
      // If no players are available, just update score without name
      setState(() {
        if (isTeamA) {
           _teamAGoals++;
           _teamAGoalDetails.add({'player': 'Unknown', 'time': _matchTime});
        } else {
           _teamBGoals++;
           _teamBGoalDetails.add({'player': 'Unknown', 'time': _matchTime});
        }
        _updateScore();
      });
      return;
    }

    String? selectedPlayer;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Goal Scorer ($teamName)"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: players.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(players[index]),
                  onTap: () {
                    selectedPlayer = players[index];
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel")
            )
          ],
        );
      }
    );

    if (selectedPlayer != null) {
      setState(() {
        if (isTeamA) {
           _teamAGoals++;
           _teamAGoalDetails.add({'player': selectedPlayer, 'time': _matchTime});
        } else {
           _teamBGoals++;
           _teamBGoalDetails.add({'player': selectedPlayer, 'time': _matchTime});
        }
        _updateScore();
      });
    }
  }

  void _startSecondHalf() {
    if (_isGamePaused) return;
    setState(() {
      _currentHalf = "2nd Half";
      int halfDuration = (_matchDuration * 60) ~/ 2;
      if (_totalSeconds < halfDuration) _totalSeconds = halfDuration; 
      _matchTime = _formatTime(_totalSeconds);
    });
    _startLocalTimer();
    _updateScore();
  }

  // --- NEW FUNCTION: _addExtraTime ---
  Future<void> _addExtraTime() async {
    int? extraMins = await showDialog<int>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text("Add Extra Time (mins)"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "e.g. 5"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                int? val = int.tryParse(controller.text);
                Navigator.pop(context, val);
              },
              child: const Text("Add"),
            ),
          ],
        );
      }
    );

    if (extraMins != null && extraMins > 0) {
      setState(() {
        _matchDuration += extraMins; // Extend total duration
        _currentHalf = "Extra Time"; // Optional: Change half label
        // No need to change _totalSeconds as it continues from where it stopped
      });
      _startLocalTimer(); // Resume/Start timer with new limit
      _updateScore(); // Sync new state
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    // UPDATED: Dynamic Heading Logic
    String titleText = "Football - Live Score";
    if (_isMatchFinished) {
      titleText = "Football - Recent";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20), 
              _buildScoreBoard(),

              const SizedBox(height: 30),
              
              // Show Half-Time Message
              if (widget.isAdmin && !_isMatchFinished && _currentHalf == '1st Half' && _totalSeconds >= ((_matchDuration * 60) ~/ 2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    children: [
                      const Text("Half Time Reached", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _startSecondHalf,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        child: const Text("Start 2nd Half"),
                      ),
                    ],
                  ),
                ),

              // Admin Controls Section
              if (widget.isAdmin && !_isMatchFinished)
                if (!_showAdminControls)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _showAdminControls = true);
                        if (_gameTimer == null || !_gameTimer!.isActive) {
                           _parseTimeAndStartTimer();
                        }
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text(
                        "Update Score", 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: const Color(0xFF0A4F43), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                    ),
                  )
                else
                  _buildAdminControls(),

              // REMOVED: "MATCH FINISHED" text from here, as it is now inside the card
            ],
          ),
        ),
      ),
    );
  }

  String _getWinnerResultText() {
    if (_teamAGoals > _teamBGoals) {
      return "${widget.teamAName} Won the match";
    } else if (_teamBGoals > _teamAGoals) {
      return "${widget.teamBName} Won the match";
    } else {
      return "Match Drawn";
    }
  }

  Widget _buildTimeBar() {
    // UPDATED: Hide time bar if match is finished
    if (_isMatchFinished) return const SizedBox.shrink();

    int totalMatchSeconds = _matchDuration * 60;
    if (totalMatchSeconds == 0) totalMatchSeconds = 1; 
    double progress = (_totalSeconds / totalMatchSeconds).clamp(0.0, 1.0);

    return Container(
      height: 16, 
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double barWidth = constraints.maxWidth;
          final double progressWidth = barWidth * progress;

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none, 
            children: [
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF00838F), 
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: progressWidth,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: (progressWidth - 8).clamp(0.0, barWidth - 16), 
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF8E1), 
                    border: Border.all(color: const Color(0xFF001026), width: 3),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
        child: Column(
          children: [
            // UPDATED: Logic to hide Live elements and show Result Text
            if (_isMatchFinished) ...[
               // 1. Result Text at Top
               Text(
                 _getWinnerResultText(),
                 textAlign: TextAlign.center,
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
               ),
               const SizedBox(height: 20),
            ] else ...[
               // 1. Live Elements
               _buildTimeBar(),
               const SizedBox(height: 10),
               Text(_currentHalf.toUpperCase(), style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               const SizedBox(height: 10),
               Text(
                 _matchTime, 
                 style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, fontFamily: 'monospace')
               ),
               const SizedBox(height: 20),
            ],

            // 2. Scores (Common)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Expanded(child: _buildTeamColumn(widget.teamAName, _teamAGoals, _teamAGoalDetails)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  child: Text("-", style: TextStyle(fontSize: 40, color: Colors.grey)),
                ),
                Expanded(child: _buildTeamColumn(widget.teamBName, _teamBGoals, _teamBGoalDetails)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String name, int goals, List<Map<String, dynamic>> scorers) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
        const SizedBox(height: 10),
        Text(goals.toString(), style: TextStyle(fontSize: 48, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Display Goal Scorers
        if (scorers.isNotEmpty)
          ...scorers.map((goal) => Text(
            "${goal['player']} ${goal['time']}'",
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          ))
        else
          const SizedBox(height: 10), // Spacer to keep alignment
      ],
    );
  }

  Widget _buildAdminControls() {
    // Determine if scoring buttons should be hidden
    bool isHalfTime = _currentHalf == '1st Half' && _totalSeconds >= ((_matchDuration * 60) ~/ 2);
    // Check if full time reached (but allow if paused so we can resume/add extra time)
    bool isFullTime = _totalSeconds >= (_matchDuration * 60);
    // Check if Extra Time has finished (Full time reached AND we are in Extra Time phase)
    bool isExtraTimeFinished = isFullTime && _currentHalf == "Extra Time";

    bool hideScoringButtons = _isGamePaused || isHalfTime || _isMatchFinished || isFullTime;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Admin Controls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(onPressed: () => setState(() => _showAdminControls = false), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          
          // Conditionally show scoring buttons
          if (!hideScoringButtons) ...[
            // Goal Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGoalButton("+1 Goal ${widget.teamAName}", () { 
                  if(!_isGamePaused) _showGoalScorerDialog(widget.teamAName, true);
                }),
                _buildGoalButton("+1 Goal ${widget.teamBName}", () { 
                  if(!_isGamePaused) _showGoalScorerDialog(widget.teamBName, false);
                }),
              ],
            ),
            const SizedBox(height: 10),

            // Foul Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGoalButton("+1 Foul ${widget.teamAName}", () { 
                  if(!_isGamePaused) { setState(() => _teamAFouls++); _updateScore(); } 
                }),
                _buildGoalButton("+1 Foul ${widget.teamBName}", () { 
                  if(!_isGamePaused) { setState(() => _teamBFouls++); _updateScore(); }
                }),
              ],
            ),
            const SizedBox(height: 10),

            // Free Kick Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGoalButton("+1 FK ${widget.teamAName}", () { 
                  if(!_isGamePaused) { setState(() => _teamAFreeKicks++); _updateScore(); } 
                }),
                _buildGoalButton("+1 FK ${widget.teamBName}", () { 
                  if(!_isGamePaused) { setState(() => _teamBFreeKicks++); _updateScore(); }
                }),
              ],
            ),
            const SizedBox(height: 10),

            // Penalty Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGoalButton("+1 Pen ${widget.teamAName}", () { 
                  if(!_isGamePaused) { setState(() => _teamAPenalties++); _updateScore(); } 
                }),
                _buildGoalButton("+1 Pen ${widget.teamBName}", () { 
                  if(!_isGamePaused) { setState(() => _teamBPenalties++); _updateScore(); }
                }),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
             // Optional placeholder when buttons are hidden
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 20.0),
               child: Text(
                 _isGamePaused ? "Match Paused" : (isHalfTime ? "Half Time - Controls Locked" : (isFullTime ? "Full Time Reached" : "Match Finished")),
                 style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
             ),
          ],
          
          // --- NEW BUTTON: Extra Time (Shown only when full time reached and extra time not finished) ---
          if (isFullTime && _currentHalf != "Extra Time") ...[
             SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addExtraTime,
                icon: const Icon(Icons.add_alarm, color: Colors.white),
                label: const Text("Extra Time"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Pause/Resume Button
          // Hide if Extra Time is finished (or Match is finished)
          if (!isExtraTimeFinished && !_isMatchFinished) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _togglePauseMatch,
                  icon: Icon(_isGamePaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                  label: Text(_isGamePaused ? "Resume Match" : "Pause Match"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isGamePaused ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                ),
              ),
              const SizedBox(height: 10),
          ],
          
          // End Match Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateScore(finishMatch: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100, 
                foregroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("End Match", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}