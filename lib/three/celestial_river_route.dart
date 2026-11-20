import 'dart:math' as math;

// =============================================================================
// 🌊 النهر السماوي — مصدر الحقيقة الوحيد للمسار
// =============================================================================
//
// كل رقم هنا **مقيس** من هندسة الجزيرة الفعلية (مصفوفات `nature_layout`
// بعد تصغير `_kNatureScale` في الشاشة) لا مقدَّرًا: خط المنتصف يمرّ على
// بلاطات المرج بخلوص ≥ ٢٫٤، وبلاطات المسار (المخاضات) تعبره في أربعة
// مواضع، والمصبّان يصلان إلى حدّ ماء البحيرتين بالحساب لا بالتقدير.
//
// المسار: من قدم شلال M15 عند (−1.55، −36.10) — حيث ينتهي سطح الصخر
// المقيس — ثم غربًا وجنوبًا حتى حافة الجزيرة عند (30، 82) حيث يهبط
// شلال الحافة. الطول ١٥٠٫٩٤ وحدة.

/// نقاط تحكّم المسار (x، z) — يُمرَّر عليها Catmull-Rom.
///
/// النقطة الأولى **قدم الشلال** لا نقطة اعتباطية: أول قياس جعل البداية
/// (−1.6، −31.2) فكان النهر يبدأ بعد ٥ وحدات من الشلال ويحتاج وصلة
/// بزاوية ٩٠° تنثني فيها حافة الشريط على نفسها. البدء عند القدم جعل
/// الانحناء كله في المقطع الأول (عشر وحدات) فلم يبقَ أي انثناء حاد.
const List<List<double>> kCelestialRiverControlPoints = <List<double>>[
  <double>[-1.55, -36.10],
  <double>[-9.0, -29.0],
  <double>[-16.0, -23.0],
  <double>[-20.5, -13.0],
  <double>[-21.2, -4.8],
  <double>[-20.0, 8.0],
  <double>[-18.0, 20.8],
  <double>[-15.5, 34.0],
  <double>[-13.9, 46.9],
  <double>[-13.2, 54.0],
  <double>[-9.0, 61.0],
  <double>[-4.3, 64.8],
  <double>[5.0, 69.5],
  <double>[16.0, 75.0],
  <double>[25.0, 79.0],
  <double>[30.0, 82.0],
];

/// عدد مقاطع Catmull-Rom لكل ضلع من نقاط التحكّم.
const int kCelestialRiverSubdivisions = 60;

/// تباعد العيّنات على خط المنتصف (وحدة عالمية).
const double kCelestialRiverSampleStep = 0.35;

// --- مناسيب الماء -----------------------------------------------------------------

/// سطح الماء. أعلى من أرض المرج (‑٠٫٠٤) بـ٠٫٣، ولهذا يحتاج النهر جدارًا
/// يحتويه في كل طوله، وهو ما يجعله يُقرأ **قناة جنّة** مرصوفة لا جدولًا
/// محفورًا في العشب.
const double kCelestialRiverWaterY = 0.26;

/// شريط الحافة المبلَّلة بين الماء والجدار (أغمق قليلًا، يخفي حدّ البلاطة).
const double kCelestialRiverBedY = 0.22;

/// أعلى الجدار الحجري.
const double kCelestialRiverKerbTopY = 0.40;

/// أسفل تنّورة الجدار التي تُغرزه في المرج فلا يظهر فراغ تحته.
///
/// **−٠٫٨٥ لا −٠٫٠٦**: المرج ≈ −٠٫٠٤ لكن حوض البحيرتين ينزل إلى −٠٫٤/−٠٫٦
/// (مقيس 2026-11-19)، وقدم عند −٠٫٠٦ كان يترك الجدار معلّقًا فوق الحوض عند
/// المصبّين. الجزء الزائد من الجدار مدفون حيث الأرض أعلى، فلا يُرى.
const double kCelestialRiverKerbFootY = -0.85;

/// نصف عرض الماء (العرض الكلي ٣٫٢).
const double kCelestialRiverHalfWidth = 1.60;

/// نصف عرض الماء عند القدم: أوسع قليلًا ليبتلع وصلة الشلال.
const double kCelestialRiverHeadHalfWidth = 2.35;

/// امتداد شريط الحافة المبلَّلة خارج حدّ الماء.
const double kCelestialRiverBedEdge = 0.35;

