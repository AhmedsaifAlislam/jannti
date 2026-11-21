import 'dart:math' as math;

import 'package:flutter/material.dart';

/// طور نمو الجزيرة المصغّرة عند نسبة إنجاز معيّنة.
///
/// دالة نقية (بلا widget) كي تُختبر بلا محرّك رسم: الحاجب يسأل عنها
/// ليختار النص، والرسّام يسأل عنها ليعرف أيّ طبقة ظهرت.
enum ParadiseStage {
  soil,
  mountains,
  water,
  palms,
  ready;

  /// النص الذي يقابل الطور.
  String get label => switch (this) {
    ParadiseStage.soil => 'يُجمع تراب الجنة…',
    ParadiseStage.mountains => 'تُرفع جبالها…',
    ParadiseStage.water => 'يجري نهرها…',
    ParadiseStage.palms => 'تُغرس نخيلها…',
    ParadiseStage.ready => 'اكتملت جنتك',
  };
}

/// يختار الطور من نسبة الإنجاز (0..1).
///
/// العتبات مقصودة على **الوحدات الست** للحاجب: بأربع وحدات يُرفع المرج
/// والجبال، وبنصفها يظهر الماء، ثم تُغرس النخيل، وأخيرًا تكتمل.
ParadiseStage paradiseStageFor(double progress) {
  // `double.nan.clamp(0,1)` يعيد **١٫٠** في Dart لأن `compareTo` يضع NaN
  // فوق كل شيء — أي أن قيمة تالفة كانت ستعلن «اكتملت جنتك». الفحص صريح.
  if (progress.isNaN) return ParadiseStage.soil;
  final p = progress.clamp(0.0, 1.0);
  if (p >= 1.0) return ParadiseStage.ready;
  if (p >= 0.66) return ParadiseStage.palms;
  if (p >= 0.33) return ParadiseStage.water;
  if (p > 0.0) return ParadiseStage.mountains;
  return ParadiseStage.soil;
}

/// جزيرة مصغّرة تنمو مع تحميل أصول المشهد — بديل عدّاد B3 الجاف.
///
/// ترسم بلا أي أصل خارجي (لا صور ولا شبكات): كل شيء `Canvas`، فالحاجب
/// يظهر في أول إطار بلا تحميل إضافي. والجزيرة تكبر من ٧٨٪ إلى ١٠٠٪ وتظهر
/// طبقاتها بالترتيب، فيقرأ المستخدم تقدّمًا لا رقمًا.
class ParadiseLoader extends StatefulWidget {
  const ParadiseLoader({super.key, required this.progress, this.size = 168});

  /// من ٠ إلى ١.
  final double progress;

  /// عرض وارتفاع اللوحة بالبكسل المنطقي.
  final double size;

  @override
  State<ParadiseLoader> createState() => _ParadiseLoaderState();
}

class _ParadiseLoaderState extends State<ParadiseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NaN يُقصّ إلى ١٫٠ في `clamp` (compareTo يضع NaN فوق كل شيء).
    final double safeProgress = widget.progress.isNaN
        ? 0.0
        : widget.progress.clamp(0.0, 1.0);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ParadiseLoaderPainter(
              progress: safeProgress,
              pulse: _pulse.value,
            ),
          );
        },
      ),
    );
  }
}

class _ParadiseLoaderPainter extends CustomPainter {
  const _ParadiseLoaderPainter({required this.progress, required this.pulse});

  final double progress;

  /// ٠..١ من دورة ٧ ثوانٍ — للنور لا للجزيرة.
  final double pulse;

  /// حدّ ظهور طبقة: يعيد ٠..١ محليًا بعد لحظة `at`.
  double _reveal(double at) => ((progress - at) / 0.10).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final s = size.width;
    final cx = s * 0.5;

    // الجزيرة تكبر مع التقدّم: ٧٨٪ في البداية ← ١٠٠٪ عند الاكتمال.
    final grow = 0.78 + 0.22 * progress;

