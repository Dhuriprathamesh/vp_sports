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
  String _matchTime = "00:00";
  String _currentHalf = "1st Half"; // "1st Half" or "2nd Half"
  bool _isMatchFinished = false;
  Timer? _pollingTimer;
  Timer? _gameTimer; // Local timer for continuous running
  bool _isUpdating = false;
  bool _showAdminControls = false; // Toggle to show/hide update buttons
  int _totalSeconds = 0; // Track time in seconds for easier calculation

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    if (widget.isAdmin) {
      // If admin, start the local game timer logic after initial fetch
    } else {
      // If viewer, poll server
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
    
    // Parse the current _matchTime string (MM:SS) to seconds
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
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _totalSeconds++;
        _matchTime = _formatTime(_totalSeconds);
      });

      // Logic for Halves
      // Stop at 45:00 (2700 seconds) if it is 1st Half
      if (_currentHalf == '1st Half' && _totalSeconds >= 2700) {
        _gameTimer?.cancel();
        _updateScore(manualSync: true); // Sync the stop state
      }

      // Sync with server every 30 seconds automatically to keep viewers updated
      if (_totalSeconds % 30 == 0) {
        _updateScore(manualSync: false);
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _fetchLiveScore() async {
    if (_isUpdating) return;
    const String host = kIsWeb ? 'localhost' : '10.0.2.2';
    try {
      final response = await http.get(Uri.parse('http://$host:5000/api/get_football_live_score/${widget.matchId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            // Only update these if we aren't the admin currently running the timer
            // Or if it's the initial load
            if (!widget.isAdmin || _gameTimer == null) {
               _teamAGoals = data['team_a_goals'];
               _teamBGoals = data['team_b_goals'];
               _matchTime = data['match_time'];
               _currentHalf = data['current_half'];
               _isMatchFinished = data['match_status'] == 'finished';
               
               if (widget.isAdmin && !_isMatchFinished && _gameTimer == null) {
                 _parseTimeAndStartTimer();
               }
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
    if (manualSync) setState(() => _isUpdating = true);
    
    const String host = kIsWeb ? 'localhost' : '10.0.2.2';
    try {
      await http.post(
        Uri.parse('http://$host:5000/api/update_football_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'team_a_goals': _teamAGoals,
          'team_b_goals': _teamBGoals,
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

  void _startSecondHalf() {
    setState(() {
      _currentHalf = "2nd Half";
      // Ensure we start from 45:00 if somehow below
      if (_totalSeconds < 2700) _totalSeconds = 2700; 
      _matchTime = _formatTime(_totalSeconds);
    });
    _startLocalTimer();
    _updateScore();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Football - Live Score"),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SingleChildScrollView( // WRAPPED IN SCROLLVIEW TO FIX OVERFLOW
          child: Column(
            // Align content to top (start) instead of center
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20), // Top padding
              _buildScoreBoard(),
              const SizedBox(height: 30),
              
              // Show Half-Time Message if needed
              if (widget.isAdmin && _currentHalf == '1st Half' && _totalSeconds >= 2700)
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

              if (widget.isAdmin && !_isMatchFinished) ...[
                 const SizedBox(height: 20),
                 if (!_showAdminControls)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20.0),
                     child: ElevatedButton.icon(
                       onPressed: () => setState(() => _showAdminControls = true),
                       icon: const Icon(Icons.edit),
                       label: const Text("Update Score / Manage"),
                       style: ElevatedButton.styleFrom(
                         minimumSize: const Size(double.infinity, 50),
                         backgroundColor: Colors.white,
                         foregroundColor: Theme.of(context).primaryColor
                       ),
                     ),
                   ),
                 if (_showAdminControls) _buildAdminControls(),
                 const SizedBox(height: 20),
              ],

              if (_isMatchFinished) 
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("MATCH FINISHED", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          children: [
            Text(_currentHalf.toUpperCase(), style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Text(
              _matchTime, 
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, fontFamily: 'monospace')
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildTeamColumn(widget.teamAName, _teamAGoals)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("-", style: TextStyle(fontSize: 40, color: Colors.grey)),
                ),
                Expanded(child: _buildTeamColumn(widget.teamBName, _teamBGoals)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String name, int goals) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
        const SizedBox(height: 10),
        Text(goals.toString(), style: TextStyle(fontSize: 48, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAdminControls() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))]
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGoalButton("+1 Goal ${widget.teamAName}", () { setState(() => _teamAGoals++); _updateScore(); }),
              _buildGoalButton("+1 Goal ${widget.teamBName}", () { setState(() => _teamBGoals++); _updateScore(); }),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              labelText: "Correct Time (e.g. 23:45)", 
              filled: true, 
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.timer)
            ),
            onSubmitted: (val) { 
              setState(() {
                 _matchTime = val; 
                 // Recalculate seconds for timer
                 final parts = val.split(':');
                 if (parts.length == 2) {
                    _totalSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                 }
              }); 
              _updateScore(); 
            },
          ),
          const SizedBox(height: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
      ),
      child: Text(label),
    );
  }
}