/// امتداد أعلى الجدار وقدمه خارج حدّ الماء.
const double kCelestialRiverKerbTopEdge = 0.85;
const double kCelestialRiverKerbFootEdge = 1.02;

/// خلوص الزرع عن خط المنتصف: حدّ الماء ١٫٦ + الجدار ٠٫٨٥ + هامش الزرع ١٫٠.
const double kCelestialRiverPlantClearance = 3.45;

/// طول جدار يُخمَد فيه ارتفاع الجدار عند الطرفين (يغرق في الصخر/المرج).
const double kCelestialRiverKerbFade = 1.8;

// --- المخاضات ---------------------------------------------------------------------

/// أربع بلاطات مسار تعبر النهر — `[s، x، z]` من `kNatureInstances` (شبكة ١٠).
///
/// `s` هو أقرب طول على المسار إلى مركز البلاطة، و`x`/`z` مركزها. توضع
/// عليها حجارة العبور، وإلا انقطع الممرّ عند الماء في منتصف الجزيرة.
const List<List<double>> kCelestialFords = <List<double>>[
  <double>[11.25, -8.71, -27.18],
  <double>[64.75, -17.28, 20.82],
  <double>[98.00, -13.96, 54.01],
  <double>[112.50, -4.31, 64.78],
];

// --- المصبّان ---------------------------------------------------------------------

/// مصبّان جانبيان يصلان النهر بالبحيرتين — `[s، فهرس البحيرة في kNatureLakes]`.
///
/// المسافة إلى حدّ الضفة وحدّ الماء **تُحسب** في `CelestialRiverRoute`
/// بتقاطع شعاع مع دائرة البحيرة، فلا تُكتب أرقام مكرَّرة تنحرف عن
/// `nature_layout` عند أي تعديل.
const List<List<double>> kCelestialInlets = <List<double>>[
  <double>[91.20, 0],
  <double>[31.60, 1],
];

/// عرض قناة المصبّ ونصف عمقها في وسطها.
const double kCelestialInletHalfWidth = 0.62;
const double kCelestialInletEdgeDrop = 0.20;

// --- شلال M15 ---------------------------------------------------------------------

/// أعمدة جدول الشلال (x) — خمسة أعمدة على وجه الصخر.
const List<double> kCelestialFallColumns = <double>[
  -3.1,
  -2.4,
  -1.7,
  -1.0,
  -0.3,
];

/// سطح الشلال: كل صف `[z، y عند الأعمدة الخمسة]`.
///
/// **القياس** (2026-11-19): أشعة عمودية من y=90 على مجسّمات الجبال
/// الجنوبية الخمسة بعد تطبيق `_kNatureScale = 0.80` عليها، ثم أُضيف ٠٫٢٢
/// خلوصًا فوق أعلى سطح. الارتفاع الأول ٩٫٤٢ عند z = −44.5 والقدم ٠٫٢٦
/// عند z = −36.0 — أي هبوط ٩٫٢ على مسافة ٨٫٥ أفقية (≈٤٧°). لا تُعدَّل
/// قيمة هنا بلا إعادة القياس بنفس السكربت، وإلا دُفن الشلال في الصخر
/// أو طار فوقه.
const List<List<double>> kCelestialFallProfile = <List<double>>[
  <double>[-44.5, 8.97, 9.23, 9.42, 9.28, 8.75],
  <double>[-44.0, 8.32, 8.49, 8.69, 8.68, 8.14],
  <double>[-43.5, 8.00, 8.10, 8.47, 8.16, 7.36],
  <double>[-43.0, 7.76, 7.84, 8.22, 7.59, 6.79],
  <double>[-42.5, 7.34, 7.19, 7.34, 6.89, 6.45],
  <double>[-42.0, 6.70, 6.39, 6.11, 6.27, 5.96],
  <double>[-41.5, 6.14, 5.77, 5.42, 5.30, 5.21],
  <double>[-41.0, 5.71, 5.42, 5.03, 4.80, 4.73],
  <double>[-40.5, 5.31, 5.04, 4.76, 4.44, 3.43],
  <double>[-40.0, 4.90, 4.78, 4.42, 3.35, 3.10],
  <double>[-39.5, 4.47, 4.29, 3.97, 3.01, 2.78],
  <double>[-39.0, 3.25, 3.07, 2.93, 2.71, 2.41],
  <double>[-38.5, 2.95, 2.69, 2.56, 2.47, 2.04],
  <double>[-38.0, 2.69, 2.37, 2.23, 2.17, 1.70],
  <double>[-37.5, 2.40, 2.06, 1.98, 1.93, 1.35],
  <double>[-37.0, 2.09, 1.76, 1.66, 1.40, 0.87],
  <double>[-36.5, 1.46, 1.20, 0.91, 0.62, 0.35],
  <double>[-36.0, 0.69, 0.52, 0.26, 0.26, 0.26],
];

