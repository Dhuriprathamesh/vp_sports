import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart';

// --- Import All Live Score Screens ---
import '../common/live_football_score_screen.dart';
import '../common/live_cricket_score_screen.dart';
import '../common/live_kabaddi_score_screen.dart';
import '../common/live_volleyball_score_screen.dart';
import '../common/live_chess_score_screen.dart';
import '../common/live_carrom_score_screen.dart';
import '../common/live_table_tennis_score_screen.dart';
import '../common/live_badminton_score_screen.dart';
import '../common/live_athletics_score_screen.dart';
import '../common/live_basketball_score_screen.dart';

class MatchDetailsScreen extends StatefulWidget {
  final int matchId;
  final bool isAdmin;
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const MatchDetailsScreen({
    super.key,
    required this.matchId,
    required this.isAdmin,
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _matchDetails;
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;
  late final AnimationController _headerController;
  late final Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize Tab Controller based on sport (Athletics needs 4 tabs)
    int tabs = widget.sportName == 'Athletics' ? 4 : 3;
    _tabController = TabController(length: tabs, vsync: this);

    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerAnimation =
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut);

    _fetchMatchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _fetchMatchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Calls the fixed backend endpoint that supports all sports
      final response = await http.get(Uri.parse(
          '${ApiConstants.baseUrl}/api/get_match_details/${widget.matchId}?sport=${widget.sportName}'));

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _matchDetails = json.decode(response.body);
          });
          _headerController.forward();
        } else {
          setState(() {
            _errorMessage = 'Failed to load match details (${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not connect to the server.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startMatch() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(Uri.parse(
          '${ApiConstants.baseUrl}/api/start_match/${widget.matchId}?sport=${widget.sportName}'));

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Match is now live!'),
                backgroundColor: Colors.green),
          );

          Widget nextScreen;
          String sport = widget.sportName;

          // --- Navigation Logic for All 10 Sports ---
          if (sport == 'Athletics') {
            nextScreen = LiveAthleticsScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              teamCName: _matchDetails!['team_c_name'] ?? 'Team C',
              eventCategory: _matchDetails!['info']['Category'] ?? 'Race',
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Football') {
            nextScreen = LiveFootballScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Kabaddi') {
            nextScreen = LiveKabaddiScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Volleyball') {
            nextScreen = LiveVolleyballScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
              matchFormat: _matchDetails!['info']['Format'] ?? 'Best of 3 Sets',
            );
          } else if (sport == 'Basketball') {
            nextScreen = LiveBasketballScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Chess') {
            nextScreen = LiveChessScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Carrom') {
            nextScreen = LiveCarromScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Table Tennis') {
            nextScreen = LiveTableTennisScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else if (sport == 'Badminton') {
            nextScreen = LiveBadmintonScoreScreen(
              matchId: widget.matchId,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isAdmin: true,
              isForBoys: widget.isForBoys,
            );
          } else {
            // Default to Cricket
            nextScreen = LiveCricketScoreScreen(
              matchId: widget.matchId,
              sportName: widget.sportName,
              teamAName: _matchDetails!['team_a_name'],
              teamBName: _matchDetails!['team_b_name'],
              isForBoys: widget.isForBoys,
              onGenderToggle: widget.onGenderToggle,
              isAdmin: true,
            );
          }

          Navigator.of(context)
              .pushReplacement(MaterialPageRoute(builder: (_) => nextScreen))
              .then((_) {
            Navigator.of(context).pop(true);
          });
        } else {
          final responseBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${responseBody['message']}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to connect to server: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, int> _getSportPlayerCounts(String sportName) {
    if (sportName == 'Athletics') return {'players': 5, 'subs': 0};
    
    switch (sportName) {
      case 'Basketball': return {'players': 5, 'subs': 5};
      case 'Cricket': return {'players': 11, 'subs': 4};
      case 'Football': return {'players': 11, 'subs': 5};
      case 'Kabaddi': return {'players': 7, 'subs': 5};
      case 'Volleyball': return {'players': 6, 'subs': 6};
      case 'Carrom': return {'players': 5, 'subs': 0};
      case 'Table Tennis': return {'players': 5, 'subs': 0};
      case 'Badminton': return {'players': 5, 'subs': 0};
      case 'Chess': return {'players': 5, 'subs': 0};
      default: return {'players': 11, 'subs': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sportName),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: (widget.isAdmin &&
              _matchDetails != null &&
              _matchDetails!['match_status'] == 'upcoming')
          ? _buildStartMatchButton()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _matchDetails == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(_errorMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ));
    }
    if (_matchDetails == null) {
      return const Center(
          child: Text('No match details found.',
              style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        _buildMatchHeader(
            _matchDetails!['team_a_name'], _matchDetails!['team_b_name']),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildPlayerListTab(
                  _matchDetails!['team_a_name'],
                  _matchDetails!['team_a_players']),
              _buildPlayerListTab(
                  _matchDetails!['team_b_name'],
                  _matchDetails!['team_b_players']),
              if (widget.sportName == 'Athletics')
                 _buildPlayerListTab(
                    _matchDetails!['team_c_name'] ?? 'Team C', 
                    _matchDetails!['team_c_players']
                 ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchHeader(String teamA, String teamB) {
    return FadeTransition(
      opacity: _headerAnimation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(_headerAnimation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(teamA,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Icon(widget.sportIcon, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text("vs",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.bold))
                  ],
                ),
              ),
              Expanded(
                  child: Text(teamB,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
              if (widget.sportName == 'Athletics') ...[
                 const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4), 
                    child: Text("vs", style: TextStyle(color: Colors.white70))
                 ),
                 Expanded(
                    child: Text(
                        _matchDetails!['team_c_name'] ?? 'Team C', 
                        textAlign: TextAlign.center, 
                        style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                            fontSize: 18
                        )
                    )
                 ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.white.withOpacity(0.9),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        tabs: [
          const Tab(child: Text("Info")),
          const Tab(child: Text("Team A")),
          const Tab(child: Text("Team B")),
          if (widget.sportName == 'Athletics') const Tab(child: Text("Team C")),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    // Parse time safely
    DateTime? startTime;
    try {
      startTime = DateTime.parse(_matchDetails!['date']);
    } catch (e) {
      startTime = DateTime.now();
    }

    final Map<String, dynamic> info = _matchDetails!['info'] ?? {};
    
    // --- Helper for formatting lists/strings ---
    String formatInfoValue(dynamic val) {
      if (val is List) return val.join(', ');
      return val.toString();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildInfoRow(Icons.calendar_today, 'Date',
                  DateFormat.yMMMMd().format(startTime!)),
              const Divider(),
              _buildInfoRow(
                  Icons.schedule, 'Time', DateFormat.jm().format(startTime)),
              const Divider(),
              _buildInfoRow(Icons.location_on_outlined, 'Venue',
                  _matchDetails!['venue']),
              
              // --- Dynamic Info Fields from API ---
              if (info.isNotEmpty) ...[
                 const Divider(),
                 ...info.entries.map((entry) {
                    IconData icon = Icons.info_outline;
                    if (entry.key.contains('Umpires') || entry.key.contains('Officials') || entry.key.contains('Referees')) icon = Icons.sports;
                    if (entry.key.contains('Overs') || entry.key.contains('Duration') || entry.key.contains('Time')) icon = Icons.timer;
                    if (entry.key.contains('Category') || entry.key.contains('Format')) icon = Icons.category;
                    
                    return Column(
                      children: [
                        _buildInfoRow(icon, entry.key, formatInfoValue(entry.value)),
                        const Divider(),
                      ],
                    );
                 })
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 16),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
              child: Text(value,
                  style: TextStyle(color: Colors.grey[800]),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildPlayerListTab(String teamName, dynamic playersRaw) {
    List<String> players = [];
    if (playersRaw is List) {
      players = playersRaw.map((e) => e.toString()).where((e) => e.toString().isNotEmpty).toList();
    }

    if (players.isEmpty) {
      return const Center(
          child: Text("No player data available.",
              style: TextStyle(color: Colors.white)));
    }

    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final playingCount = playerCounts['players']!;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final isSubstitute = index >= playingCount;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text("${index + 1}",
                  style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold)),
            ),
            title: Text(players[index]),
            trailing: isSubstitute
                ? const Text("Sub",
                    style: TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic))
                : null,
          ),
        );
      },
    );
  }

  Widget _buildStartMatchButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -4))
          ]),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _startMatch,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_circle_fill_outlined),
          label: const Text('Start Match'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}