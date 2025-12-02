import 'package:flutter/material.dart';
import 'dart:math' as math;

class SixAnimationOverlay extends StatefulWidget {
  final Widget child;
  final Stream<bool> triggerStream; // Stream to trigger animation externally

  const SixAnimationOverlay({
    super.key,
    required this.child,
    required this.triggerStream,
  });

  @override
  State<SixAnimationOverlay> createState() => _SixAnimationOverlayState();
}

class _SixAnimationOverlayState extends State<SixAnimationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _swingProgress;
  late Animation<double> _ballProgress;
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

    // Bat swing animation (0.0 to 1.0)
    _swingProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn), 
      ),
    );

    // Ball moves after impact (impact happens around 0.3 of controller time)
    _ballProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic), 
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
        
        // FIXED POSITIONING LOGIC (STICKY - Gap Area Left)
        final double stickmanBottom = screenSize.height * 0.60; 
        final double stickmanLeft = 20.0; 

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    // 1. The Stickman (Sticky Position)
                    Positioned(
                      bottom: stickmanBottom, 
                      left: stickmanLeft, 
                      child: Opacity(
                        opacity: _opacity.value,
                        child: Transform.scale(
                          scale: _scale.value,
                          child: CustomPaint(
                            size: const Size(100, 100), 
                            painter: SixStickmanPainter(swingProgress: _swingProgress.value),
                          ),
                        ),
                      ),
                    ),
                    
                    // 2. The Ball (Sticky Trajectory)
                    _buildBall(screenSize, stickmanBottom, stickmanLeft),
                    
                    // 3. "6" Text (Near Stickman)
                    if (_controller.value > 0.35)
                       Positioned(
                         bottom: stickmanBottom + 30, 
                         left: stickmanLeft + 70, 
                         child: Opacity(
                           opacity: _opacity.value,
                           child: Transform.scale(
                             scale: 1.0 + (_controller.value * 0.5), 
                             child: Text(
                               "SIX!", 
                               style: TextStyle(
                                 fontSize: 40, // Large font
                                 fontWeight: FontWeight.w900, 
                                 color: Colors.green, 
                                 decoration: TextDecoration.none, 
                                 shadows: [
                                   BoxShadow(
                                     blurRadius: 4, 
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
    // Start Position: Relative to stickman's bat
    final double startX = stickmanLeft + 40; 
    // Converting bottom offset to top offset for calculation
    final double startY = screenSize.height - (stickmanBottom + 50);

    // End Position: Way off screen top-right
    final double endX = screenSize.width * 1.2;
    final double endY = screenSize.height * 0.1;

    // Control Point: Curve upwards (High Arc for 6)
    final double controlX = screenSize.width * 0.6;
    final double controlY = screenSize.height * 0.05;

    final double t = _ballProgress.value;
    
    if (t <= 0.0) return const SizedBox.shrink();

    // Quadratic Bezier Formula
    final double x = (1 - t) * (1 - t) * startX + 2 * (1 - t) * t * controlX + t * t * endX;
    final double y = (1 - t) * (1 - t) * startY + 2 * (1 - t) * t * controlY + t * t * endY;

    // Scale ball down as it flies away
    final double ballScale = 1.0 - (t * 0.5); 

    return Positioned(
      left: x, 
      top: y,
      child: Transform.scale(
        scale: ballScale,
        child: Container(
          width: 12, 
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.red, Colors.red.shade900], 
              center: const Alignment(-0.3, -0.3), 
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(1, 1),
              )
            ],
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

// Stickman Painter with Swing Animation
class SixStickmanPainter extends CustomPainter {
  final double swingProgress; 

  SixStickmanPainter({required this.swingProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.black..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final Paint headPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final double shiftY = 10.0; 

    // 1. Head
    canvas.drawCircle(center.translate(0, -25 + shiftY), 6, headPaint);

    // 2. Body
    canvas.drawLine(center.translate(0, -18 + shiftY), center.translate(0, 10 + shiftY), paint);

    // 3. Legs (Stance)
    canvas.drawLine(center.translate(0, 10 + shiftY), center.translate(-10, 35 + shiftY), paint);
    canvas.drawLine(center.translate(0, 10 + shiftY), center.translate(10, 35 + shiftY), paint);

    // 4. Arms (Moving with Swing)
    double startAngle = 0.5; // Bat held back high
    double endAngle = -2.0;  // Bat swung forward/up
    double currentAngle = startAngle + (endAngle - startAngle) * swingProgress;

    // Hands position
    double handX = 12 * math.cos(currentAngle + 1.5); 
    double handY = 12 * math.sin(currentAngle + 1.5); 
    
    Offset shoulderPos = center.translate(0, -15 + shiftY);
    Offset handsPos = shoulderPos.translate(handX + 4, handY + 8);

    // Draw Arms
    canvas.drawLine(shoulderPos, handsPos, paint);

    // 5. Bat
    final Paint batPaint = Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 3.0..strokeCap = StrokeCap.square;
    double batLength = 35.0;
    double batX = batLength * math.cos(currentAngle);
    double batY = batLength * math.sin(currentAngle);
    
    canvas.drawLine(handsPos, handsPos.translate(batX, batY), batPaint);
  }

  @override
  bool shouldRepaint(covariant SixStickmanPainter oldDelegate) => oldDelegate.swingProgress != swingProgress;
}