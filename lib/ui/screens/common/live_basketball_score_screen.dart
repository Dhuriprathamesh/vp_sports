import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart'; // Import ApiConstants

class LiveBasketballScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveBasketballScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveBasketballScoreScreen> createState() => _LiveBasketballScoreScreenState();
}

class _LiveBasketballScoreScreenState extends State<LiveBasketballScoreScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _pollingTimer;

  // Match Data
  int _currentQuarter = 1;
  int _totalQuarters = 4;
  String _matchStatus = 'upcoming'; // upcoming, live, finished
  
  // Scores
  int _team1Score = 0;
  int _team2Score = 0;
  
  // Quarter-wise Scores
  Map<String, int> _team1QuarterScores = {'q1': 0, 'q2': 0, 'q3': 0, 'q4': 0, 'ot': 0};
  Map<String, int> _team2QuarterScores = {'q1': 0, 'q2': 0, 'q3': 0, 'q4': 0, 'ot': 0};

  // Stats
  int _team1Fouls = 0;
  int _team2Fouls = 0;
  int _team1Timeouts = 0;
  int _team2Timeouts = 0;

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _matchStatus != 'finished') {
        _fetchLiveScore(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveScore({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    if (!mounted) return;

    try {
      // --- FIX: Use ApiConstants ---
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/get_basketball_live_score/${widget.matchId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _matchStatus = data['match_status'] ?? 'live';
          _currentQuarter = data['current_quarter'] ?? 1;
          _totalQuarters = data['total_quarters'] ?? 4;

          _team1Score = data['team1_score'] ?? 0;
          _team2Score = data['team2_score'] ?? 0;

          // Map Quarter Scores
          _team1QuarterScores = {
            'q1': data['team1_q1_score'] ?? 0,
            'q2': data['team1_q2_score'] ?? 0,
            'q3': data['team1_q3_score'] ?? 0,
            'q4': data['team1_q4_score'] ?? 0,
            'ot': data['team1_ot_score'] ?? 0,
          };
          _team2QuarterScores = {
            'q1': data['team2_q1_score'] ?? 0,
            'q2': data['team2_q2_score'] ?? 0,
            'q3': data['team2_q3_score'] ?? 0,
            'q4': data['team2_q4_score'] ?? 0,
            'ot': data['team2_ot_score'] ?? 0,
          };

          _team1Fouls = data['team1_fouls'] ?? 0;
          _team2Fouls = data['team2_fouls'] ?? 0;
          _team1Timeouts = data['team1_timeouts'] ?? 0;
          _team2Timeouts = data['team2_timeouts'] ?? 0;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !isRefresh) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateScore({bool finishMatch = false, bool nextQuarter = false}) async {
    // SECURITY CHECK: Only admin can update
    if (!widget.isAdmin) return;

    // Optimistic Update Logic for Quarters
    int newQuarter = _currentQuarter;
    if (nextQuarter && _currentQuarter <= _totalQuarters) {
      newQuarter++;
    }

    // Prepare JSON payload matching database columns
    Map<String, dynamic> payload = {
      'team1_score': _team1Score,
      'team2_score': _team2Score,
      'team1_q1_score': _team1QuarterScores['q1'], 'team2_q1_score': _team2QuarterScores['q1'],
      'team1_q2_score': _team1QuarterScores['q2'], 'team2_q2_score': _team2QuarterScores['q2'],
      'team1_q3_score': _team1QuarterScores['q3'], 'team2_q3_score': _team2QuarterScores['q3'],
      'team1_q4_score': _team1QuarterScores['q4'], 'team2_q4_score': _team2QuarterScores['q4'],
      'team1_ot_score': _team1QuarterScores['ot'], 'team2_ot_score': _team2QuarterScores['ot'],
      'current_quarter': newQuarter,
      'team1_fouls': _team1Fouls, 'team2_fouls': _team2Fouls,
      'team1_timeouts': _team1Timeouts, 'team2_timeouts': _team2Timeouts,
      'match_status': finishMatch ? 'finished' : 'live',
    };

    try {
      // --- FIX: Use ApiConstants ---
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/update_basketball_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      _fetchLiveScore(isRefresh: true);
    } catch (e) {
      // Handle error silently or show toast if critical
    }
  }

  // --- Admin Actions with Security Checks ---

  void _addPoints(int team, int points) {
    if (!widget.isAdmin || _matchStatus == 'finished') return;
    
    String qKey = _currentQuarter > 4 ? 'ot' : 'q$_currentQuarter';

    setState(() {
      if (team == 1) {
        _team1Score += points;
        _team1QuarterScores[qKey] = (_team1QuarterScores[qKey] ?? 0) + points;
      } else {
        _team2Score += points;
        _team2QuarterScores[qKey] = (_team2QuarterScores[qKey] ?? 0) + points;
      }
    });
    _updateScore();
  }

  void _addFoul(int team) {
    if (!widget.isAdmin || _matchStatus == 'finished') return;
    setState(() {
      if (team == 1) _team1Fouls++; else _team2Fouls++;
    });
    _updateScore();
  }

  void _addTimeout(int team) {
    if (!widget.isAdmin || _matchStatus == 'finished') return;
    setState(() {
      if (team == 1) _team1Timeouts++; else _team2Timeouts++;
    });
    _updateScore();
  }

  void _nextQuarter() {
    if (!widget.isAdmin) return;
    if (_currentQuarter >= 4 && _team1Score != _team2Score) {
      _finishMatch();
    } else {
      _updateScore(nextQuarter: true);
    }
  }

  void _finishMatch() {
    if (!widget.isAdmin) return;
    _updateScore(finishMatch: true);
  }

  String _getWinnerText() {
    if (_team1Score > _team2Score) return widget.teamAName;
    if (_team2Score > _team1Score) return widget.teamBName;
    return "Draw";
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys 
        ? AppTheme.boysGradientColors 
        : AppTheme.girlsGradientColors;

    // --- UPDATED TITLE LOGIC ---
    String appBarTitle;
    if (_matchStatus == 'finished') {
      appBarTitle = "Basketball Recent";
    } else {
      appBarTitle = "Basketball Live";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors, 
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));

    return Column(
      children: [
        _buildScoreBoard(), 
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildQuarterTable(),
                const SizedBox(height: 16),
                
                // --- STATUS CONTAINER (Visible to All) ---
                _buildStatusCard(),

                // --- ADMIN ONLY SECTION ---
                // Completely removed from the widget tree if not admin
                if (widget.isAdmin && _matchStatus != 'finished') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Column(
                      children: [
                        Text("Admin Controls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade700)),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.teamAName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(widget.teamBName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAdminControls(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildGameControls(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBoard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeamScore(widget.teamAName, _team1Score, _team1Fouls, _team1Timeouts),
            
            Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  "Q$_currentQuarter", 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _matchStatus == 'live' ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _matchStatus == 'live' ? Colors.red.shade100 : Colors.green.shade100),
                  ),
                  child: Text(
                    _matchStatus == 'live' ? 'LIVE' : 'FINAL', 
                    style: TextStyle(
                      color: _matchStatus == 'live' ? Colors.red : Colors.green, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12
                    )
                  ),
                )
              ],
            ),
            
            _buildTeamScore(widget.teamBName, _team2Score, _team2Fouls, _team2Timeouts),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScore(String name, int score, int fouls, int timeouts) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Text("$score", style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSmallBadge("F: $fouls", Colors.red.shade50, Colors.red.shade800), 
            const SizedBox(width: 8),
            _buildSmallBadge("TO: $timeouts", Colors.orange.shade50, Colors.orange.shade800),
          ],
        )
      ],
    );
  }

  Widget _buildSmallBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildQuarterTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                flex: 3, 
                child: Text("Quarter\nScoring", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2))
              ),
              _buildQuarterHeader("Q1"),
              _buildQuarterHeader("Q2"),
              _buildQuarterHeader("Q3"),
              _buildQuarterHeader("Q4"),
              _buildQuarterHeader("OT"),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildQuarterRow(widget.teamAName, _team1QuarterScores),
          const SizedBox(height: 12),
          _buildQuarterRow(widget.teamBName, _team2QuarterScores),
        ],
      ),
    );
  }

  Widget _buildQuarterHeader(String text) {
    return Expanded(
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildQuarterRow(String team, Map<String, int> scores) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(team, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
        _buildQuarterScore(scores['q1']),
        _buildQuarterScore(scores['q2']),
        _buildQuarterScore(scores['q3']),
        _buildQuarterScore(scores['q4']),
        _buildQuarterScore(scores['ot']),
      ],
    );
  }

  Widget _buildQuarterScore(int? score) {
    return Expanded(
      child: Center(
        child: Text("${score ?? 0}", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_matchStatus == 'finished') {
        String winner = _getWinnerText();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9), 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50)), 
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  Text("WINNER", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                winner, 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    } else {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)],
          ),
          child: Column(
            children: [
              Text("Match Status", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                _matchStatus == 'upcoming' ? "Match Not Started" : "Quarter $_currentQuarter In Progress", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }

  // --- Admin Controls: Guaranteed to be hidden from users ---
  Widget _buildAdminControls() {
    if (!widget.isAdmin) return const SizedBox.shrink(); // Double protection
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildControlPanel(1)), 
          VerticalDivider(width: 32, thickness: 1, color: Colors.grey.shade300),
          Expanded(child: _buildControlPanel(2)), 
        ],
      ),
    );
  }

  Widget _buildControlPanel(int team) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularScoreBtn("+1", () => _addPoints(team, 1)),
              const SizedBox(width: 12),
              _buildCircularScoreBtn("+2", () => _addPoints(team, 2)),
              const SizedBox(width: 12),
              _buildCircularScoreBtn("+3", () => _addPoints(team, 3)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            InkWell(
              onTap: () => _addFoul(team),
              child: const Text("Foul", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            InkWell(
              onTap: () => _addTimeout(team),
              child: const Text("Timeout", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCircularScoreBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0B2), 
          shape: BoxShape.circle,
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildGameControls() {
    if (!widget.isAdmin) return const SizedBox.shrink(); // Double protection
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _nextQuarter,
        icon: Icon(_currentQuarter >= 4 ? Icons.flag : Icons.skip_next),
        label: Text(
          _currentQuarter >= 4 && _team1Score != _team2Score ? "FINISH MATCH" : "NEXT QUARTER",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF212121),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 2,
        ),
      ),
    );
  }
}