import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart'; // Import ApiConstants
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
  
  // Stats
  int _teamAFouls = 0;
  int _teamBFouls = 0;
  int _teamAFreeKicks = 0; 
  int _teamBFreeKicks = 0; 
  int _teamAPenalties = 0;
  int _teamBPenalties = 0;

  // Player Lists
  List<String> _teamAPlayers = [];
  List<String> _teamBPlayers = [];

  // Track Banned Players (Sent Off)
  final Set<String> _sentOffPlayers = {};

  // Details
  List<Map<String, dynamic>> _teamAGoalDetails = [];
  List<Map<String, dynamic>> _teamBGoalDetails = [];
  List<Map<String, dynamic>> _teamAFoulDetails = [];
  List<Map<String, dynamic>> _teamBFoulDetails = [];

  String _matchTime = "00:00";
  String _currentHalf = "1st Half";
  bool _isMatchFinished = false;
  Timer? _pollingTimer;
  Timer? _gameTimer;
  bool _isUpdating = false;
  bool _showAdminControls = false;
  int _totalSeconds = 0;
  int _matchDuration = 90;
  
  bool _isGamePaused = true; 
  bool _hasTimerStarted = false; 

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

  // --- Helper to Filter Active Players ---
  List<String> _getActivePlayers(List<String> allPlayers) {
    return allPlayers.where((p) => !_sentOffPlayers.contains(p)).toList();
  }
  // ---------------------------------------

  void _startLocalTimer() {
    _gameTimer?.cancel();
    if (_isGamePaused || _isMatchFinished) return;

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      int halfDurationSeconds = (_matchDuration * 60) ~/ 2;
      bool isHalfTimeLimit = _currentHalf == '1st Half' && _totalSeconds >= halfDurationSeconds;
      bool isFullTimeLimit = _totalSeconds >= (_matchDuration * 60);

      if (isHalfTimeLimit || isFullTimeLimit) {
          timer.cancel();
          setState(() {
             _isGamePaused = true;
          });
          if (widget.isAdmin) {
             _updateScore(timerAction: 'stop'); 
          }
          return;
      }

      setState(() {
        _totalSeconds++;
        _matchTime = _formatTime(_totalSeconds);
      });
    });
  }

  Future<void> _resumeMatch() async {
    setState(() {
        _isGamePaused = false;
        _hasTimerStarted = true;
    });
    await _updateScore(timerAction: 'start');
    _startLocalTimer();
  }

  Future<void> _pauseMatch() async {
    setState(() => _isGamePaused = true);
    _gameTimer?.cancel();
    await _updateScore(timerAction: 'stop');
  }

  void _togglePauseMatch() {
    if (_isGamePaused) {
      _resumeMatch();
    } else {
      _pauseMatch();
    }
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _fetchLiveScore() async {
    if (_isUpdating) return;
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/get_football_live_score/${widget.matchId}'));
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

             _teamAPlayers = List<String>.from(data['team_a_players'] ?? []);
             _teamBPlayers = List<String>.from(data['team_b_players'] ?? []);
             _teamAGoalDetails = List<Map<String, dynamic>>.from(data['team_a_goal_details'] ?? []);
             _teamBGoalDetails = List<Map<String, dynamic>>.from(data['team_b_goal_details'] ?? []);
             _teamAFoulDetails = List<Map<String, dynamic>>.from(data['team_a_foul_details'] ?? []);
             _teamBFoulDetails = List<Map<String, dynamic>>.from(data['team_b_foul_details'] ?? []);

             // --- NEW: Recalculate Sent Off Players from Server Data ---
             _sentOffPlayers.clear();
             for (var foul in _teamAFoulDetails) {
               if (foul['card'] == 'Red') _sentOffPlayers.add(foul['player']);
             }
             for (var foul in _teamBFoulDetails) {
               if (foul['card'] == 'Red') _sentOffPlayers.add(foul['player']);
             }
             // ---------------------------------------------------------

             if (data['calculated_seconds'] != null) {
                int serverSeconds = data['calculated_seconds'];
                if ((_totalSeconds - serverSeconds).abs() > 2 || _totalSeconds == 0) {
                   _totalSeconds = serverSeconds;
                   _matchTime = _formatTime(_totalSeconds);
                }
                if (serverSeconds > 0) _hasTimerStarted = true;
             }
             
             _currentHalf = data['current_half'];
             _isMatchFinished = data['match_status'] == 'finished';
             
             bool serverIsLive = data['match_status'] == 'live';
             
             if (!widget.isAdmin) {
                _isGamePaused = !serverIsLive;
             } else {
                if (serverIsLive) {
                   if (_hasTimerStarted) {
                      _isGamePaused = false;
                   } else {
                      _isGamePaused = true; 
                   }
                } else {
                   _isGamePaused = true;
                }
             }
             
             if (data['match_duration'] != null) {
               _matchDuration = data['match_duration'];
             }
             
             if (!_isGamePaused && !widget.isAdmin) {
                if (_gameTimer == null || !_gameTimer!.isActive) _startLocalTimer();
             } else if (widget.isAdmin && !_isGamePaused && _hasTimerStarted) {
                 if (_gameTimer == null || !_gameTimer!.isActive) _startLocalTimer();
             }
          });
        }
      }
    } catch (e) {
      print("Error fetching football score: $e");
    }
  }

  Future<void> _updateScore({bool finishMatch = false, bool manualSync = true, String? timerAction}) async {
    if (!widget.isAdmin) return;
    if (_isGamePaused && !finishMatch && timerAction == null) return; 

    if (manualSync) setState(() => _isUpdating = true);
    
    try {
      Map<String, dynamic> payload = {
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
          'team_a_foul_details': _teamAFoulDetails,
          'team_b_foul_details': _teamBFoulDetails,
          'match_time': _matchTime, 
          'current_half': _currentHalf,
          'status': finishMatch ? 'finished' : (_isGamePaused ? 'paused' : 'live')
      };
      
      if (timerAction != null) {
        payload['timer_action'] = timerAction;
      }

      // --- FIX: Use ApiConstants ---
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_football_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
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

  // --- Player Selection Dialog (Goals) ---
  Future<void> _showGoalScorerDialog(String teamName, bool isTeamA) async {
    // FILTER: Get only active players
    List<String> players = _getActivePlayers(isTeamA ? _teamAPlayers : _teamBPlayers);
    
    if (players.isEmpty) {
      // Fallback if no active players
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
          content: SizedBox( // Changed to SizedBox for performance
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

  // --- Player Selection Dialog (Fouls) - UPDATED LOGIC ---
  Future<void> _showFoulDialog(String teamName, bool isTeamA) async {
    // FILTER: Get only active players
    List<String> players = _getActivePlayers(isTeamA ? _teamAPlayers : _teamBPlayers);

    // 1. Select Card Type
    String? cardType = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Select Card Type"),
          children: [
             SimpleDialogOption(
               onPressed: () => Navigator.pop(context, 'Yellow'),
               child: const Padding(
                 padding: EdgeInsets.all(8.0),
                 child: Row(children: [Icon(Icons.style, color: Colors.yellow), SizedBox(width: 10), Text("Yellow Card")]),
               ),
             ),
             SimpleDialogOption(
               onPressed: () => Navigator.pop(context, 'Red'),
               child: const Padding(
                 padding: EdgeInsets.all(8.0),
                 child: Row(children: [Icon(Icons.style, color: Colors.red), SizedBox(width: 10), Text("Red Card")]),
               ),
             ),
          ],
        );
      }
    );

    if (cardType == null) return;

    // 2. Select Player
    String? selectedPlayer;
    if (players.isNotEmpty) {
       selectedPlayer = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Select Player ($teamName)"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(players[index]),
                    onTap: () {
                      Navigator.pop(context, players[index]);
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
    } else {
      selectedPlayer = "Unknown";
    }

    if (selectedPlayer != null) {
       setState(() {
         // Get current foul lists to check for existing yellows
         List<Map<String, dynamic>> currentTeamFouls = isTeamA ? _teamAFoulDetails : _teamBFoulDetails;
         
         if (cardType == 'Yellow') {
           // Check if player already has a yellow
           int yellowCount = currentTeamFouls
               .where((f) => f['player'] == selectedPlayer && f['card'] == 'Yellow')
               .length;

           if (yellowCount >= 1) {
             // --- LOGIC: 2nd Yellow converts to Red ---
             
             // 1. Add the 2nd Yellow record
             currentTeamFouls.add({'player': selectedPlayer, 'time': _matchTime, 'card': 'Yellow'});
             
             // 2. Add the Red Card record (Conversion)
             currentTeamFouls.add({'player': selectedPlayer, 'time': _matchTime, 'card': 'Red'});
             
             // 3. Mark as sent off (Banned from current match)
             _sentOffPlayers.add(selectedPlayer!);
             
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("$selectedPlayer sent off (2 Yellows)! Banned for next match."), backgroundColor: Colors.red)
             );
           } else {
             // Just a first yellow
             currentTeamFouls.add({'player': selectedPlayer, 'time': _matchTime, 'card': 'Yellow'});
           }
         } else if (cardType == 'Red') {
           // Direct Red
           currentTeamFouls.add({'player': selectedPlayer, 'time': _matchTime, 'card': 'Red'});
           _sentOffPlayers.add(selectedPlayer!);
           
           ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("$selectedPlayer sent off! Banned for next match."), backgroundColor: Colors.red)
           );
         }

         // Update Counters
         if (isTeamA) {
           _teamAFouls++; 
           // Note: We might want to increment fouls twice if it's 2 yellows -> red, 
           // but usually the counter just tracks the 'Foul' event, not the cards. 
           // Keeping simple increment here.
         } else {
           _teamBFouls++;
         }
         
        _updateScore();
      });
    }
  }

  // --- Player Selection & Outcome Dialog (Penalties) ---
  Future<void> _showPenaltyDialog(String teamName, bool isTeamA) async {
    // FILTER: Get only active players
    List<String> players = _getActivePlayers(isTeamA ? _teamAPlayers : _teamBPlayers);
    
    // 1. Select Player
    String? selectedPlayer;
    if (players.isNotEmpty) {
       selectedPlayer = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Select Penalty Taker ($teamName)"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(players[index]),
                    onTap: () {
                      Navigator.pop(context, players[index]);
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
    } else {
      selectedPlayer = "Unknown";
    }

    if (selectedPlayer == null) return;

    // 2. Select Outcome
    String? outcome = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Penalty Outcome"),
          children: [
             SimpleDialogOption(
               onPressed: () => Navigator.pop(context, 'Scored'),
               child: const Padding(
                 padding: EdgeInsets.all(12.0),
                 child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Goal (Scored)")]),
               ),
             ),
             SimpleDialogOption(
               onPressed: () => Navigator.pop(context, 'Missed'),
               child: const Padding(
                 padding: EdgeInsets.all(12.0),
                 child: Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 10), Text("Missed")]),
               ),
             ),
          ],
        );
      }
    );

    if (outcome == 'Scored') {
      setState(() {
        if (isTeamA) {
           _teamAGoals++;
           _teamAPenalties++; 
           _teamAGoalDetails.add({'player': "$selectedPlayer (P)", 'time': _matchTime});
        } else {
           _teamBGoals++;
           _teamBPenalties++; 
           _teamBGoalDetails.add({'player': "$selectedPlayer (P)", 'time': _matchTime});
        }
        _updateScore();
      });
    } else if (outcome == 'Missed') {
       setState(() {
         if (isTeamA) {
           _teamAPenalties++; 
         } else {
           _teamBPenalties++; 
         }
         _updateScore();
       });
    }
  }

  void _startSecondHalf() {
    setState(() {
      _currentHalf = "2nd Half";
      int halfDuration = (_matchDuration * 60) ~/ 2;
      if (_totalSeconds < halfDuration) _totalSeconds = halfDuration; 
      _matchTime = _formatTime(_totalSeconds);
    });
    _resumeMatch(); 
  }

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
        _matchDuration += extraMins;
        _currentHalf = "Extra Time"; 
      });
      _resumeMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    // --- UPDATED TITLE LOGIC ---
    String titleText = "Football Live Score";
    if (_isMatchFinished) {
      titleText = "Football Recent";
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
              
              if (_isMatchFinished) 
                _buildFinishedScoreCard()
              else 
                _buildLiveScoreCard(),

              const SizedBox(height: 30),
              
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

              if (widget.isAdmin && !_isMatchFinished)
                if (!_showAdminControls)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _showAdminControls = true);
                        if (!_hasTimerStarted) {
                           _resumeMatch();
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

  Widget _buildFinishedScoreCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Text(
              _getWinnerResultText(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(widget.teamAName, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text("$_teamAGoals", 
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w500, color: Color(0xFF004D40), height: 1.0), 
                      ),
                      const SizedBox(height: 16),
                      if (_teamAGoalDetails.isNotEmpty)
                        ..._teamAGoalDetails.map((g) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.0),
                          child: Text(
                            "${g['player']} ${g['time']}'",
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        )).toList()
                      else
                        const SizedBox(height: 10), 
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 45.0, left: 8, right: 8), 
                  child: const Text("-", style: TextStyle(fontSize: 32, color: Colors.grey, fontWeight: FontWeight.w300)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(widget.teamBName, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text("$_teamBGoals", 
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w500, color: Color(0xFF004D40), height: 1.0),
                      ),
                      const SizedBox(height: 16),
                      if (_teamBGoalDetails.isNotEmpty)
                        ..._teamBGoalDetails.map((g) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.0),
                          child: Text(
                            "${g['player']} ${g['time']}'",
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        )).toList()
                      else
                         const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveScoreCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
        child: Column(
          children: [
            _buildTimeBar(),
            const SizedBox(height: 10),
            Text(_currentHalf.toUpperCase(), style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Text(
              _matchTime, 
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, fontFamily: 'monospace')
            ),
            const SizedBox(height: 20),
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
        if (scorers.isNotEmpty)
          ...scorers.map((goal) => Text(
            "${goal['player']} ${goal['time']}'",
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          )).toList()
      ],
    );
  }

  Widget _buildTimeBar() {
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

  Widget _buildAdminControls() {
    bool isHalfTime = _currentHalf == '1st Half' && _totalSeconds >= ((_matchDuration * 60) ~/ 2);
    bool isFullTime = _totalSeconds >= (_matchDuration * 60);
    bool isExtraTimeFinished = isFullTime && _currentHalf == "Extra Time";
    bool hideScoringButtons = _isGamePaused || isHalfTime || _isMatchFinished || isFullTime;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
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
          
          if (!hideScoringButtons) ...[
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
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGoalButton("+1 Foul ${widget.teamAName}", () { if(!_isGamePaused) { _showFoulDialog(widget.teamAName, true); } }),
                _buildGoalButton("+1 Foul ${widget.teamBName}", () { if(!_isGamePaused) { _showFoulDialog(widget.teamBName, false); } }),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGoalButton("+1 Pen ${widget.teamAName}", () { if(!_isGamePaused) { _showPenaltyDialog(widget.teamAName, true); } }),
                _buildGoalButton("+1 Pen ${widget.teamBName}", () { if(!_isGamePaused) { _showPenaltyDialog(widget.teamBName, false); } }),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 20.0),
               child: Text(
                 _isGamePaused ? "Match Paused" : (isHalfTime ? "Half Time - Controls Locked" : (isFullTime ? "Full Time Reached" : "Match Finished")),
                 style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
             ),
          ],
          
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