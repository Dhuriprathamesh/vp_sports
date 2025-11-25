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
  String _currentHalf = "1st Half";
  bool _isMatchFinished = false;
  Timer? _pollingTimer;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    if (!widget.isAdmin) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchLiveScore());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
            _teamAGoals = data['team_a_goals'];
            _teamBGoals = data['team_b_goals'];
            _matchTime = data['match_time'];
            _currentHalf = data['current_half'];
            _isMatchFinished = data['match_status'] == 'finished';
          });
        }
      }
    } catch (e) {
      print("Error fetching football score: $e");
    }
  }

  Future<void> _updateScore({bool finishMatch = false}) async {
    if (!widget.isAdmin) return;
    setState(() => _isUpdating = true);
    
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
      if (finishMatch) {
        setState(() => _isMatchFinished = true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating score: $e")));
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(title: const Text("Football - Live Score")),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildScoreBoard(),
            const SizedBox(height: 30),
            if (widget.isAdmin && !_isMatchFinished) _buildAdminControls(),
            if (_isMatchFinished) 
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("MATCH FINISHED", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          children: [
            Text(_currentHalf, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_matchTime, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildTeamColumn(widget.teamAName, _teamAGoals)),
                const Text("-", style: TextStyle(fontSize: 40, color: Colors.grey)),
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
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(goals.toString(), style: TextStyle(fontSize: 50, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAdminControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () { setState(() => _teamAGoals++); _updateScore(); }, child: const Text("+1 Goal A")),
            ElevatedButton(onPressed: () { setState(() => _teamBGoals++); _updateScore(); }, child: const Text("+1 Goal B")),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: TextField(
            decoration: const InputDecoration(labelText: "Update Time (e.g. 23:45)", filled: true, fillColor: Colors.white),
            onSubmitted: (val) { setState(() => _matchTime = val); _updateScore(); },
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _updateScore(finishMatch: true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text("End Match"),
        ),
      ],
    );
  }
}