import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/app_theme.dart';

// --- Data Models ---
// A base class for different types of match results.
abstract class MatchResult {}

class TeamMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final String result;
  final List<String> highlights;

  TeamMatchResult({
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.result,
    this.highlights = const [],
  });
}

class PlayerMatchResult extends MatchResult {
  final String playerA;
  final String playerB;
  final String result;
  final List<String> gameScores;

  PlayerMatchResult({
    required this.playerA,
    required this.playerB,
    required this.result,
    required this.gameScores,
  });
}

class AthleticsResult extends MatchResult {
  final String event;
  final List<Map<String, String>> podium;
  final String winner;

  AthleticsResult({
    required this.event,
    required this.podium,
    required this.winner,
  });
}

class VolleyballMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String result;
  final String bestPlayer;
  final List<String> setScores;

  VolleyballMatchResult({
    required this.teamA,
    required this.teamB,
    required this.result,
    required this.bestPlayer,
    required this.setScores,
  });
}

// --- Data Source ---
// A centralized place for all the sample sports data.
class SportsData {
  static List<MatchResult> getRecentMatches(String sportName) {
    switch (sportName) {
      case 'Cricket':
        return [
          TeamMatchResult(
            teamA: 'Vidyalankar Warriors',
            teamB: 'Poly Strikers',
            scoreA: '152/7 (20.0)',
            scoreB: '153/6 (19.3)',
            result: 'Poly Strikers won by 4 wickets',
            highlights: ['Top Scorer: A. Patil - 62 (38)', 'Best Bowler: R. Deshmukh - 3/22 (4)'],
          )
        ];
      case 'Football':
        return [
          TeamMatchResult(
            teamA: 'Vidyalankar FC',
            teamB: 'Polytechnic United',
            scoreA: '1',
            scoreB: '2',
            result: 'Polytechnic United won 2-1',
            highlights: ['Goal Scorers:', 'Vidyalankar FC: R. Khan (12\')', 'Polytechnic United: S. Pawar (48\'), M. Ghosh (71\')'],
          )
        ];
      case 'Kabaddi':
        return [
          TeamMatchResult(
            teamA: 'Vidyalankar Raiders',
            teamB: 'Polytechnic Panthers',
            scoreA: '39',
            scoreB: '47',
            result: 'Polytechnic Panthers won by 8 points',
            highlights: ['Top Raider: S. Jadhav (15 raid points)', 'Top Defender: A. More (5 tackle points)'],
          )
        ];
      case 'Volleyball':
        return [
          VolleyballMatchResult(
            teamA: 'Vidyalankar Spikers',
            teamB: 'Polytechnic Smashers',
            result: '3-2 Sets (Polytechnic Smashers won)',
            bestPlayer: 'Best Player: R. Naik (12 spikes, 3 blocks)',
            setScores: ['25-20', '22-25', '23-25', '25-18', '9-15'],
          )
        ];
      case 'Athletics':
        return [
          AthleticsResult(
            event: '100m Race',
            winner: 'S. Mehta (Vidyalankar)',
            podium: [
              {'position': '1st', 'athlete': 'S. Mehta', 'time': '11.2s'},
              {'position': '2nd', 'athlete': 'R. Singh', 'time': '11.5s'},
              {'position': '3rd', 'athlete': 'M. Khan', 'time': '11.8s'},
            ]
          )
        ];
      case 'Table Tennis':
        return [
          PlayerMatchResult(
            playerA: 'R. Patel',
            playerB: 'M. Joshi',
            result: 'R. Patel won 3-1',
            gameScores: ['11-8', '7-11', '11-9', '11-6'],
          )
        ];
      case 'Badminton':
        return [
          PlayerMatchResult(
            playerA: 'S. Patil',
            playerB: 'R. Sharma',
            result: 'S. Patil won 2-1',
            gameScores: ['21-18', '18-21', '21-17'],
          )
        ];
      // Other sports can be added here
      default:
        return [];
    }
  }
}

