import 'package:flutter/material.dart';
import 'dart:math';

class AdminLeaderboardScreen extends StatefulWidget {
  final bool isForBoys;
  final Function(bool) onGenderToggle;

  const AdminLeaderboardScreen({
    super.key,
    required this.isForBoys,
    required this.onGenderToggle,
  });

  @override
  State<AdminLeaderboardScreen> createState() => _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen>
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
    leaderboardData.sort((a, b) => b['points'].compareTo(a['points']));
    final winner = leaderboardData.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Leaderboard'),
        centerTitle: true,
        backgroundColor: theme.primaryColor.withOpacity(0.85),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withOpacity(0.8),
              const Color(0xFF073A30),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildWinnerText(winner['name']),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildPodium(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
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
    final podiumOrder = [
      leaderboardData[1],
      leaderboardData[0],
      leaderboardData[2],
    ];
    final ranks = [2, 1, 3];
    final podiumHeights = [0.7, 1.0, 0.6]; // Proportional heights

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(podiumOrder.length, (index) {
        final data = podiumOrder[index];
        final rank = ranks[index];
        final heightFactor = podiumHeights[index];
        return _buildPodiumPlace(data, rank, heightFactor, _animations[index]);
      }),
    );
  }

  Widget _buildPodiumPlace(Map<String, dynamic> data, int rank, double heightFactor, Animation<double> animation) {
    final double avatarRadius = rank == 1 ? 50 : 40;
    
    return Flexible(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 200 * (1 - animation.value)),
            child: Opacity(
              opacity: animation.value,
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: data['color'].withOpacity(0.8),
                child: Stack(
                  clipBehavior: Clip.none,
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
                        top: -25,
                        left: 0,
                        right: 0,
                        child: Icon(Icons.emoji_events, color: Colors.yellow[600], size: 40),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                flex: (heightFactor * 10).toInt(),
                child: FractionallySizedBox(
                  heightFactor: heightFactor,
                  child: Container(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2, // Leaderboard is selected
      onTap: (index) {
        if (index == 0) { // Home
          Navigator.of(context).pop();
        } else if (index == 3) { // Gender Toggle
          widget.onGenderToggle(!widget.isForBoys);
        }
        // Other taps (Schedule, etc.) can be handled here
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

