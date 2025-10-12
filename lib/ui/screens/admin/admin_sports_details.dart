import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/app_theme.dart';
import '../../../data/mock_data.dart';
import 'add_match.dart';

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
  State<AdminSportsDetailsScreen> createState() => _AdminSportsDetailsScreenState();
}

class _AdminSportsDetailsScreenState extends State<AdminSportsDetailsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late List<MatchResult> _liveMatches;
  late List<MatchResult> _recentMatches;
  late List<MatchResult> _upcomingMatches;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMatches();
  }

  void _loadMatches() {
    setState(() {
      _liveMatches = SportsData.getLiveMatches(widget.sportName);
      _recentMatches = SportsData.getRecentMatches(widget.sportName);
      _upcomingMatches = SportsData.getUpcomingMatches(widget.sportName);

      if (_liveMatches.isNotEmpty) {
        _tabController.index = 0;
      } else {
        _tabController.index = 1;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _showAddMatchDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container(); // This is not used in the builder.
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<double>(begin: 0.5, end: 1.0);
        final scaleAnimation = animation.drive(tween.chain(CurveTween(curve: Curves.easeOutCubic)));
        final fadeAnimation = animation.drive(Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)));

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4 * animation.value, sigmaY: 4 * animation.value),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AddMatchScreen(sportName: widget.sportName),
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys ? AppTheme.boysGradientColors : AppTheme.girlsGradientColors;

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
                  _buildMatchList(context, 'Live', _liveMatches),
                  _buildMatchList(context, 'Recent', _recentMatches),
                  _buildMatchList(context, 'Upcoming', _upcomingMatches),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMatchDialog(context),
        child: const Icon(Icons.add),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.sportIcon, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(child: Text('${widget.sportName} Matches')),
        ],
      ),
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
          ],
        ),
        tabs: const [Tab(text: 'Live'), Tab(text: 'Recent'), Tab(text: 'Upcoming')],
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return FadeInAnimation(
          delay: Duration(milliseconds: 100 + index * 50),
          child: _buildMatchCard(context, match, category),
        );
      },
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchResult match, String category) {
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
            _buildCardContent(context, match, category),
          ],
        ),
      ),
    );
  }
  
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            category.toUpperCase(),
            style: TextStyle(
              color: category == 'Live' ? Colors.red.shade800 : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent(BuildContext context, MatchResult match, String category) {
    if (match is UpcomingMatch) {
      return _buildUpcomingMatchContent(context, match);
    }
    if (match is LiveMatch) {
      return _buildLiveMatchContent(context, match);
    }
    if (match is TeamMatchResult) {
      return _buildTeamMatchContent(context, match);
    }
    if (match is VolleyballMatchResult) {
      return _buildVolleyballContent(context, match);
    }
    if (match is AthleticsResult) {
      return _buildAthleticsContent(context, match);
    }
    if (match is PlayerMatchResult) {
      return _buildPlayerMatchContent(context, match);
    }
    if (match is CarromMatchResult) {
      return _buildCarromContent(context, match);
    }
    if (match is ChessMatchResult) {
      return _buildChessContent(context, match);
    }
    return ListTile(title: Text(widget.sportName));
  }

  // --- WIDGETS FOR DIFFERENT CARD TYPES ---

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
              if (match.teamA != null && match.teamB != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(match.teamA!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text('vs', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      ),
                    ),
                    Text(match.teamB!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                )
              else
                Text(match.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              
              const SizedBox(height: 4),
              Text(match.venue, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(match.date, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            Text(match.time, style: TextStyle(color: Colors.grey[700])),
          ],
        )
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
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildPlayerMatchContent(BuildContext context, PlayerMatchResult pMatch) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayerRow(context, pMatch.playerA, pMatch.playerB),
        const SizedBox(height: 8),
        Text(
          'Game Scores: ${pMatch.gameScores.join(" / ")}',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        Text(
          pMatch.result,
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
        Text(
          result.event,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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
  
  Widget _buildChessContent(BuildContext context, ChessMatchResult match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, match.teamA, "1.5"),
        const SizedBox(height: 8),
        _buildTeamRow(context, match.teamB, "1.5"),
        const SizedBox(height: 12),
        ...match.boardResults.asMap().entries.map((entry) {
          final board = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              'Board ${entry.key + 1}: ${board['playerWhite']} vs ${board['playerBlack']} (${board['result']})',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(
          match.result,
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
  
   Widget _buildCarromContent(BuildContext context, CarromMatchResult match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayerRow(context, match.playerA, match.playerB),
        const SizedBox(height: 8),
        ...match.roundScores.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            'Round ${entry.key + 1}: ${entry.value}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700])
          ),
        )),
        const SizedBox(height: 12),
        Text(
          match.result,
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
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

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  
  const FadeInAnimation({super.key, required this.child, this.delay = Duration.zero});

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

