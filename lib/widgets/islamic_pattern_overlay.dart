import 'dart:math';

import 'package:flutter/material.dart';

/// نقش إسلامي هندسي متحرك بحركة انسيابية خفيفة (نجمة ثمانية + أرابيسك حي)
/// يُستخدم كطبقة علوية تفاعلية شفافة فوق الكروت البيضاء
class IslamicPatternOverlay extends StatefulWidget {
  final double opacity;
  final Color color;
  final bool animate;

  const IslamicPatternOverlay({
    super.key,
    this.opacity = 0.08,
    this.color = const Color(0xFF1B5E20),
    this.animate = true,
  });

  @override
  State<IslamicPatternOverlay> createState() => _IslamicPatternOverlayState();
}

class _IslamicPatternOverlayState extends State<IslamicPatternOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _LivingIslamicGeometricPainter(
                  color: widget.color,
                  baseOpacity: widget.opacity,
                  progress: _controller.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LivingIslamicGeometricPainter extends CustomPainter {
  final Color color;
  final double baseOpacity;
  final double progress;

  _LivingIslamicGeometricPainter({
    required this.color,
    required this.baseOpacity,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle breathing opacity
    final breathing = 0.85 + 0.3 * sin(progress * pi * 2);
    final currentOpacity = (baseOpacity * breathing).clamp(0.02, 0.25);

    final linePaint = Paint()
      ..color = color.withValues(alpha: currentOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: currentOpacity * 0.35)
      ..style = PaintingStyle.fill;

    // Gentle kinetic drift
    final driftX = sin(progress * pi * 2) * 12.0;
    final driftY = cos(progress * pi * 2) * 10.0;
    final rotAngle = progress * pi * 0.25; // Gentle rotation

    const spacing = 58.0;
    final cols = (size.width / spacing).ceil() + 2;
    final rows = (size.height / spacing).ceil() + 2;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * spacing + (row.isOdd ? spacing / 2 : 0) + driftX;
        final cy = row * spacing + driftY;

        // Draw animated 8-pointed star
        _drawMorphingStar(canvas, Offset(cx, cy), 18, rotAngle, linePaint);

        // Draw connecting diamond lattice
        _drawDiamondLattice(canvas, Offset(cx, cy), 13, fillPaint);
      }
    }

    // Dynamic Arabesque corner ripples
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: currentOpacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final cornerCenter = Offset(
      size.width * 0.88 + driftX * 0.5,
      size.height * 0.18 + driftY * 0.5,
    );

    for (int r = 18; r < 90; r += 16) {
      final animatedRadius = r + sin(progress * pi * 2 + r) * 3;
      canvas.drawCircle(cornerCenter, animatedRadius, cornerPaint);
    }
  }

  void _drawMorphingStar(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Paint paint,
  ) {
    final path1 = Path();
    final path2 = Path();

    // Square 1
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * pi * 2 - pi / 4 + rotation;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      if (i == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }
    path1.close();

    // Square 2 (rotated by 45 degrees)
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * pi * 2 + rotation;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      if (i == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    path2.close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);

    // Inner sacred circle
    canvas.drawCircle(center, radius * 0.38, paint);
  }

  void _drawDiamondLattice(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size * 0.32);
    path.lineTo(center.dx + size * 0.32, center.dy);
    path.lineTo(center.dx, center.dy + size * 0.32);
    path.lineTo(center.dx - size * 0.32, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LivingIslamicGeometricPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
