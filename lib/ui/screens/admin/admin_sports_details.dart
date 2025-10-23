import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/app_theme.dart';
import '../../../data/mock_data.dart';
import 'add_match.dart';
import '../user/match_details_screen.dart';
import '../common/live_cricket_score_screen.dart'; // IMPORT ADDED

class AdminSportsDetailsScreen extends StatefulWidget {
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const AdminSportsDetailsScreen({
    super.key,
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<AdminSportsDetailsScreen> createState() =>
      _AdminSportsDetailsScreenState();
}

class _AdminSportsDetailsScreenState extends State<AdminSportsDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<UpcomingMatch> _liveMatches = []; // MODIFIED TYPE
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
            // MODIFIED: Create UpcomingMatch objects to store id, teamA, teamB
            final List<UpcomingMatch> fetchedMatches =
                data.map<UpcomingMatch>((json) {
              return UpcomingMatch(
                id: json['id'],
                title: '${widget.sportName} Match', // Title is required
                teamA: json['teamA'],
                teamB: json['teamB'],
                venue: json['venue'], // Venue is required
                date: json['date'], // Date is required
                time: json['time'], // Time is required
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
            setState(() {
              _errorMessage = 'Failed to load $status matches from server.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not connect to the server. Please ensure it is running.';
          print("Connection Error ($status): $e");
        });
      }
    } finally {
      if (mounted && status == 'upcoming') {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadAllMatches() {
    _fetchMatches('live');
    _fetchMatches('upcoming');
    _recentMatches = []; // Clear mock data

    if(_liveMatches.isNotEmpty) {
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
      appBar: _buildAppBar(context),
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
        child: Column(
          children: [
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMatchList(context, 'Live', _liveMatches), // MODIFIED
                  _buildMatchList(context, 'Recent', _recentMatches),
                  _buildUpcomingMatchList(context),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? matchAdded = await showDialog<bool>(
            context: context,
            builder: (context) => AddMatchScreen(sportName: widget.sportName),
          );

          if (matchAdded == true) {
            _loadAllMatches();
            _tabController.animateTo(2);
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildUpcomingMatchList(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage.isNotEmpty && _upcomingMatches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
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
          onTap: () async {
            final bool? refresh = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(
                  matchId: match.id,
                  isAdmin: true,
                  sportName: widget.sportName,
                  sportIcon: widget.sportIcon,
                  isForBoys: widget.isForBoys, // MODIFIED: Pass isForBoys
                  onGenderToggle: widget.onGenderToggle, // MODIFIED: Pass onGenderToggle
                ),
              ),
            );
            if (refresh == true) {
              _loadAllMatches();
            }
          },
          child: _buildMatchCard(context, match, 'Upcoming'),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.sportIcon, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(child: Text('${widget.sportName} Matches')),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
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
            Icon(Icons.hourglass_empty, size: 50, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              'No ${category.toLowerCase()} matches to show.',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        // MODIFIED: Wrap card in GestureDetector for tap handling
        return GestureDetector(
          onTap: () {
            if (category == 'Live' && match is UpcomingMatch) {
              // Navigate to Live Score Screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LiveCricketScoreScreen(
                    matchId: match.id,
                    sportName: widget.sportName,
                    teamAName: match.teamA ?? 'Team A',
                    teamBName: match.teamB ?? 'Team B',
                    isForBoys: widget.isForBoys,
                    onGenderToggle: widget.onGenderToggle,
                    isAdmin: true, // This is the admin screen
                  ),
                ),
              );
            }
          },
          child: _buildMatchCard(context, match, category),
        );
      },
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchResult match, String category) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(context, category),
            const SizedBox(height: 12),
            if (match is UpcomingMatch && category == 'Upcoming') _buildUpcomingMatchContent(context, match),
            // MODIFIED: Use _buildLiveMatchContent for Live category matches (which are UpcomingMatch type)
            if (match is UpcomingMatch && category == 'Live') _buildLiveMatchContent(context, match),
            // Remove the LiveMatch specific check as it's handled above
          ],
        ),
      ),
    );
  }

  // MODIFIED: Changed parameter type and content to match admin_home.dart style
  Widget _buildLiveMatchContent(BuildContext context, UpcomingMatch match) {
    // Using placeholder data similar to admin_home.dart
    String scoreA = "0/0"; // Placeholder
    String scoreB = "0/0"; // Placeholder
    String summary = "Match is live."; // Placeholder

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Middle Section: Teams and Scores
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Team Names Column
              Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(match.teamA ?? 'Team A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   const SizedBox(height: 8),
                   Text(match.teamB ?? 'Team B', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              // Scores Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(scoreA, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                   const SizedBox(height: 8),
                  Text(scoreB, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
            ],
          ),
        ),
         const SizedBox(height: 8), // Space before summary

        // Bottom Section: Summary
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(summary, style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor)),
        ),
      ],
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