// A screen to show details for a specific sport.
class SportsDetailsScreen extends StatelessWidget {
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const SportsDetailsScreen({
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _SportsDetailsView(
      sportName: sportName,
      sportIcon: sportIcon,
      isForBoys: isForBoys,
      onGenderToggle: onGenderToggle,
    );
  }
}

class _SportsDetailsView extends StatefulWidget {
  final String sportName;
  final IconData sportIcon;
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const _SportsDetailsView({
    required this.sportName,
    required this.sportIcon,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<_SportsDetailsView> createState() => _SportsDetailsViewState();
}

class _SportsDetailsViewState extends State<_SportsDetailsView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<MatchResult> _recentMatches;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _recentMatches = SportsData.getRecentMatches(widget.sportName);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: double.infinity,
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
                  _buildMatchList(context, 'Live', []), // No live data yet
                  _buildMatchList(context, 'Recent', _recentMatches),
                  _buildMatchList(context, 'Upcoming', []), // No upcoming data yet
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.sportIcon, color: Colors.white),
          const SizedBox(width: 8),
          Text('${widget.sportName} Matches'),
        ],
      ),
      actions: [Container(width: 48)],
      centerTitle: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.85),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        tabs: const [
          Tab(text: 'Live'),
          Tab(text: 'Recent'),
          Tab(text: 'Upcoming'),
        ],
      ),
    );
  }

  Widget _buildMatchList(BuildContext context, String category, List<MatchResult> matches) {
    if (matches.isEmpty) {
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
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return FadeInAnimation(
          delay: Duration(milliseconds: 100 + index * 50),
          child: _buildMatchCard(context, match, category)
        );
      },
    );
  }

  // --- Card Builder Logic ---
  Widget _buildMatchCard(BuildContext context, MatchResult match, String category) {
    // This is the new base card that provides the consistent "home page" style.
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(context, category),
            const SizedBox(height: 12),
            _buildCardContent(context, match),
          ],
        ),
      ),
    );
  }
  
  // --- Reusable UI Helper Widgets ---
  
  Widget _buildCardHeader(BuildContext context, String category) {
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
            color: category == 'Live' ? Colors.red.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20)
          ),
          child: Text(
            category.toUpperCase(),
            style: TextStyle(
              color: category == 'Live' ? Colors.red.shade800 : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 10
            ),
          ),
        )
      ],
    );
  }

  // This function determines which type of card content to build.
  Widget _buildCardContent(BuildContext context, MatchResult match) {
    switch (widget.sportName) {
      case 'Cricket':
      case 'Football':
      case 'Kabaddi':
        return _buildTeamMatchContent(context, match as TeamMatchResult);
      case 'Volleyball':
        return _buildVolleyballContent(context, match as VolleyballMatchResult);
      case 'Athletics':
        return _buildAthleticsContent(context, match as AthleticsResult);
      case 'Table Tennis':
      case 'Badminton':
         return _buildPlayerMatchContent(context, match as PlayerMatchResult);
      default:
        return ListTile(title: Text(widget.sportName));
    }
  }

  // --- Specific Card Content Widgets (New and Improved UI) ---
  
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
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        if (match.highlights.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...match.highlights.map((h) => Text(
            h, 
            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: h.contains(':') ? FontStyle.normal : FontStyle.italic)
          ))
        ]
      ],
    );
  }

  Widget _buildPlayerMatchContent(BuildContext context, PlayerMatchResult match) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayerRow(context, match.playerA, match.playerB),
        const SizedBox(height: 8),
        Text(
          'Game Scores: ${match.gameScores.join(" / ")}',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        Text(
          match.result,
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAthleticsContent(BuildContext context, AthleticsResult result) {
    final podiumIcons = [Icons.looks_one, Icons.looks_two, Icons.looks_3];
    final podiumColors = [Colors.amber.shade700, Colors.grey.shade500, Colors.brown.shade400];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...result.podium.asMap().entries.map((entry) {
          final pos = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(podiumIcons[entry.key], color: podiumColors[entry.key], size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${pos['athlete']}', style: const TextStyle(fontSize: 16))),
                Text('${pos['time']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(
          'Winner: ${result.winner}',
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildVolleyballContent(BuildContext context, VolleyballMatchResult match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, match.teamA, match.setScores.where((s) => int.parse(s.split('-')[0]) > int.parse(s.split('-')[1])).length.toString()),
        const SizedBox(height: 8),
        _buildTeamRow(context, match.teamB, match.setScores.where((s) => int.parse(s.split('-')[1]) > int.parse(s.split('-')[0])).length.toString()),
        const SizedBox(height: 12),
         Text('Set Scores: ${match.setScores.join(" | ")}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
         const SizedBox(height: 8),
        Text(
          match.result,
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(match.bestPlayer, style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 12)),
      ],
    );
  }
  
  Widget _buildTeamRow(BuildContext context, String name, String score) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(name.substring(0, 1), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Text(score, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
      ],
    );
  }

  Widget _buildPlayerRow(BuildContext context, String playerA, String playerB) {
     return Row(
      children: [
        const Icon(Icons.person_outline, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(playerA, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("vs", style: TextStyle(color: Colors.grey)),
        ),
        Text(playerB, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        } else {
          // Handle navigation to Schedule/Leaderboard if needed.
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
        const BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
        BottomNavigationBarItem(
          icon: Icon(widget.isForBoys ? Icons.male : Icons.female),
          label: widget.isForBoys ? 'Boys' : 'Girls',
        ),
      ],
    );
  }
}


// --- Animation Widget ---
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  
  const FadeInAnimation({required this.child, this.delay = Duration.zero, super.key});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

