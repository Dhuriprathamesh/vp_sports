import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/api_constants.dart'; // Import ApiConstants

class LiveCarromScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveCarromScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveCarromScoreScreen> createState() => _LiveCarromScoreScreenState();
}

class _LiveCarromScoreScreenState extends State<LiveCarromScoreScreen> {
  bool _isLoading = true;
  String _gameStatusText = "Match not started";
  String? _winner;
  String _matchStatus = 'upcoming'; // To track if live or not
  Timer? _pollingTimer;

  // Controllers for Update Dialog
  final TextEditingController _statusController = TextEditingController();
  
  // Selection for Dropdown
  String? _selectedWinner; 

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchLiveScore(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveScore({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/get_carrom_live_score/${widget.matchId}'));
      
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        
        String serverStatusText = data['game_status_text'] ?? "Match not started";
        String serverMatchStatus = data['match_status'] ?? 'upcoming';
        String displayStatusText = serverStatusText;

        if (serverMatchStatus == 'live' && (serverStatusText == "Match Not Started" || serverStatusText == "Match not started")) {
           displayStatusText = "Match Started";
        }

        setState(() {
          _gameStatusText = displayStatusText;
          _winner = data['winner'];
          _matchStatus = serverMatchStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateScore(String statusText, String? winnerName, bool finishMatch) async {
    try {
      // --- FIX: Use ApiConstants ---
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_carrom_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status_text': statusText,
          'winner': winnerName,
          'status': finishMatch ? 'finished' : 'live'
        }),
      );
      _fetchLiveScore(isRefresh: true);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Handle error
    }
  }

  void _showUpdateDialog() {
    _selectedWinner = _winner; 
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Update Match Result"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Winner (Optional)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedWinner,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text("Choose Winner"),
                  items: [
                    DropdownMenuItem(value: widget.teamAName, child: Text(widget.teamAName)),
                    DropdownMenuItem(value: widget.teamBName, child: Text(widget.teamBName)),
                    const DropdownMenuItem(value: "Draw", child: Text("Draw")),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      _selectedWinner = val;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  String autoStatus = "Match Finished";
                  if (_selectedWinner != null) {
                    if (_selectedWinner == "Draw") {
                      autoStatus = "Match Drawn";
                    } else {
                      autoStatus = "Winner: $_selectedWinner";
                    }
                  }
                  _updateScore(autoStatus, _selectedWinner, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935), // Red
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Finish Match"),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF004D40); 
    final bgColor = const Color(0xFFFFF3E0); 

    // --- UPDATED TITLE LOGIC ---
    String title = "Carrom Live";
    if (_matchStatus == 'finished') {
      title = "Carrom Recent";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      backgroundColor: bgColor,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // --- Players Card ---
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30, 
                                  backgroundColor: Colors.teal.withOpacity(0.1),
                                  child: Text(widget.teamAName[0].toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                                ),
                                const SizedBox(height: 12),
                                Text(widget.teamAName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Text("VS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                          Expanded(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30, 
                                  backgroundColor: Colors.teal.withOpacity(0.1),
                                  child: Text(widget.teamBName[0].toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                                ),
                                const SizedBox(height: 12),
                                Text(widget.teamBName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- Status Card ---
                  if (_winner == null || _winner!.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text("Match Status", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(
                              _gameStatusText, 
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // --- Winner Card ---
                  if (_winner != null && _winner!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: const Color(0xFFE8F5E9), // Light Green
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF4CAF50), width: 1)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emoji_events, color: Colors.orange, size: 28),
                                SizedBox(width: 8),
                                Text("WINNER", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _winner!, 
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // --- Admin Controls ---
                  if (widget.isAdmin && _matchStatus != 'finished') 
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _showUpdateDialog,
                        icon: const Icon(Icons.edit_note),
                        label: const Text("Update / Finish Match", style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}