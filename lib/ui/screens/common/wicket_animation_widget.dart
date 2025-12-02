import 'package:flutter/material.dart';
import 'dart:math' as math;

class WicketAnimationOverlay extends StatefulWidget {
  final Widget child;
  final Stream<bool> triggerStream; // Stream to trigger animation externally

  const WicketAnimationOverlay({
    super.key,
    required this.child,
    required this.triggerStream,
  });

  @override
  State<WicketAnimationOverlay> createState() => _WicketAnimationOverlayState();
}

class _WicketAnimationOverlayState extends State<WicketAnimationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _ballProgress;
  late Animation<double> _stumpFlyProgress;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  bool _isPlaying = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    );

    // Ball travels towards stumps (0.0 to 1.0)
    _ballProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn), // Fast ball
      ),
    );

    // Stumps fly after impact (impact at 0.4)
    _stumpFlyProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack), 
      ),
    );

    // Fade in elements
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_controller);

    // Initial pop-in
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOutBack),
      ),
    );

    // Listen to external triggers
    widget.triggerStream.listen((shouldPlay) {
      if (shouldPlay && mounted) {
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
        
        // FIXED POSITIONING LOGIC (Same as Six Animation)
        final double stickmanBottom = screenSize.height * 0.60; 
        final double stickmanLeft = 40.0; 

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    // 1. The Stickman & Stumps (Sticky Position)
                    Positioned(
                      bottom: stickmanBottom, 
                      left: stickmanLeft, 
                      child: Opacity(
                        opacity: _opacity.value,
                        child: Transform.scale(
                          scale: _scale.value,
                          child: CustomPaint(
                            size: const Size(120, 120), 
                            painter: WicketPainter(stumpProgress: _stumpFlyProgress.value),
                          ),
                        ),
                      ),
                    ),
                    
                    // 2. The Ball (Sticky Trajectory - Incoming)
                    _buildBall(screenSize, stickmanBottom, stickmanLeft),
                    
                    // 3. "OUT!" Text (Near Stickman)
                    if (_controller.value > 0.4)
                       Positioned(
                         bottom: stickmanBottom + 50, 
                         left: stickmanLeft + 60, 
                         child: Opacity(
                           opacity: _opacity.value,
                           child: Transform.scale(
                             scale: 1.0 + (_controller.value * 0.5), 
                             child: Text(
                               "OUT!", 
                               style: TextStyle(
                                 fontSize: 30, 
                                 fontWeight: FontWeight.bold, 
                                 color: Colors.red, 
                                 decoration: TextDecoration.none, 
                                 shadows: [
                                   BoxShadow(
                                     blurRadius: 2, 
                                     color: Colors.white.withOpacity(0.8),
                                     offset: const Offset(0,0)
                                   ),
                                 ]
                               ),
                             ),
                           ),
                         ),
                       )
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBall(Size screenSize, double stickmanBottom, double stickmanLeft) {
    // Target Position: The stumps (relative to stickmanLeft)
    final double endX = stickmanLeft + 30; 
    final double endY = screenSize.height - (stickmanBottom + 20); // Base of stumps

    // Start Position: Incoming from right (Bowler end)
    final double startX = screenSize.width * 0.8; 
    final double startY = endY - 20; // Slightly higher release point

    final double t = _ballProgress.value;
    
    // Hide ball after impact
    if (t >= 1.0) return const SizedBox.shrink();

    // Linear Interpolation (Straight Delivery)
    final double x = startX + (endX - startX) * t;
    final double y = startY + (endY - startY) * t;

    return Positioned(
      left: x, 
      top: y,
      child: Container(
        width: 10, 
        height: 10,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Colors.red, Colors.red.shade900], 
            center: const Alignment(-0.3, -0.3), 
          ),
        ),
      ),
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

// Painter for Stickman getting bowled + Flying Stumps
class WicketPainter extends CustomPainter {
  final double stumpProgress; // 0.0 to 1.0

  WicketPainter({required this.stumpProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0 
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint headPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
      
    final Paint stumpPaint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    final center = Offset(size.width / 2, size.height / 2);
    final double shiftY = 10.0;

    // --- STUMPS ---
    // Base position relative to stickman
    Offset stumpBase = center.translate(-20, 35 + shiftY);
    
    // Stump 1 (Off) - Flies away
    double flyX = -30.0 * stumpProgress;
    double flyY = -40.0 * stumpProgress;
    double rotate = -1.0 * stumpProgress; // Rotate left
    
    _drawStump(canvas, stumpBase.translate(0 + flyX, flyY), stumpPaint, rotation: rotate);
    
    // Stump 2 (Middle) - Stays or wobbles
    _drawStump(canvas, stumpBase.translate(8, 0), stumpPaint);

    // Stump 3 (Leg) - Flies other way
    double flyX2 = 20.0 * stumpProgress;
    double flyY2 = -20.0 * stumpProgress;
    double rotate2 = 0.5 * stumpProgress;
    _drawStump(canvas, stumpBase.translate(16 + flyX2, flyY2), stumpPaint, rotation: rotate2);


    // --- STICKMAN (Reacting/Defeated pose) ---
    // 1. Head (Looking down/shocked)
    canvas.drawCircle(center.translate(10, -25 + shiftY), 6, headPaint);

    // 2. Body
    canvas.drawLine(center.translate(10, -18 + shiftY), center.translate(10, 10 + shiftY), paint);

    // 3. Legs (Stance)
    canvas.drawLine(center.translate(10, 10 + shiftY), center.translate(0, 35 + shiftY), paint);
    canvas.drawLine(center.translate(10, 10 + shiftY), center.translate(20, 35 + shiftY), paint);

    // 4. Arms (Dropped bat or Hands on head)
    // Let's do dropped bat look
    canvas.drawLine(center.translate(10, -15 + shiftY), center.translate(0, 0 + shiftY), paint); // Left arm down
    canvas.drawLine(center.translate(10, -15 + shiftY), center.translate(20, 0 + shiftY), paint); // Right arm down
    
    // 5. Bat (Lying on ground)
    final Paint batPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 3.0;
    canvas.drawLine(center.translate(25, 30 + shiftY), center.translate(45, 35 + shiftY), batPaint);
  }
  
  void _drawStump(Canvas canvas, Offset base, Paint paint, {double rotation = 0.0}) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(rotation);
      canvas.drawLine(Offset.zero, const Offset(0, -30), paint); // 30px tall stump
      canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WicketPainter oldDelegate) => oldDelegate.stumpProgress != stumpProgress;
}