/// أدنى ارتفاع يسمح به للشلال: سطح الماء نفسه، وإلا ظهر الشلال مقصوصًا.
const double kCelestialFallMinY = 0.24;

/// قدم الشلال: حيث يبدأ شريط النهر.
const List<double> kCelestialFallFoot = <double>[-1.55, -36.05];

/// نصف قطر بركة الاستقبال عند القدم (تدفن وصلة الشلال بالنهر).
const double kCelestialFallPlungeRadius = 2.10;

// --- شلال الحافة ------------------------------------------------------------------

/// `[z، y، نصف العرض]` عند x = 30 — شريط الحافة يهبط عن الجزيرة.
///
/// الحافة الأولى للقشرة عند 1.004 من المحيط (y = −0.30) والثانية عند
/// 1.030 (y = −0.55)، فالهبوط يمرّ بهما ثم ينطلق في الفراغ.
const List<List<double>> kCelestialEdgeFall = <List<double>>[
  <double>[82.0, 0.26, 1.60],
  <double>[84.9, -0.55, 1.70],
  <double>[85.7, -5.00, 1.90],
  <double>[86.6, -12.00, 2.10],
];

// --- الإزاحات المعتمدة -----------------------------------------------------------

/// ثلاثة مجسّمات طبيعية كانت تقف في مجرى الماء — `[شبكة، fromX، fromZ، toX، toZ]`.
///
/// المطابقة بـ(الشبكة + الإحداثي) لا بفهرس الصف: `kNatureInstances` مولَّد
/// فلا يُحرَّر يدويًا، وفهرس الصف يتغيّر مع كل توليد. الإزاحات ٢–٤ وحدات
/// وكلها تُبقي خلوصًا ≥ ٣٫٦ عن خط المنتصف.
const List<List<double>> kCelestialPropShifts = <List<double>>[
  // birch_a — كانت في الماء عند s ≈ ١١
  <double>[0, -11.9485, -28.5308, -14.03, -29.92],
  // birch_b — كانت في الماء عند قدم الشلال
  <double>[1, 0.4800, -36.6400, 1.51, -32.77],
  // grass_b — كانت في الجدار عند s ≈ ١٧
  <double>[5, -14.4878, -27.1526, -16.34, -27.92],
];

/// جيودان بلوريان (من صنعنا، ليسا في جدول الطبيعة) كانا على المسار —
/// `[fromX، fromZ، toX، toZ]`. يُنقلان غربًا ٥ وحدات ولا يُحذفان.
const List<List<double>> kCelestialGeodeShifts = <List<double>>[
  <double>[-18.5, 16.0, -23.60, 15.0],
  <double>[-14.0, 36.0, -20.00, 36.0],
];

// =============================================================================
// المسار المحسوب
// =============================================================================

/// عيّنة على خط منتصف النهر: الموضع والمماس والناظم عند طول [s].
class CelestialRiverSample {
  const CelestialRiverSample({
    required this.s,
    required this.x,
    required this.z,
    required this.tx,
    required this.tz,
    required this.nx,
    required this.nz,
  });

  /// الطول المتراكم من قدم الشلال.
  final double s;
  final double x;
  final double z;

  /// المماس (اتجاه الجريان) — وحدة.
  final double tx;
  final double tz;

  /// الناظم الأفقي (المماس مُدارًا ٩٠°)، يشير إلى «يسار» الجريان.
  final double nx;
  final double nz;

  /// نقطة على بعد [offset] من خط المنتصف في اتجاه الناظم.
  List<double> offset(double offset) => <double>[
    x + nx * offset,
    z + nz * offset,
  ];
}

/// منحنى النهر: عيّنات موزّعة على الطول + استعلام أقرب نقطة.
class CelestialRiverRoute {
  CelestialRiverRoute._(this.samples);

  final List<CelestialRiverSample> samples;

  double get length => samples.last.s;

