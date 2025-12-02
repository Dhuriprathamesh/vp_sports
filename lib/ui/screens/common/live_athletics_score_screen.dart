import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart'; // Ensure ApiConstants is imported

class LiveAthleticsScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final String teamCName;
  final String eventCategory;
  final bool isAdmin;
  final bool isForBoys;

  const LiveAthleticsScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.teamCName,
    required this.eventCategory,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveAthleticsScoreScreen> createState() =>
      _LiveAthleticsScoreScreenState();
}

class _LiveAthleticsScoreScreenState extends State<LiveAthleticsScoreScreen> {
  bool _isLoading = true;
  String _winner = '';
  String _runnerUp = '';
  String _thirdPlace = '';
  String _gameStatusText = 'Race Not Started';
  Timer? _pollingTimer;

  // For Admin selection
  String? _selectedWinner;
  String? _selectedRunnerUp;
  String? _selectedThirdPlace;

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _fetchLiveScore(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveScore({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoading = true);
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(Uri.parse(
          '${ApiConstants.baseUrl}/api/get_athletics_live_score/${widget.matchId}'));

      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _winner = data['winner'] ?? '';
          _runnerUp = data['runner_up'] ?? '';
          _thirdPlace = data['third_place'] ?? '';
          _gameStatusText = data['game_status_text'] ?? 'Race Not Started';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isBackground) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateScore() async {
    if (_selectedWinner == null || _selectedRunnerUp == null || _selectedThirdPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all podium positions')));
      return;
    }

    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_athletics_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'winner': _selectedWinner,
          'runner_up': _selectedRunnerUp,
          'third_place': _selectedThirdPlace,
          'game_status_text': 'Race Finished',
          'status': 'finished'
        }),
      );

      if (mounted && response.statusCode == 200) {
         _fetchLiveScore();
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Results Updated!')));
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    // --- UPDATED TITLE LOGIC ---
    // If the race is finished (winner declared or status text), show "Recent"
    String title = "${widget.eventCategory} Live";
    if (_gameStatusText == 'Race Finished' || (_winner.isNotEmpty && _winner != 'None')) {
       title = "${widget.eventCategory} Recent";
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    if (widget.isAdmin && _gameStatusText != 'Race Finished') _buildAdminControls() else _buildPodium(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.directions_run, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 12),
            Text(_gameStatusText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("${widget.teamAName} vs ${widget.teamBName} vs ${widget.teamCName}", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium() {
    if (_winner.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _buildRankCard(1, _winner, Colors.amber),
        _buildRankCard(2, _runnerUp, Colors.grey),
        _buildRankCard(3, _thirdPlace, Colors.brown.shade300),
      ],
    );
  }

  Widget _buildRankCard(int rank, String teamName, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Text('#$rank', style: const TextStyle(color: Colors.white))),
        title: Text(teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.emoji_events),
      ),
    );
  }

  Widget _buildAdminControls() {
    final teams = [widget.teamAName, widget.teamBName, widget.teamCName];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Update Results", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _buildDropdown("Winner (Gold)", teams, (val) => setState(() => _selectedWinner = val)),
            _buildDropdown("Runner Up (Silver)", teams, (val) => setState(() => _selectedRunnerUp = val)),
            _buildDropdown("Third Place (Bronze)", teams, (val) => setState(() => _selectedThirdPlace = val)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateScore,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text("Finish Race & Save Results"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}