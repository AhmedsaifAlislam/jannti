import 'package:flutter/material.dart';

/// ============================================================================
/// 🎨 ملف الإضاءة والألوان الموحّد لعالم الجنة ثلاثي الأبعاد.
/// ============================================================================
/// كل ما يخصّ مظهر السماء والضباب والإضاءة والشمس/القمر والسحاب والنجوم موجود
/// هنا فقط — عدّل الأرقام بحرية **دون لمس منطق المشهد** في
/// `screens/jannati_3d_screen.dart`.
///
/// 🌅 طريقة العمل: «محطات زمنية + استيفاء»
///   • [dayCycle] = محطات مرتّبة على مدار ٢٤ ساعة (فجر ← ظهيرة ← غروب ← ليل).
///   • [specAtHour] تعطي لوحة الإضاءة الدقيقة لأي لحظة، بحساب استيفاء خطي بين
///     المحطتين المحيطتين — لذلك تنساب المشاهد بلا أي قفزة على مدار اليوم.
///   • إضافة/حذف/تعديل محطة لا يؤثر على أي شيء آخر.
///
/// 🔧 دليل التعديل السريع:
///   • سماء قبة المشهد ................ [PhaseSpec.skyColor]
///   • أبخرة الأفق (وهي التي تُلوّن الأرض البعيدة) .. [PhaseSpec.fogColor]
///   • قوة إضاءة المشهد كاملًا ......... [PhaseSpec.ambientIntensity]
///   • الشمس/القمر .................... [PhaseSpec.sun] و [PhaseSpec.sunIntensity]
///   • موضع القرص المرئي وارتفاعه ..... [PhaseSpec.sunPos] (y سالب = تحت الأفق)
///   • ظهور النجوم .................... [PhaseSpec.starOpacity]
///   • كثافة النجوم وتوهّجها .......... [starField]
/// ============================================================================

/// ⏱️ عدد الإطارات بين تحديثين تلقائيين (٣٠ إطارًا ≈ نصف ثانية).
/// زيادته = تحديث أقل = استهلاك أقل، وبلا أي فرق بصري.
const int kAutoRefreshFrames = 30;

/// 🎞️ مدة انسياب التبديل اليدوي بالزر (بالثواني).
const double kManualTransitionSeconds = 2.5;

/// 🎛️ أوضاع التحكّم بالإضاءة.
enum DayLightMode {
  auto,
  dawn,
  noon,
  night;

  /// هل يتبع ساعة الجهاز؟
  bool get isAuto => this == DayLightMode.auto;

  /// الساعة الثابتة لهذا الوضع (null = تلقائي حسب الساعة).
  double? get fixedHour {
    switch (this) {
      case DayLightMode.auto:
        return null;
      case DayLightMode.dawn:
        return 6.25; // ٠٦:١٥ — الشروق النحاسي
      case DayLightMode.noon:
        return 12.5; // ١٢:٣٠ — الظهيرة الذهبية (المظهر الأصلي)
      case DayLightMode.night:
        return 0.5; // ٠٠:٣٠ — الليل الكحلي المرصّع بالنجوم
    }
  }

  /// الاسم المعروض على زر التبديل.
  String get label {
    switch (this) {
      case DayLightMode.auto:
        return 'تلقائي';
      case DayLightMode.dawn:
        return 'فجر';
      case DayLightMode.noon:
        return 'ظهيرة';
      case DayLightMode.night:
        return 'ليل';
    }
  }

  /// أيقونة زر التبديل.
  IconData get icon {
    switch (this) {
      case DayLightMode.auto:
        return Icons.schedule;
      case DayLightMode.dawn:
        return Icons.wb_twilight;
      case DayLightMode.noon:
        return Icons.wb_sunny_outlined;
      case DayLightMode.night:
        return Icons.nightlight_round;
    }
  }

  /// لون زر التبديل.
  Color get accent {
    switch (this) {
      case DayLightMode.auto:
        return const Color(0xFF8FD6C0);
      case DayLightMode.dawn:
        return const Color(0xFFFFB37A);
      case DayLightMode.noon:
        return const Color(0xFFFFD700);
      case DayLightMode.night:
        return const Color(0xFF9FC6FF);
    }
  }
}

/// لوحة إضاءة لحظة واحدة: السماء/الضباب + الإضاءة + الشمس/القمر + السحاب + النجوم.
///
/// جميع الألوان بصيغة `0xRRGGBB`.
class PhaseSpec {
  const PhaseSpec({
    required this.skyColor,
    required this.fogColor,
    required this.ambient,
    required this.ambientIntensity,
    required this.sun,
    required this.sunIntensity,
    required this.fill,
    required this.fillIntensity,
    required this.lightPos,
    required this.sunPos,
    required this.core,
    required this.corona,
    required this.cloud,
    required this.starOpacity,
  });