  /// يبني المسار من نقاط التحكّم: Catmull-Rom ثم إعادة توزيع على الطول.
  factory CelestialRiverRoute.build() {
    final dense = <List<double>>[];
    final cp = kCelestialRiverControlPoints;
    for (var i = 0; i < cp.length - 1; i++) {
      final p0 = i > 0 ? cp[i - 1] : cp[0];
      final p1 = cp[i];
      final p2 = cp[i + 1];
      final p3 = i + 2 < cp.length ? cp[i + 2] : cp[cp.length - 1];
      for (var k = 0; k < kCelestialRiverSubdivisions; k++) {
        dense.add(_catmullRom(p0, p1, p2, p3, k / kCelestialRiverSubdivisions));
      }
    }
    dense.add(<double>[cp.last[0], cp.last[1]]);

    final cumulative = <double>[0.0];
    for (var i = 1; i < dense.length; i++) {
      cumulative.add(
        cumulative[i - 1] +
            math.sqrt(
              math.pow(dense[i][0] - dense[i - 1][0], 2) +
                  math.pow(dense[i][1] - dense[i - 1][1], 2),
            ),
      );
    }
    final total = cumulative.last;

    final steps = math.max(2, (total / kCelestialRiverSampleStep).ceil());
    final samples = <CelestialRiverSample>[];
    var cursor = 1;
    for (var k = 0; k <= steps; k++) {
      final s = total * k / steps;
      while (cursor < cumulative.length - 1 && cumulative[cursor] < s) {
        cursor++;
      }
      final i = cursor;
      final span = cumulative[i] - cumulative[i - 1];
      final t = span <= 0 ? 0.0 : (s - cumulative[i - 1]) / span;
      final x = dense[i - 1][0] + (dense[i][0] - dense[i - 1][0]) * t;
      final z = dense[i - 1][1] + (dense[i][1] - dense[i - 1][1]) * t;
      var dx = dense[i][0] - dense[i - 1][0];
      var dz = dense[i][1] - dense[i - 1][1];
      final norm = math.sqrt(dx * dx + dz * dz);
      if (norm > 0) {
        dx /= norm;
        dz /= norm;
      }
      samples.add(
        CelestialRiverSample(s: s, x: x, z: z, tx: dx, tz: dz, nx: dz, nz: -dx),
      );
    }
    return CelestialRiverRoute._(samples);
  }

  static List<double> _catmullRom(
    List<double> p0,
    List<double> p1,
    List<double> p2,
    List<double> p3,
    double t,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;
    double axis(int i) =>
        0.5 *
        (2 * p1[i] +
            (-p0[i] + p2[i]) * t +
            (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * t2 +
            (-p0[i] + 3 * p1[i] - 3 * p2[i] + p3[i]) * t3);
    return <double>[axis(0), axis(1)];
  }

  /// العيّنة عند الطول [s] (مشبوكة، بلا استيفاء).
  CelestialRiverSample at(double s) {
    final ratio = (s / length).clamp(0.0, 1.0);
    final index = (ratio * (samples.length - 1)).round();
    return samples[index];
  }

  /// نصف عرض الماء عند [s] — أوسع عند قدم الشلال ليشمل بركة الاستقبال.
  double halfWidthAt(double s) {
    final t = (s / 6.0).clamp(0.0, 1.0);
    final k = (1.0 - t) * (1.0 - t);
    return kCelestialRiverHalfWidth +
        (kCelestialRiverHeadHalfWidth - kCelestialRiverHalfWidth) * k;
  }

  /// معامل ارتفاع الجدار: ٠ عند الطرفين (يغرق) و١ في الوسط.
  double kerbFactorAt(double s) {
    final head = (s / kCelestialRiverKerbFade).clamp(0.0, 1.0);
    final tail = ((length - s) / kCelestialRiverKerbFade).clamp(0.0, 1.0);
    return math.min(head, tail);
  }

  /// أقرب مسافة أفقية من ([x]، [z]) إلى خط المنتصف.
  double distanceTo(double x, double z) {
    var best = double.infinity;
    for (final sample in samples) {
      final dx = sample.x - x;
      final dz = sample.z - z;
      final d = dx * dx + dz * dz;
      if (d < best) best = d;
    }
    return math.sqrt(best);
  }
}

/// المسار المحسوب مرة واحدة عند أول استعمال.
final CelestialRiverRoute kCelestialRiverRoute = CelestialRiverRoute.build();
