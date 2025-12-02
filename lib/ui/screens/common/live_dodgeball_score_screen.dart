import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart';

class LiveDodgeballScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveDodgeballScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveDodgeballScoreScreen> createState() => _LiveDodgeballScoreScreenState();
}

class _LiveDodgeballScoreScreenState extends State<LiveDodgeballScoreScreen> {
  // State Variables
  int _scoreA = 0;
  int _scoreB = 0;
  String _matchStatus = "live";
  bool _isMatchFinished = false;
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchScore();
    // Start polling for regular users to keep scores updated
    if (!widget.isAdmin) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchScore(isBackground: true));
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // --- API: Fetch Live Score ---
  Future<void> _fetchScore({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/get_dodgeball_live_score/${widget.matchId}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _scoreA = data['team_a_score'] ?? 0;
            _scoreB = data['team_b_score'] ?? 0;
            _matchStatus = data['match_status'] ?? 'live';
            
            if (_matchStatus == 'finished') {
              _isMatchFinished = true;
              _pollingTimer?.cancel(); // Stop polling if match ended
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching dodgeball score: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API: Update Score (Admin Only) ---
  Future<void> _updateScore({bool finish = false}) async {
    try {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_dodgeball_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'team_a_score': _scoreA,
          'team_b_score': _scoreB,
          'status': finish ? 'finished' : 'live'
        }),
      );
      
      if (finish) {
        setState(() => _isMatchFinished = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Match Ended Successfully"), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Optional: Go back after finishing
        }
      }
    } catch (e) {
      debugPrint("Error updating score: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update score"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Gradient based on Gender Toggle
    final gradient = widget.isForBoys 
        ? AppTheme.boysGradientColors 
        : AppTheme.girlsGradientColors;
    
    // Dynamic AppBar Title
    String title = _isMatchFinished ? "Dodgeball Final Result" : "Dodgeball Live";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient, 
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter
          ),
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // --- Main Scoreboard Card ---
                    _buildScoreCard(),
                    
                    const SizedBox(height: 30),

                    // --- Admin Control Panel ---
                    if (widget.isAdmin && !_isMatchFinished) 
                      _buildAdminControls(),
                      
                    if (_isMatchFinished)
                      _buildFinishedBanner(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Team A
            Expanded(child: _buildTeamColumn(widget.teamAName, _scoreA)),
            
            // VS / Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text("VS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                  if (!_isMatchFinished)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: const Text("LIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                    )
                ],
              ),
            ),
            
            // Team B
            Expanded(child: _buildTeamColumn(widget.teamBName, _scoreB)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String name, int score) {
    return Column(
      children: [
        Text(
          name, 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Text(
          "$score", 
          style: TextStyle(
            fontSize: 56, 
            fontWeight: FontWeight.w900, 
            color: Theme.of(context).primaryColor
          )
        ),
        const Text("Points", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildAdminControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Update Score", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { 
                    setState(() => _scoreA++); 
                    _updateScore(); 
                  },
                  icon: const Icon(Icons.add),
                  label: Text(widget.teamAName, overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { 
                    setState(() => _scoreB++); 
                    _updateScore(); 
                  },
                  icon: const Icon(Icons.add),
                  label: Text(widget.teamBName, overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          ElevatedButton(
            onPressed: () => _showEndMatchDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("FINISH MATCH", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildFinishedBanner() {
    String winner = "Draw";
    if (_scoreA > _scoreB) winner = widget.teamAName;
    if (_scoreB > _scoreA) winner = widget.teamBName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
          const SizedBox(height: 8),
          const Text("WINNER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.green)),
          const SizedBox(height: 4),
          Text(winner, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showEndMatchDialog() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("End Match?"),
        content: const Text("This will finalize the score and mark the match as finished. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateScore(finish: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("End Match"),
          )
        ],
      )
    );
  }
}