  /// لون قبة السماء (عادم الضباب) — هو ما تراه أعلى المشهد.
  final int skyColor;

  /// لون أبخرة الأفق (الضباب) — يُلوّن الأرض البعيدة ويمنح العمق.
  final int fogColor;

  /// الإضاءة المحيطة (تحدد مدى «إنارة» المشهد كاملًا).
  final int ambient;
  final double ambientIntensity;

  /// مصدر الضوء الرئيسي: الشمس نهارًا / القمر ليلًا.
  final int sun;
  final double sunIntensity;

  /// ضوء تعبئة خفيف يمنع الوجوه الميتة السوداء.
  final int fill;
  final double fillIntensity;

  /// موضع مصدر الضوء `[x, y, z]` — خفّض `y` لتقترب الشمس من الأفق.
  final List<double> lightPos;

  /// موضع القرص المرئي (الشمس/القمر) `[x, y, z]` — `y` سالب = تحت الأفق.
  final List<double> sunPos;

  /// لون القرص المرئي وهالته ولون السحاب.
  final int core;
  final int corona;
  final int cloud;

  /// عتامة النجوم (0 = بلا نجوم في هذه اللحظة).
  final double starOpacity;
}

/// محطة زمنية: لحظة على مدار اليوم مع لوحتها واسم فترتها.
class DayKeyframe {
  const DayKeyframe({
    required this.hour,
    required this.label,
    required this.spec,
  });

  /// الساعة ككسر عشري (6.25 تعني ٠٦:١٥).
  final double hour;

  /// اسم الفترة (يُعرض على زر التبديل في الوضع التلقائي).
  final String label;

  final PhaseSpec spec;
}

