import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart'; // Import ApiConstants

class LiveChessScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveChessScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName, // White Team Name
    required this.teamBName, // Black Team Name
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveChessScoreScreen> createState() => _LiveChessScoreScreenState();
}

class _LiveChessScoreScreenState extends State<LiveChessScoreScreen> {
  // Removed turn tracking logic
  String _gameStatusText = "Match Started";
  String? _winner;
  bool _isMatchFinished = false;
  Timer? _pollingTimer;
  bool _isUpdating = false;

  // State variables for player names
  String _playerAName = "Loading...";
  String _playerBName = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchPlayerNames(); // Fetch player details on init
    _initializeScreen(); // Initialize match state and polling
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Initialize screen: Fetch status and ensure match is 'live' if admin
  Future<void> _initializeScreen() async {
    await _fetchLiveScore();

    // If admin opens the screen and match is not finished, ensure it's marked as 'live'
    if (widget.isAdmin && !_isMatchFinished) {
      String statusToUpdate = _gameStatusText;
      if (statusToUpdate.isEmpty || statusToUpdate == "Match not started") {
        statusToUpdate = "Match Started";
      }

      await _updateScore(
        statusText: statusToUpdate,
        finish: false,
      );
    }

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _fetchLiveScore());
  }

  // Fetch specific match details to get player names
  Future<void> _fetchPlayerNames() async {
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/get_match_details/${widget.matchId}?sport=Chess')
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _playerAName = data['player_a_selected'] ?? 'N/A';
            _playerBName = data['player_b_selected'] ?? 'N/A';
            
            // Fallback logic
            if (_playerAName == 'N/A' || _playerAName.isEmpty) {
               List<dynamic> playersA = data['team_a_players'] ?? [];
               if (playersA.isNotEmpty) _playerAName = playersA[0].toString();
            }
            if (_playerBName == 'N/A' || _playerBName.isEmpty) {
               List<dynamic> playersB = data['team_b_players'] ?? [];
               if (playersB.isNotEmpty) _playerBName = playersB[0].toString();
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching players: $e");
      if (mounted) {
        setState(() {
          _playerAName = "N/A";
          _playerBName = "N/A";
        });
      }
    }
  }

  Future<void> _fetchLiveScore() async {
    if (_isUpdating) return;
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/get_chess_live_score/${widget.matchId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _gameStatusText = data['game_status_text'] ?? '';
            _winner = data['winner'];
            _isMatchFinished = data['match_status'] == 'finished';
          });
        }
      }
    } catch (e) {
      print("Error fetching chess score: $e");
    }
  }

  Future<void> _updateScore({required String statusText, String? winner, bool finish = false}) async {
    if (!widget.isAdmin) return;
    setState(() => _isUpdating = true);
    
    try {
      // --- FIX: Use ApiConstants ---
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_chess_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'current_turn': 'N/A', 
          'game_status_text': statusText,
          'winner': winner,
          'status': finish ? 'finished' : 'live' 
        }),
      );
      
      if (mounted) {
        setState(() {
          _gameStatusText = statusText;
          if (finish) {
            _isMatchFinished = true;
            _winner = winner;
          }
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating score: $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    // --- UPDATED TITLE LOGIC ---
    String title = "Chess Live";
    if (_isMatchFinished) {
      title = "Chess Recent";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildScoreBoard(),
              const SizedBox(height: 30),
              
              if (_isMatchFinished)
                 _buildResultCard()
              else 
                 const SizedBox(height: 16),

              if (widget.isAdmin && !_isMatchFinished) ...[
                 const SizedBox(height: 30),
                 _buildAdminControls(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildPlayerColumn("White", widget.teamAName, _playerAName, Icons.person_outline)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("VS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Expanded(child: _buildPlayerColumn("Black", widget.teamBName, _playerBName, Icons.person, isFilled: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerColumn(String sideLabel, String teamName, String playerName, IconData icon, {bool isFilled = false}) {
    return Column(
      children: [
        Icon(icon, size: 40, color: isFilled ? Colors.black : Colors.grey.shade700),
        const SizedBox(height: 8),
        Text(sideLabel, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          playerName, 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade800, fontStyle: FontStyle.italic), 
          textAlign: TextAlign.center
        ),
      ],
    );
  }
  
  Widget _buildResultCard() {
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber, width: 2)),
       child: Column(
         children: [
           const Icon(Icons.emoji_events, color: Colors.amber, size: 50),
           const SizedBox(height: 10),
           const Text("MATCH FINISHED", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           Text(_winner == "Draw" ? "Game Drawn" : "$_winner Wins!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
           const SizedBox(height: 8),
           Text("Result: $_gameStatusText", style: const TextStyle(fontSize: 14, color: Colors.grey)),
         ],
       ),
     );
  }

  Widget _buildAdminControls() {
    return Column(
      children: [
        const Text("Declare Result", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Row(
           children: [
             Expanded(child: _buildResultButton("White Wins", () => _updateScore(statusText: "Won by White", winner: widget.teamAName, finish: true), Colors.green)),
             const SizedBox(width: 10),
             Expanded(child: _buildResultButton("Black Wins", () => _updateScore(statusText: "Won by Black", winner: widget.teamBName, finish: true), Colors.black)),
           ],
        ),
        const SizedBox(height: 10),
        Row(
           children: [
             Expanded(child: _buildResultButton("Draw", () => _updateScore(statusText: "Draw", winner: "Draw", finish: true), Colors.orange)),
             const SizedBox(width: 10),
             Expanded(child: _buildResultButton("Abort", () => _updateScore(statusText: "Aborted", winner: "None", finish: true), Colors.red)),
           ],
        )
      ],
    );
  }
  
  Widget _buildResultButton(String label, VoidCallback onTap, Color color) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
      child: Text(label),
    );
  }
}