import 'dart:math';
import 'package:flutter/material.dart';

class JannatiLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const JannatiLogo({
    super.key,
    this.size = 100,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF1B5E34),
            Color(0xFF0B331D),
            Color(0xFF03140B),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: max(1.5, size * 0.035),
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.05,
                ),
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.25),
                  blurRadius: size * 0.5,
                  spreadRadius: size * 0.08,
                ),
              ]
            : null,
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(size, size),
          painter: _JannatiLogoPainter(),
        ),
      ),
    );
  }
}

class _JannatiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Inner Filigree Ring
    final innerRing = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, size.width * 0.015);
    canvas.drawCircle(center, radius * 0.84, innerRing);

    // 2. Golden Crescent (الهلال الذهبي)
    final crescentPath = Path();
    final crescentCenter = Offset(center.dx - radius * 0.08, center.dy + radius * 0.05);
    final crescentRadius = radius * 0.58;

    crescentPath.addArc(
      Rect.fromCircle(center: crescentCenter, radius: crescentRadius),
      -pi * 0.65,
      pi * 1.3,
    );
    crescentPath.arcTo(
      Rect.fromCircle(
        center: Offset(crescentCenter.dx + radius * 0.22, crescentCenter.dy - radius * 0.04),
        radius: crescentRadius * 0.84,
      ),
      pi * 0.65,
      -pi * 1.3,
      false,
    );
    crescentPath.close();

    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    canvas.drawPath(crescentPath, goldPaint);

    // 3. Radiant Paradise Palm (نخلة النور)
    final palmPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(2.0, size.width * 0.04);

    final trunkPath = Path();
    trunkPath.moveTo(center.dx + radius * 0.05, center.dy + radius * 0.50);
    trunkPath.quadraticBezierTo(
      center.dx + radius * 0.08,
      center.dy + radius * 0.15,
      center.dx + radius * 0.02,
      center.dy - radius * 0.16,
    );
    canvas.drawPath(trunkPath, palmPaint);

    // Palm Crown Fronds
    final frondPaint = Paint()
      ..color = const Color(0xFF69F0AE)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.8, size.width * 0.032);

    final orig = Offset(center.dx + radius * 0.02, center.dy - radius * 0.16);

    // Left Fronds
    canvas.drawLine(orig, Offset(orig.dx - radius * 0.32, orig.dy - radius * 0.16), frondPaint);
    canvas.drawLine(orig, Offset(orig.dx - radius * 0.36, orig.dy - radius * 0.01), frondPaint);
    canvas.drawLine(orig, Offset(orig.dx - radius * 0.28, orig.dy + radius * 0.14), frondPaint);

    // Right Fronds
    canvas.drawLine(orig, Offset(orig.dx + radius * 0.32, orig.dy - radius * 0.16), frondPaint);
    canvas.drawLine(orig, Offset(orig.dx + radius * 0.36, orig.dy - radius * 0.01), frondPaint);
    canvas.drawLine(orig, Offset(orig.dx + radius * 0.28, orig.dy + radius * 0.14), frondPaint);

    // Top Center Frond
    canvas.drawLine(orig, Offset(orig.dx, orig.dy - radius * 0.34), frondPaint);

    // 4. Eight-Pointed Celestial Star of Light (نجم النور)
    final starPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..style = PaintingStyle.fill;

    final starCenter = Offset(center.dx + radius * 0.28, center.dy - radius * 0.36);
    final starR = radius * 0.16;

    final starPath = Path();
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * pi * 2;
      final r = (i % 2 == 0) ? starR : starR * 0.45;
      final p = Offset(starCenter.dx + r * cos(a), starCenter.dy + r * sin(a));
      if (i == 0) {
        starPath.moveTo(p.dx, p.dy);
      } else {
        starPath.lineTo(p.dx, p.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);

    final starCore = Paint()..color = const Color(0xFFFFD700);
    canvas.drawCircle(starCenter, starR * 0.32, starCore);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