/// 🎨 دورة اليوم: ٨ محطات — فجر ← شروق ← ضحى ← ظهيرة ← عصر ← غروب ← غسق ← ليل.
///
/// ⚠️ يجب أن تبقى مرتّبة تصاعديًا بالساعة.
const List<DayKeyframe> dayCycle = [
  // ── ٠٠:٣٠ ليل: سماء كحلية صافية + قمر فضي + نجوم كاملة ──────────────────
  DayKeyframe(
    hour: 0.5,
    label: 'ليل',
    spec: PhaseSpec(
      skyColor: 0x0C2138,
      fogColor: 0x0A2029,
      ambient: 0x1F4A52,
      ambientIntensity: 0.34,
      sun: 0xB8D8FF,
      sunIntensity: 0.50,
      fill: 0x1B5E20,
      fillIntensity: 0.22,
      lightPos: [60, 70, 40],
      sunPos: [35, 70, -88],
      core: 0xEAF2FF,
      corona: 0xB3D4FF,
      cloud: 0x86A79E,
      starOpacity: 1.0,
    ),
  ),

  // ── ٠٥:١٥ فجر: كحلي مزرق + توهّج دافئ يبدأ والقمر تحت الأفق ─────────────
  DayKeyframe(
    hour: 5.25,
    label: 'فجر',
    spec: PhaseSpec(
      skyColor: 0x1A3346,
      fogColor: 0x1C3A3C,
      ambient: 0x54696B,
      ambientIntensity: 0.50,
      sun: 0xFFC48F,
      sunIntensity: 0.55,
      fill: 0x24564E,
      fillIntensity: 0.26,
      lightPos: [30, 14, 55],
      sunPos: [-45, -30, -95],
      core: 0xFFD9B0,
      corona: 0xFF9E63,
      cloud: 0xC9B8B4,
      starOpacity: 0.55,
    ),
  ),

  // ── ٠٦:١٥ شروق: شمس نحاسية منخفضة شرقًا (المظهر الزمردي–الذهبي المعتمد) ─
  DayKeyframe(
    hour: 6.25,
    label: 'شروق',
    spec: PhaseSpec(
      skyColor: 0x2E4A50,
      fogColor: 0x2E4A50,
      ambient: 0x6E8078,
      ambientIntensity: 0.62,
      sun: 0xFFB067,
      sunIntensity: 1.0,
      fill: 0x2E7D6B,
      fillIntensity: 0.38,
      lightPos: [110, 22, 60],
      sunPos: [118, 12, -60],
      core: 0xFFE3B8,
      corona: 0xFFA05A,
      cloud: 0xF7DCC6,
      starOpacity: 0.15,
    ),
  ),

  // ── ٠٨:٣٠ ضحى: زمردي صافٍ + ضوء أبيض ذهبي ───────────────────────────────
  DayKeyframe(
    hour: 8.5,
    label: 'ضحى',
    spec: PhaseSpec(
      skyColor: 0x1E4A41,
      fogColor: 0x1E4A41,
      ambient: 0x586557,
      ambientIntensity: 0.60,
      sun: 0xFFCB9C,
      sunIntensity: 1.20,
      fill: 0x338A55,
      fillIntensity: 0.39,
      lightPos: [95, 55, 48],
      sunPos: [100, 48, -70],
      core: 0xFFF2D8,
      corona: 0xFFD08A,
      cloud: 0xFBE7D6,
      starOpacity: 0.0,
    ),
  ),

  // ── ١٢:٣٠ ظهيرة ذهبية ★ (المظهر الأصلي بلا أي تغيير) ────────────────────
  DayKeyframe(
    hour: 12.5,
    label: 'ظهيرة',
    spec: PhaseSpec(
      skyColor: 0x134C37,
      fogColor: 0x134C37,
      ambient: 0x4A6B56,
      ambientIntensity: 0.55,
      sun: 0xFFE082,
      sunIntensity: 1.35,
      fill: 0x388E3C,
      fillIntensity: 0.40,
      lightPos: [55, 90, 45],
      sunPos: [50, 90, -90],
      core: 0xFFFDF0,
      corona: 0xFFE082,
      cloud: 0xFFFAF0,
      starOpacity: 0.0,
    ),
  ),

  // ── ١٦:٠٠ عصر: زمردي ذهبي أدفأ والشمس تميل غربًا ────────────────────────
  DayKeyframe(
    hour: 16.0,
    label: 'عصر',
    spec: PhaseSpec(
      skyColor: 0x18513C,
      fogColor: 0x18513C,
      ambient: 0x50705A,
      ambientIntensity: 0.56,
      sun: 0xFFD98A,
      sunIntensity: 1.15,
      fill: 0x3A8B3F,
      fillIntensity: 0.36,
      lightPos: [10, 62, 50],
      sunPos: [5, 60, -95],
      core: 0xFFF7E2,
      corona: 0xFFCE86,
      cloud: 0xFDEEDC,
      starOpacity: 0.0,
    ),
  ),

  // ── ١٨:٤٥ غروب: سماء بنفسجية–كحلية وأبخرة عنبرية وشمس عند الأفق غربًا ────
  DayKeyframe(
    hour: 18.75,
    label: 'غروب',
    spec: PhaseSpec(
      skyColor: 0x2A2A46,
      fogColor: 0x4A3E38,
      ambient: 0x8A7060,
      ambientIntensity: 0.52,
      sun: 0xFF9E5E,
      sunIntensity: 0.85,
      fill: 0x4A6B3C,
      fillIntensity: 0.30,
      lightPos: [-30, 16, 55],
      sunPos: [-35, 10, -95],
      core: 0xFFD9A0,
      corona: 0xFF8A4A,
      cloud: 0xE8C0A8,
      starOpacity: 0.06,
    ),
  ),

  // ── ٢٠:٣٠ غسق: كحلي بنفسجي خفيف + القمر يطلع شرقًا والنجوم تعود ─────────
  DayKeyframe(
    hour: 20.5,
    label: 'غسق',
    spec: PhaseSpec(
      skyColor: 0x101F33,
      fogColor: 0x14262E,
      ambient: 0x30565E,
      ambientIntensity: 0.40,
      sun: 0xC8D6F0,
      sunIntensity: 0.48,
      fill: 0x1F5A2C,
      fillIntensity: 0.24,
      lightPos: [40, 16, 55],
      sunPos: [95, -25, -70],
      core: 0xE6EEFF,
      corona: 0xA8C4E8,
      cloud: 0x9AA6A0,
      starOpacity: 0.62,
    ),
  ),
];

/// فهرس المحطة الجارية في الساعة المعطاة (المحطة الأخيرة التي بدأت).
int periodIndexAtHour(double hour) {
  final double h = _wrapHour(hour);
  int idx = dayCycle.length - 1;
  for (int i = 0; i < dayCycle.length; i++) {
    if (dayCycle[i].hour <= h) idx = i;
  }
  return idx;
}

/// اسم الفترة الجارية (يُعرض على زر التبديل في الوضع التلقائي).
String periodLabelAtHour(double hour) =>
    dayCycle[periodIndexAtHour(hour)].label;

