import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';

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
  late final TabController _tabController;
  late final AnimationController _headerController;
  late final Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _headerAnimation = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
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
      final String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final response = await http.get(
          Uri.parse('http://$host:5000/api/get_match_details/${widget.matchId}'));

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _matchDetails = json.decode(response.body);
          });
          _headerController.forward();
        } else {
          setState(() {
            _errorMessage = 'Failed to load match details.';
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
      final String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final response = await http
          .post(Uri.parse('http://$host:5000/api/start_match/${widget.matchId}'));

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Match is now live!'),
                backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Map<String, int> _getSportPlayerCounts(String sportName) {
    switch (sportName) {
      case 'Cricket':
        return {'players': 11, 'subs': 4};
      case 'Football':
        return {'players': 11, 'subs': 5};
      case 'Kabaddi':
        return {'players': 7, 'subs': 3};
      case 'Volleyball':
        return {'players': 6, 'subs': 2};
      case 'Table Tennis':
      case 'Badminton':
      case 'Carrom':
      case 'Chess':
        return {'players': 5, 'subs': 0};
      default:
        return {'players': 1, 'subs': 0}; 
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
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: widget.isAdmin ? _buildStartMatchButton() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _matchDetails == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage, style: const TextStyle(color: Colors.white)),
      );
    }
    if (_matchDetails == null) {
      return const Center(
          child: Text('No match details found.',
              style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        _buildMatchHeader(
          _matchDetails!['team_a_name'],
          _matchDetails!['team_b_name'],
        ),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildPlayerListTab(
                  _matchDetails!['team_a_name'], List<String>.from(_matchDetails!['team_a_players'])),
              _buildPlayerListTab(
                  _matchDetails!['team_b_name'], List<String>.from(_matchDetails!['team_b_players'])),
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
            color: Colors.black.withAlpha(51),
            borderRadius: BorderRadius.circular(16),
             border: Border.all(color: Colors.white.withAlpha(77)),
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(teamA,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                     Icon(widget.sportIcon, color: Colors.white, size: 32),
                     const SizedBox(height: 4),
                     Text("vs", style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.bold))
                  ],
                ),
              ),
              Expanded(
                  child: Text(teamB,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
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
        color: Colors.black.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.white.withAlpha(230),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withAlpha(242),
          borderRadius: BorderRadius.circular(20),
           boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        tabs: const [
          Tab(child: Text("Info")),
          Tab(child: Text("Team A")),
          Tab(child: Text("Team B")),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final startTime = DateTime.parse(_matchDetails!['start_time']);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withAlpha(26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
               _buildInfoRow(Icons.calendar_today, 'Date', DateFormat.yMMMMd().format(startTime)),
               const Divider(),
               _buildInfoRow(Icons.schedule, 'Time', DateFormat.jm().format(startTime)),
                const Divider(),
               _buildInfoRow(Icons.location_on_outlined, 'Venue', _matchDetails!['venue']),
                const Divider(),
               _buildInfoRow(Icons.sports, 'Umpires', (_matchDetails!['umpires'] as List).join(', ')),
                const Divider(),
               _buildInfoRow(Icons.sports_cricket_outlined, 'Overs', _matchDetails!['overs_per_innings'].toString()),
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
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 16),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: TextStyle(color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildPlayerListTab(String teamName, List<String> players) {
    if (players.isEmpty) {
      return const Center(child: Text("No player data available.", style: TextStyle(color: Colors.white)));
    }
    
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final playingCount = playerCounts['players']!;
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final isSubstitute = index >= playingCount;
        return _AnimatedListItem(
          index: index,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
                child: Text("${index + 1}", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              ),
              title: Text(players[index]),
              trailing: isSubstitute ? const Text("Sub", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)) : null,
            ),
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
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, -4),
          )
        ]
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _startMatch,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_circle_fill_outlined),
          label: const Text('Start Match'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// A simple widget for staggered list animations
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final delay = (widget.index * 80).toDouble();
    final animationDuration = _controller.duration!.inMilliseconds;
    final intervalStart = (delay / animationDuration).clamp(0.0, 1.0);
    
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(intervalStart, 1.0, curve: Curves.easeOut),
      ),
    );
     _slide = Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(intervalStart, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

