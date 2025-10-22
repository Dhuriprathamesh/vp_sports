import 'package:flutter/material.dart';
import 'dart:math';

class LeaderboardScreen extends StatefulWidget {
  final bool isForBoys;

  const LeaderboardScreen({super.key, required this.isForBoys});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _animations;

  // Mock data for the leaderboard
  final List<Map<String, dynamic>> leaderboardData = [
    {
      'name': 'Computer Engineering',
      'logo': 'CO',
      'points': 12450,
      'color': Colors.amber,
    },
    {
      'name': 'Electronics and Computer Engineering',
      'logo': 'EJ',
      'points': 10525,
      'color': const Color(0xFFC0C0C0),
    },
    {
      'name': 'Information Technology',
      'logo': 'IF',
      'points': 10240,
      'color': const Color(0xFFCD7F32),
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animations = List.generate(
      leaderboardData.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.2 * index,
            0.6 + 0.2 * index,
            curve: Curves.elasticOut,
          ),
        ),
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
    final theme = Theme.of(context);
    // Sort data to ensure the highest score is always #1
    leaderboardData.sort((a, b) => b['points'].compareTo(a['points']));
    
    final winner = leaderboardData.first;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Department Leaderboard'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withOpacity(0.8),
              const Color(0xFF073A30),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            _buildWinnerText(winner['name']),
            const Spacer(flex: 1),
            _buildPodium(),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerText(String winnerName) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: Tween<double>(begin: 0.5, end: 1.0)
              .animate(CurvedAnimation(
                parent: _controller,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
              ))
              .value,
          child: Opacity(
            opacity: Tween<double>(begin: 0.0, end: 1.0)
                .animate(CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ))
                .value,
            child: Text(
              '$winnerName is the winner!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black45,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPodium() {
    // Reorder for podium display: 2nd, 1st, 3rd
    final podiumOrder = [
      leaderboardData[1],
      leaderboardData[0],
      leaderboardData[2],
    ];
    final ranks = [2, 1, 3];

    return SizedBox(
      height: 350,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(podiumOrder.length, (index) {
          final data = podiumOrder[index];
          final rank = ranks[index];
          return _buildPodiumPlace(data, rank, _animations[index]);
        }),
      ),
    );
  }

  Widget _buildPodiumPlace(Map<String, dynamic> data, int rank, Animation<double> animation) {
    final double height = rank == 1 ? 300 : (rank == 2 ? 250 : 220);
    final double avatarRadius = rank == 1 ? 50 : 40;
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width / 3.5,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: data['color'].withOpacity(0.8),
              child: Stack(
                children: [
                   Center(
                     child: Text(
                      data['logo'],
                      style: TextStyle(
                        fontSize: avatarRadius - 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                                   ),
                   ),
                  if (rank == 1)
                     Positioned(
                      top: -15,
                      left: 0,
                      right: 0,
                      child: Icon(Icons.emoji_events, color: Colors.yellow[600], size: 40),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Podium Bar
            Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: data['color'], width: 4),
                  left: BorderSide(color: data['color'].withOpacity(0.5), width: 2),
                  right: BorderSide(color: data['color'].withOpacity(0.5), width: 2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#$rank',
                    style: TextStyle(
                      color: data['color'],
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      data['name'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data['points']} points',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