/// لوحة الإضاءة الدقيقة لأي ساعة على مدار اليوم (استيفاء بين محطتين).
PhaseSpec specAtHour(double hour) {
  final double h = _wrapHour(hour);
  final int i = periodIndexAtHour(h);
  final DayKeyframe cur = dayCycle[i];
  final DayKeyframe next = dayCycle[(i + 1) % dayCycle.length];

  final double start = cur.hour;
  double end = next.hour;
  if (end <= start) end += 24.0;

  double hh = h;
  if (hh < start) hh += 24.0;

  final double span = end - start;
  if (span <= 0) return cur.spec;
  final double t = ((hh - start) / span).clamp(0.0, 1.0);
  return lerpSpec(cur.spec, next.spec, t);
}

/// لوحة الوضع المطلوب (تلقائي = حسب [hour]).
PhaseSpec specForMode(DayLightMode mode, double hour) =>
    specAtHour(mode.fixedHour ?? hour);

/// الطور التقريبي للساعة (لأيقونة الزر ولونه فقط).
DayLightMode modeAtHour(double hour) {
  final double h = _wrapHour(hour);
  if (h >= 4.0 && h < 8.75) return DayLightMode.dawn;
  if (h >= 8.75 && h < 17.5) return DayLightMode.noon;
  return DayLightMode.night;
}

/// استيفاء خطي بين لوحتين — يُستخدم في محرك اليوم وفي انسياب التبديل اليدوي.
PhaseSpec lerpSpec(PhaseSpec a, PhaseSpec b, double t) {
  if (t <= 0.0) return a;
  if (t >= 1.0) return b;
  return PhaseSpec(
    skyColor: _lerpHex(a.skyColor, b.skyColor, t),
    fogColor: _lerpHex(a.fogColor, b.fogColor, t),
    ambient: _lerpHex(a.ambient, b.ambient, t),
    ambientIntensity: _lerpD(a.ambientIntensity, b.ambientIntensity, t),
    sun: _lerpHex(a.sun, b.sun, t),
    sunIntensity: _lerpD(a.sunIntensity, b.sunIntensity, t),
    fill: _lerpHex(a.fill, b.fill, t),
    fillIntensity: _lerpD(a.fillIntensity, b.fillIntensity, t),
    lightPos: _lerp3(a.lightPos, b.lightPos, t),
    sunPos: _lerp3(a.sunPos, b.sunPos, t),
    core: _lerpHex(a.core, b.core, t),
    corona: _lerpHex(a.corona, b.corona, t),
    cloud: _lerpHex(a.cloud, b.cloud, t),
    starOpacity: _lerpD(a.starOpacity, b.starOpacity, t),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// أدوات داخلية
// ─────────────────────────────────────────────────────────────────────────────

/// يحصر الساعة في المدى 0 ← 24.
double _wrapHour(double hour) {
  double h = hour % 24.0;
  if (h < 0) h += 24.0;
  return h;
}

double _lerpD(double a, double b, double t) => a + (b - a) * t;

List<double> _lerp3(List<double> a, List<double> b, double t) => [
  _lerpD(a[0], b[0], t),
  _lerpD(a[1], b[1], t),
  _lerpD(a[2], b[2], t),
];

int _lerpHex(int a, int b, double t) {
  final int ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
  final int br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
  final int r = (ar + (br - ar) * t).round();
  final int g = (ag + (bg - ag) * t).round();
  final int bl = (ab + (bb - ab) * t).round();
  return (r << 16) | (g << 8) | bl;
}

/// إعدادات حقل النجوم (يظهر في اللحظات التي `starOpacity > 0`).
class StarFieldSpec {
  const StarFieldSpec({
    required this.count,
    required this.size,
    required this.haloSize,
    required this.haloColor,
    required this.haloOpacityRatio,
    required this.twinkleBase,
    required this.twinkleAmplitude,
    required this.twinkleSpeed,
  });

  /// عدد النجوم.
  final int count;

  /// حجم النجمة الحادّة بالبكسل.
  final double size;

  /// حجم هالة التوهّج حول كل نجمة.
  final double haloSize;

  /// لون الهالة.
  final int haloColor;

  /// نسبة عتامة الهالة من عتامة اللحظة (0.26 = هالة خفيفة).
  final double haloOpacityRatio;

  /// نبض التلألؤ: الأساس + السعة × sin(الإطار × السرعة).
  final double twinkleBase;
  final double twinkleAmplitude;
  final double twinkleSpeed;
}

/// إعدادات النجوم المعتمدة (متوهّجة وكثيفة).
const StarFieldSpec starField = StarFieldSpec(
  count: 1100,
  size: 3.4,
  haloSize: 9.0,
  haloColor: 0xCFE2FF,
  haloOpacityRatio: 0.26,
  twinkleBase: 0.82,
  twinkleAmplitude: 0.18,
  twinkleSpeed: 0.05,
);