    // هالة نور خلف الجزيرة، تتنفّس مع النبضة.
    final haloRadius = s * (0.42 + 0.03 * math.sin(pulse * math.pi * 2));
    final halo = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              const Color(0xFFFFD700).withValues(alpha: 0.16 + 0.05 * progress),
              const Color(0xFF0B331D).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, s * 0.5), radius: haloRadius),
          );
    canvas.drawCircle(Offset(cx, s * 0.5), haloRadius, halo);

    // كل شيء داخل مربع محور الجزيرة، فيكبر مع `grow` دفعة واحدة.
    final center = Offset(cx, s * 0.60);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(grow, grow);
    canvas.translate(-center.dx, -center.dy);

    _paintGround(canvas, s, cx);
    _paintMountains(canvas, s, cx);
    _paintWater(canvas, s, cx);
    _paintRiver(canvas, s, cx);
    _paintPalms(canvas, s, cx);

    canvas.restore();

    _paintFireflies(canvas, s, cx);
  }

  /// التربة والقشرة الصخرية: أول ما يظهر، وهو خلف كل شيء.
  void _paintGround(Canvas canvas, double s, double cx) {
    final baseY = s * 0.66;
    final rx = s * 0.33;
    final ry = s * 0.105;

    // القشرة الصخرية أسفل الجزيرة: شكل بيضاوي ممدود للأسفل.
    final rock = Path()
      ..moveTo(cx - rx, baseY)
      ..quadraticBezierTo(
        cx - rx * 0.92,
        baseY + ry * 1.5,
        cx,
        baseY + ry * 2.0,
      )
      ..quadraticBezierTo(cx + rx * 0.92, baseY + ry * 1.5, cx + rx, baseY)
      ..quadraticBezierTo(cx, baseY + ry * 0.5, cx - rx, baseY);
    canvas.drawPath(
      rock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF8A5A32), Color(0xFF4A2E18)],
        ).createShader(Rect.fromLTWH(cx - rx, baseY, rx * 2, ry * 2)),
    );

    // المرج: بيضاوي أخضر فوق القشرة.
    final meadow = Rect.fromCenter(
      center: Offset(cx, baseY),
      width: rx * 2,
      height: ry * 2,
    );
    canvas.drawOval(
      meadow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF3E9B5F), Color(0xFF1E5C36)],
        ).createShader(meadow),
    );

    // حلقة ضوء رقيقة على الحافة العليا — تفصل الجزيرة عن الخلفية.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, baseY), width: rx * 2, height: ry * 2),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006
        ..color = const Color(0xFFE8C97A).withValues(alpha: 0.45),
    );
  }

  /// أربع قمم على الحافة العلوية، تظهر الواحدة بعد الأخرى.
  void _paintMountains(Canvas canvas, double s, double cx) {
    final t = _reveal(0.08);
    if (t <= 0) return;

    const peaks = <List<double>>[
      // x (نسبة من العرض)، ارتفاع (نسبة من s)، تأخير
      <double>[-0.24, 0.115, 0.00],
      <double>[-0.09, 0.155, 0.25],
      <double>[0.07, 0.125, 0.50],
      <double>[0.22, 0.095, 0.70],
    ];
    final baseY = s * 0.615;

    for (final peak in peaks) {
      final local = ((t - peak[2]) / 0.45).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final h = s * peak[1] * local;
      final half = s * 0.075;
      final x = cx + s * peak[0];

      final path = Path()
        ..moveTo(x - half, baseY)
        ..lineTo(x, baseY - h)
        ..lineTo(x + half, baseY)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF7FB069), Color(0xFF2F6B45)],
          ).createShader(Rect.fromLTWH(x - half, baseY - h, half * 2, h)),
      );
    }
  }

  /// بحيرتان صغيرتان على البيضاوي.
  void _paintWater(Canvas canvas, double s, double cx) {
    final t = _reveal(0.30);
    if (t <= 0) return;

    final lakes = <List<double>>[
      <double>[-0.16, 0.655, 0.052, 0.022],
      <double>[0.15, 0.688, 0.044, 0.019],
    ];
    for (final lake in lakes) {
      final rect = Rect.fromCenter(
        center: Offset(cx + s * lake[0], s * lake[1]),
        width: s * lake[2] * 2 * t,
        height: s * lake[3] * 2 * t,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF63D6C6), Color(0xFF1E7A86)],
          ).createShader(rect),
      );
    }
  }

  /// النهر: شريط منحنى من أعلى الجزيرة إلى حافتها — تصغير لـ9.4.
  void _paintRiver(Canvas canvas, double s, double cx) {
    final t = _reveal(0.48);
    if (t <= 0) return;

    final river = Path()
      ..moveTo(cx - s * 0.02, s * 0.60)
      ..quadraticBezierTo(cx - s * 0.09, s * 0.645, cx - s * 0.05, s * 0.675)
      ..quadraticBezierTo(cx - s * 0.02, s * 0.700, cx + s * 0.02, s * 0.735);

    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.026 * t
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFC8F5EE), Color(0xFF4FC3D0)],
        ).createShader(Rect.fromLTWH(0, s * 0.58, s, s * 0.18)),
    );
  }

  /// ثلاث نخيل تنمو: الجذع يطول والسعف يتفتّح.
  void _paintPalms(Canvas canvas, double s, double cx) {
    final t = _reveal(0.62);
    if (t <= 0) return;

    const palms = <List<double>>[
      <double>[-0.19, 0.70, 0.00],
      <double>[0.05, 0.715, 0.28],
      <double>[0.21, 0.70, 0.52],
    ];

    for (final palm in palms) {
      final local = ((t - palm[2]) / 0.48).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final baseX = cx + s * palm[0];
      final baseY = s * palm[1];
      final height = s * 0.085 * local;
      final top = Offset(baseX + s * 0.006, baseY - height);

      canvas.drawLine(
        Offset(baseX, baseY),
        top,
        Paint()
          ..color = const Color(0xFF8B6337)
          ..strokeWidth = math.max(1.0, s * 0.010)
          ..strokeCap = StrokeCap.round,
      );

      if (local < 0.55) continue;
      final frond = (local - 0.55) / 0.45;
      final frondPaint = Paint()
        ..color = const Color(0xFF4FD08A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * 0.007)
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < 5; i++) {
        final angle = -math.pi * 0.9 + i * math.pi * 0.45;
        final length = s * 0.045 * frond;
        canvas.drawLine(
          top,
          Offset(
            top.dx + math.cos(angle) * length,
            top.dy + math.sin(angle) * length * 0.75,
          ),
          frondPaint,
        );
      }
    }
  }

  /// يمامات النور: ست نقاط تدور حول الجزيرة، تزداد مع التقدّم.
  void _paintFireflies(Canvas canvas, double s, double cx) {
    final count = (2 + progress * 6).round();
    for (var i = 0; i < count; i++) {
      final phase = i / count * math.pi * 2 + pulse * math.pi * 2;
      final rx = s * (0.36 + 0.04 * (i.isEven ? 1 : -1));
      final ry = s * 0.20;
      final p = Offset(
        cx + math.cos(phase) * rx,
        s * 0.58 + math.sin(phase) * ry,
      );
      final alpha = 0.35 + 0.45 * (0.5 + 0.5 * math.sin(phase * 2 + pulse * 6));
      canvas.drawCircle(
        p,
        s * 0.008,
        Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParadiseLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}
