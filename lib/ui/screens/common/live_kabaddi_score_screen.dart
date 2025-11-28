import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LiveKabaddiScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  final bool isAdmin;
  final bool isForBoys;

  const LiveKabaddiScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.isAdmin,
    required this.isForBoys,
  });

  @override
  State<LiveKabaddiScoreScreen> createState() => _LiveKabaddiScoreScreenState();
}

class _LiveKabaddiScoreScreenState extends State<LiveKabaddiScoreScreen> {
  // Score Variables
  int _scoreA = 0;
  int _scoreB = 0;
  
  // Timers & Match State
  String _matchTime = "00:00";
  int _totalSeconds = 0;
  int _matchDurationMinutes = 40; // Default, will fetch from API
  Timer? _matchTimer;
  
  int _raidSeconds = 30;
  Timer? _raidTimer;
  bool _isRaidActive = false;
  String _currentRaidTeam = 'A'; // 'A' or 'B'

  String _currentHalf = "1st Half";
  bool _isMatchFinished = false;
  bool _isHalfTime = false; // New state for half-time break
  bool _isUpdating = false; 

  @override
  void initState() {
    super.initState();
    _fetchScore();
    if (!widget.isAdmin) {
      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && !_isMatchFinished) _fetchScore();
        if (_isMatchFinished) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _raidTimer?.cancel();
    super.dispose();
  }

