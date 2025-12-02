import 'package:flutter/material.dart';
import 'dart:math' as math;

class GoalAnimationOverlay extends StatefulWidget {
  final Widget child;
  final Stream<String> triggerStream; // Stream to trigger animation (pass team name or side)
  final String teamAName;

  const GoalAnimationOverlay({
    super.key,
    required this.child,
    required this.triggerStream,
    required this.teamAName,
  });

  @override
  State<GoalAnimationOverlay> createState() => _GoalAnimationOverlayState();
}

class _GoalAnimationOverlayState extends State<GoalAnimationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _runProgress;
  late Animation<double> _ballProgress;
  late Animation<double> _opacity;

  bool _isPlaying = false;
  bool _isTeamAGoal = true; // True = Left side, False = Right side
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), 
    );

    // Stickman runs to ball (0.0 to 0.4)
    _runProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.linear), 
      ),
    );

    // Ball flies into net (0.4 to 0.8)
    _ballProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic), 
      ),
    );

    // Fade out (0.8 to 1.0)
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    // Listen to triggers
    widget.triggerStream.listen((teamName) {
      if (mounted) {
        setState(() {
           _isTeamAGoal = (teamName == widget.teamAName);
        });
        _playAnimation();
      }
    });
  }

  void _playAnimation() {
    if (_isPlaying) return;
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    
    setState(() => _isPlaying = true);
    
    _controller.forward(from: 0.0).then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      setState(() => _isPlaying = false);
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final Size screenSize = MediaQuery.of(context).size;
        
        // Animation happens in the center-bottom area
        final double areaHeight = 250;
        final double areaBottom = screenSize.height * 0.3; 

        // --- FIX: WRAP IN STACK to prevent ParentDataWidget Error ---
        return Stack(
          children: [
            Positioned(
              bottom: areaBottom,
              left: 0,
              right: 0,
              height: areaHeight,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacity.value,
                      child: Stack(
                        children: [
                           // 1. The Goal Net (Positioned based on team)
                           Positioned(
                             right: _isTeamAGoal ? null : 20,
                             left: _isTeamAGoal ? 20 : null,
                             bottom: 0,
                             child: CustomPaint(
                               size: const Size(80, 100),
                               painter: GoalNetPainter(isLeft: _isTeamAGoal),
                             ),
                           ),

                           // 2. The Stickman & Ball Animation
                           _buildActionSequence(screenSize.width),
                           
                           // 3. "GOAL!" Text
                           if (_controller.value > 0.5)
                             Center(
                               child: Transform.scale(
                                 scale: 1.0 + (_controller.value * 0.5),
                                 child: Text(
                                   "GOAL!",
                                   style: TextStyle(
                                     fontSize: 60,
                                     fontWeight: FontWeight.w900,
                                     fontStyle: FontStyle.italic,
                                     color: _isTeamAGoal ? Colors.blue : Colors.red,
                                     shadows: [
                                       BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.5))
                                     ]
                                   ),
                                 ),
                               ),
                             )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionSequence(double screenWidth) {
    // If Team A scored (Left Net), Stickman runs from Right to Left.
    // If Team B scored (Right Net), Stickman runs from Left to Right.
    
    double startRunX = _isTeamAGoal ? screenWidth * 0.7 : screenWidth * 0.3;
    double kickPointX = _isTeamAGoal ? screenWidth * 0.4 : screenWidth * 0.6;
    
    // Stickman Position
    double currentStickmanX;
    if (_runProgress.value < 1.0) {
       // Running phase
       currentStickmanX = startRunX + (kickPointX - startRunX) * _runProgress.value;
    } else {
       // Stopped/Kicked phase
       currentStickmanX = kickPointX;
    }

    // Ball Position
    double ballX = kickPointX + (_isTeamAGoal ? -20 : 20); // Starts slightly in front of kick point
    double ballY = 180; // On ground relative to container height
    
    if (_ballProgress.value > 0) {
       double targetNetX = _isTeamAGoal ? 50 : screenWidth - 50;
       ballX = ballX + (targetNetX - ballX) * _ballProgress.value;
       // Parabolic arc for shot
       ballY = 180 - (100 * math.sin(_ballProgress.value * math.pi)); 
    }

    return Stack(
      children: [
        // Ball
        Positioned(
          left: ballX,
          top: ballY, // Using top relative to container
          child: Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black26)],
            ),
          ),
        ),
        // Stickman
        Positioned(
          left: currentStickmanX,
          bottom: 0,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(_isTeamAGoal ? 1.0 : -1.0, 1.0), // Flip if running right
            child: CustomPaint(
              size: const Size(50, 80),
              painter: FootballerPainter(runProgress: _runProgress.value),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlayEntry?.remove(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class GoalNetPainter extends CustomPainter {
  final bool isLeft;
  GoalNetPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw Frame (Simple rectangular goal side view)
    Path frame = Path();
    if (isLeft) {
       frame.moveTo(0, size.height);
       frame.lineTo(size.width, size.height); // Ground line
       frame.moveTo(0, size.height); 
       frame.lineTo(0, 0); // Post
       frame.lineTo(size.width, 0); // Crossbar top perspective
       frame.lineTo(size.width, size.height); // Back post
    } else {
       frame.moveTo(size.width, size.height);
       frame.lineTo(0, size.height);
       frame.moveTo(size.width, size.height);
       frame.lineTo(size.width, 0);
       frame.lineTo(0, 0);
       frame.lineTo(0, size.height);
    }
    canvas.drawPath(frame, paint);

    // Draw Netting (Grid)
    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), netPaint);
    }
    for (double i = 0; i < size.height; i += 10) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), netPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FootballerPainter extends CustomPainter {
  final double runProgress;
  FootballerPainter({required this.runProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint headPaint = Paint()..color = Colors.black;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Leg animation based on run progress (sine wave)
    double legOffset = math.sin(runProgress * 20) * 10;

    // Head
    canvas.drawCircle(center.translate(0, -25), 8, headPaint);
    // Body
    canvas.drawLine(center.translate(0, -18), center.translate(0, 10), paint);
    // Legs
    canvas.drawLine(center.translate(0, 10), center.translate(-10 + legOffset, 35), paint); // Left Leg
    canvas.drawLine(center.translate(0, 10), center.translate(10 - legOffset, 35), paint); // Right Leg
    // Arms
    canvas.drawLine(center.translate(0, -10), center.translate(-10 - legOffset, 5), paint);
    canvas.drawLine(center.translate(0, -10), center.translate(10 + legOffset, 5), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}