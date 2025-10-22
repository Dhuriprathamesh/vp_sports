import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/app_theme.dart';
import '../../../data/mock_data.dart';
import 'match_details_screen.dart';

class SportsDetailsScreen extends StatefulWidget {
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const SportsDetailsScreen({
    super.key,
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<SportsDetailsScreen> createState() => _SportsDetailsScreenState();
}

class _SportsDetailsScreenState extends State<SportsDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<LiveMatch> _liveMatches = [];
  List<MatchResult> _recentMatches = [];
  List<UpcomingMatch> _upcomingMatches = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllMatches();
  }

  Future<void> _fetchMatches(String status) async {
    if (status == 'upcoming') {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final sportNameUrl = widget.sportName.toLowerCase();
      final String apiUrl =
          'http://$host:5000/api/get_matches/$sportNameUrl?status=$status';

      final response = await http.get(Uri.parse(apiUrl));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);

          if (status == 'live') {
            final List<LiveMatch> fetchedMatches =
                data.map<LiveMatch>((json) {
              return LiveMatch(
                teamA: json['teamA'],
                teamB: json['teamB'],
                score: "0/0",
                status: "Match is live",
              );
            }).toList();
            setState(() => _liveMatches = fetchedMatches);
          } else { // upcoming
            final List<UpcomingMatch> fetchedMatches =
                data.map<UpcomingMatch>((json) {
              return UpcomingMatch(
                id: json['id'],
                title: '${widget.sportName} Match',
                teamA: json['teamA'],
                teamB: json['teamB'],
                venue: json['venue'],
                date: json['date'],
                time: json['time'],
              );
            }).toList();
            setState(() => _upcomingMatches = fetchedMatches);
          }
        } else {
          if (mounted) {
            setState(() => _errorMessage = 'Failed to load $status matches.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not connect to the server.');
        print("Connection Error ($status): $e");
      }
    } finally {
      if (mounted && status == 'upcoming') {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadAllMatches() {
    _fetchMatches('live');
    _fetchMatches('upcoming');
    _recentMatches = [];

    if (_liveMatches.isNotEmpty) {
      _tabController.index = 0;
    } else {
      _tabController.index = 2;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.sportIcon, color: Colors.white),
            const SizedBox(width: 8),
            Text('${widget.sportName} Matches'),
          ],
        ),
        actions: [Container(width: 48)],
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _buildTabBar(context),
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMatchList(context, 'Live', _liveMatches),
            _buildMatchList(context, 'Recent', _recentMatches),
            _buildUpcomingMatchList(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildUpcomingMatchList(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 16),
          ),
        ),
      );
    }
    if (_upcomingMatches.isEmpty) {
      return _buildEmptyList('Upcoming');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _upcomingMatches.length,
      itemBuilder: (context, index) {
        final match = _upcomingMatches[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(
                  matchId: match.id,
                  isAdmin: false,
                  sportName: widget.sportName,
                  sportIcon: widget.sportIcon,
                  isForBoys: widget.isForBoys,
                  onGenderToggle: widget.onGenderToggle,
                ),
              ),
            );
          },
          child: _buildMatchCard(context, match, 'Upcoming'),
        );
      },
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(26),
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
        ),
        tabs: const [
          Tab(text: 'Live'),
          Tab(text: 'Recent'),
          Tab(text: 'Upcoming')
        ],
      ),
    );
  }

  Widget _buildEmptyList(String category) {
     return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 50, color: Colors.white.withAlpha(179)),
            const SizedBox(height: 16),
            Text(
              'No ${category.toLowerCase()} matches to show.',
              style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 16),
            ),
          ],
        ),
      );
  }

  Widget _buildMatchList(
      BuildContext context, String category, List<MatchResult> matches) {
    if (matches.isEmpty) {
      return _buildEmptyList(category);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return _buildMatchCard(context, match, category);
      },
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchResult match, String category) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(context, category),
            const SizedBox(height: 12),
            if (match is UpcomingMatch)
              _buildUpcomingMatchContent(context, match),
            if (match is LiveMatch) _buildLiveMatchContent(context, match),
            if (match is TeamMatchResult) _buildTeamMatchContent(context, match),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingMatchContent(BuildContext context, UpcomingMatch match) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(widget.sportIcon, color: Theme.of(context).primaryColor, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.teamA ?? 'Team A',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text('vs',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ),
              Text(match.teamB ?? 'Team B',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(match.venue,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(match.date,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor)),
            Text(match.time, style: TextStyle(color: Colors.grey[700])),
          ],
        )
      ],
    );
  }

  Widget _buildCardHeader(BuildContext context, String category) {
    Color headerColor;
    Color textColor;

    switch (category) {
      case 'Live':
        headerColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'Upcoming':
        headerColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      default:
        headerColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${widget.sportName} • League',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: headerColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            category.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMatchContent(BuildContext context, LiveMatch match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, match.teamA, match.score),
        if (match.teamB.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildTeamRow(context, match.teamB, ""),
        ],
        const SizedBox(height: 12),
        Text(
          match.status,
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTeamMatchContent(BuildContext context, TeamMatchResult match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, match.teamA, match.scoreA),
        const SizedBox(height: 8),
        _buildTeamRow(context, match.teamB, match.scoreB),
        const SizedBox(height: 12),
        Text(
          match.result,
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTeamRow(BuildContext context, String name, String score) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
          child: Text(name.substring(0, 1),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16))),
        Text(score,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary)),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pop();
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys);
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.schedule), label: 'Schedule'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
        BottomNavigationBarItem(
          icon: Icon(widget.isForBoys ? Icons.male : Icons.female),
          label: widget.isForBoys ? 'Boys' : 'Girls',
        ),
      ],
    );
  }
}