  // --- API LOGIC ---
  Future<void> _fetchScore() async {
    // REPLACE THIS WITH YOUR IP ADDRESS
    const String host = kIsWeb ? 'localhost' : '192.168.1.12'; 
    
    try {
      final res = await http.get(Uri.parse('http://$host:5000/api/get_kabaddi_live_score/${widget.matchId}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _scoreA = data['team_a_score'] ?? 0;
            _scoreB = data['team_b_score'] ?? 0;
            _matchTime = data['match_time'] ?? "00:00";
            _currentHalf = data['current_half'] ?? "1st Half";
            
            // Get Match Duration from API (it's part of the response now)
            if (data['match_duration'] != null) {
               _matchDurationMinutes = data['match_duration'];
            }

            if (data['match_status'] == 'finished') {
                _isMatchFinished = true;
                _matchTimer?.cancel();
                _raidTimer?.cancel();
            }
            
            // Sync Admin Timer from Server Time string
            if (widget.isAdmin && !_isMatchFinished && _matchTimer == null) {
               try {
                 List<String> parts = _matchTime.split(':');
                 if(parts.length == 2) {
                   _totalSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                   _checkGamePhase(); // Check if we should be in half-time based on fetched time
                 }
               } catch(e) {}
            }
          });
        }
      }
    } catch (e) { 
      print("Fetch Error: $e"); 
    }
  }

  Future<void> _updateScore() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    // REPLACE THIS WITH YOUR IP ADDRESS
    const String host = kIsWeb ? 'localhost' : '192.168.1.12';
    
    try {
      await http.post(
        Uri.parse('http://$host:5000/api/update_kabaddi_score/${widget.matchId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'team_a_score': _scoreA,
          'team_b_score': _scoreB,
          'match_time': _matchTime,
          'current_half': _currentHalf,
          'match_status': _isMatchFinished ? 'finished' : 'live'
        }),
      );
    } catch (e) { 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update Failed: $e"))); 
    } finally {
      if(mounted) setState(() => _isUpdating = false);
    }
  }

  // --- TIMER & GAME PHASE LOGIC ---
  void _checkGamePhase() {
      if (_isMatchFinished) return;

      int halfTimeSeconds = (_matchDurationMinutes * 60) ~/ 2;
      int fullTimeSeconds = _matchDurationMinutes * 60;

      // 1. Check for 1st Half End
      if (_currentHalf == "1st Half" && _totalSeconds >= halfTimeSeconds) {
          if (_matchTimer?.isActive ?? false) {
             _pauseMatchTimer();
          }
          
          if (_isRaidActive) return;

          setState(() {
             _isHalfTime = true;
             _totalSeconds = halfTimeSeconds; 
             _updateTimeDisplay();
          });
      }
      // 2. Check for Full Time
      else if (_totalSeconds >= fullTimeSeconds) {
          if (_matchTimer?.isActive ?? false) {
             _pauseMatchTimer();
          }

          if (_isRaidActive) return;

          setState(() {
             _totalSeconds = fullTimeSeconds; // Cap at full time
             _updateTimeDisplay();
          });
      }
  }

  void _startSecondHalf() {
      setState(() {
          _currentHalf = "2nd Half";
          _isHalfTime = false;
      });
      _toggleMatchTimer(); // Resume timer
      _updateScore();
  }

  void _toggleMatchTimer() {
    if (_matchTimer != null && _matchTimer!.isActive) {
      _pauseMatchTimer();
    } else {
      int fullTimeSeconds = _matchDurationMinutes * 60;
      if (_totalSeconds >= fullTimeSeconds && !_isRaidActive) return; 

      _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        
        int limit = (_currentHalf == "1st Half") ? (_matchDurationMinutes * 60) ~/ 2 : (_matchDurationMinutes * 60);
        
        if (_totalSeconds < limit) {
            setState(() {
              _totalSeconds++;
              _updateTimeDisplay();
            });
        }
        
        _checkGamePhase();

        if (_totalSeconds % 10 == 0) _updateScore();
      });
    }
    setState(() {}); 
  }

  void _pauseMatchTimer() {
      _matchTimer?.cancel();
      setState(() {}); 
  }

  void _updateTimeDisplay() {
      int m = _totalSeconds ~/ 60;
      int s = _totalSeconds % 60;
      _matchTime = "${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}";
  }

  void _toggleRaidTimer() {
    if (_isRaidActive) {
      // --- END RAID LOGIC ---
      _raidTimer?.cancel();
      setState(() {
        _isRaidActive = false;
        _raidSeconds = 30; 
        _currentRaidTeam = (_currentRaidTeam == 'A') ? 'B' : 'A';
      });
      
      _checkGamePhase();
      _updateScore();
    } else {
      // --- START RAID LOGIC ---
      _raidTimer?.cancel();
      setState(() {
        _raidSeconds = 30;
        _isRaidActive = true;
      });
      _raidTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        
        if (_raidSeconds > 0) {
          setState(() => _raidSeconds--);
        } else {
          // --- RAID FINISHED ---
          timer.cancel();
          setState(() {
            _isRaidActive = false;
            _raidSeconds = 30; 
            _currentRaidTeam = (_currentRaidTeam == 'A') ? 'B' : 'A';
            
            _checkGamePhase();
          });
          _updateScore();
        }
      });
    }
  }

  // --- SCORING LOGIC ---
  void _addPoints(String team, int points) {
    if (_isMatchFinished || _isHalfTime) return; 
    
    setState(() {
      if (team == 'A') {
        _scoreA += points;
      } else {
        _scoreB += points;
      }
      
      if (_isRaidActive) {
         _raidTimer?.cancel();
         _isRaidActive = false;
         _raidSeconds = 30; 
      }
      
      _currentRaidTeam = (_currentRaidTeam == 'A') ? 'B' : 'A';
      
      _checkGamePhase();
    });
    _updateScore();
  }

  // --- MULTI-POINT DIALOG ---
  Future<void> _showMultiPointDialog(String team) async {
    final int? points = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Points for ${team == 'A' ? widget.teamAName : widget.teamBName}'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(8, (index) { 
                final int p = index + 3;
                return ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    foregroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text("+$p", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            )
          ],
        );
      },
    );

    if (points != null) {
      _addPoints(team, points);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;
    
    // Determine App Bar Title
    String appBarTitle = "Kabaddi - $_currentHalf";
    if (_isMatchFinished) appBarTitle = "Kabaddi - Result";

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: const Color(0xFF0A4F43)),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: _isMatchFinished 
            ? _buildFinishedView() 
            : _buildLiveView(),
      ),
    );
  }

  // --- VIEW FOR FINISHED MATCH ---
  Widget _buildFinishedView() {
    String resultText = "Match Tied";
    if (_scoreA > _scoreB) {
      resultText = "${widget.teamAName} Won";
    } else if (_scoreB > _scoreA) {
      resultText = "${widget.teamBName} Won";
    }

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Result Heading
              Text(
                resultText,
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Theme.of(context).primaryColor
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "FINAL SCORE",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 30),
              
              // 2. Scores Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(widget.teamAName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text("$_scoreA", style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: Colors.black87)),
                      ],
                    ),
                  ),
                  Container(
                    height: 50,
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(widget.teamBName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text("$_scoreB", style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- VIEW FOR LIVE MATCH ---
  Widget _buildLiveView() {
    return Column(
      children: [
        // 1. Scoreboard Card
        _buildScoreCard(),
        
        // 2. Raid Timer (Big & Bold)
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                 SizedBox(
                   width: 150, height: 150,
                   child: CircularProgressIndicator(
                     value: _raidSeconds / 30, 
                     strokeWidth: 12, 
                     color: _raidSeconds < 10 ? Colors.red : Colors.amber,
                     backgroundColor: Colors.white24,
                   ),
                 ),
                 Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text("$_raidSeconds", style: const TextStyle(fontSize: 60, color: Colors.white, fontWeight: FontWeight.bold)),
                     const Text("RAID TIME", style: TextStyle(fontSize: 12, color: Colors.white70)),
                   ],
                 ),
              ],
            ),
          ),
        ),
        
        // 3. Admin Controls
        if (widget.isAdmin)
            if (_isHalfTime)
                _buildHalfTimeControls()
            else if (_totalSeconds >= _matchDurationMinutes * 60 && !_isRaidActive) 
                _buildFullTimeControls()
            else 
                _buildAdminControls(),
      ],
    );
  }

  Widget _buildScoreCard() {
    int totalMatchSeconds = _matchDurationMinutes * 60;
    double progress = _totalSeconds / totalMatchSeconds;
    if (progress > 1.0) progress = 1.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      color: Colors.white.withOpacity(0.95),
      elevation: 8,
      clipBehavior: Clip.antiAlias, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // --- RED TIME LINE (Progress Bar) ---
          LinearProgressIndicator(
            value: progress, 
            minHeight: 6, 
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTeamColumn(widget.teamAName, _scoreA, _currentRaidTeam == 'A'),
                Column(children: [
                  Text(_matchTime, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                  
                  // START/PAUSE Button
                  if (widget.isAdmin && !_isHalfTime && _totalSeconds < _matchDurationMinutes * 60)
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: _toggleMatchTimer,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                        ),
                        child: Text(
                          _matchTimer?.isActive ?? false ? "PAUSE" : "START", 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: const Text("TIME", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  
                ]),
                _buildTeamColumn(widget.teamBName, _scoreB, _currentRaidTeam == 'B'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamColumn(String name, int score, bool isRaiding) {
    return Column(
      children: [
        // Indicator dot if raiding
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRaiding ? Colors.red : Colors.transparent
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ),
        Text("$score", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF0A4F43))),
      ],
    );
  }

  // --- CONTROLS FOR DIFFERENT STATES ---

  Widget _buildHalfTimeControls() {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text("HALF TIME BREAK", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
             const SizedBox(height: 20),
             ElevatedButton(
               onPressed: _startSecondHalf,
               style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
               child: const Text("Start 2nd Half", style: TextStyle(fontSize: 16, color: Colors.white)),
             )
          ],
        ),
      );
  }

  Widget _buildFullTimeControls() {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text("FULL TIME REACHED", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
             const SizedBox(height: 20),
             ElevatedButton(
               onPressed: () async {
                   setState(() => _isMatchFinished = true);
                   await _updateScore();
                   if (mounted) Navigator.pop(context, true);
               }, 
               style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
               child: const Text("End Match", style: TextStyle(fontSize: 16, color: Colors.white)),
             )
          ],
        ),
      );
  }

  Widget _buildAdminControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleRaidTimer, 
                icon: const Icon(Icons.timer),
                label: Text(_isRaidActive ? "End Raid" : "Start Raid (30s)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRaidActive ? Colors.red : Colors.amber[800], 
                  foregroundColor: Colors.white
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(),
          ),
          const Text("SCORING", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildControlColumn("Team A", 'A', Colors.green.shade50)),
              const SizedBox(width: 16),
              Expanded(child: _buildControlColumn("Team B", 'B', Colors.blue.shade50)),
            ],
          ),
          const SizedBox(height: 10),
          
          SizedBox(
            width: double.infinity, 
            child: ElevatedButton( 
              onPressed: () async {
                 setState(() => _isMatchFinished = true);
                 await _updateScore();
                 if (mounted) Navigator.pop(context, true);
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, 
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("End Match Early", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControlColumn(String label, String team, Color color) {
    bool isAttacking = (team == _currentRaidTeam);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _btn(team, "+1 Pt", 1),
              
              if (isAttacking) ...[
                _btn(team, "+2 Pts", 2),
                SizedBox(
                  height: 35,
                  width: 70, 
                  child: ElevatedButton(
                    onPressed: () => _showMultiPointDialog(team),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: const Text("Multi Pts", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          )
        ],
      ),
    );
  }

  Widget _btn(String team, String label, int points) {
    return SizedBox(
      height: 35,
      width: 60,
      child: ElevatedButton(
        onPressed: () => _addPoints(team, points),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}