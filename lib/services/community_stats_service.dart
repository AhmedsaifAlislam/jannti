import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 🌿 خدمة عدد المستخدمين النشطين (Social Proof).
/// رقم أساس يتحكّم به المالك عن بُعد عبر version.json، مع انحراف عضوي خلال
/// الدقيقة لا يبدو مزيّفًا. كشف الرقم الحقيقي بضغط خفي (5 ضغطات).
class CommunityStatsService {
  static final CommunityStatsService _instance =
      CommunityStatsService._internal();
  factory CommunityStatsService() => _instance;
  CommunityStatsService._internal();

  static const int _defaultBase =
      14200; // القيمة الافتراضية قبل التهيئة عن بُعد

  int _base = _defaultBase;
  bool _enabled = true;
  int _growthPerDay = 0;
  DateTime? _configuredAt;

  Timer? _ticker;
  Timer? _revealTimer;

  final ValueNotifier<int> _displayed = ValueNotifier<int>(_defaultBase);
  ValueNotifier<int> get displayed => _displayed;

  final ValueNotifier<bool> _reveal = ValueNotifier<bool>(false);
  ValueNotifier<bool> get reveal => _reveal;

  bool get enabled => _enabled;

  /// الرقم «الحقيقي» الحالي (قاعدة + نمو يومي إن وُجد).
  int get trueBase {
    if (_growthPerDay == 0 || _configuredAt == null) return _base;
    final days = DateTime.now().difference(_configuredAt!).inDays;
    return _base + days * _growthPerDay;
  }

  /// تُستدعى من AppUpdateService بعد جلب version.json.
  void configure({int? base, bool? enabled, int? growthPerDay}) {
    if (base != null && base > 0) {
      _base = base;
      _configuredAt = DateTime.now();
    }
    if (enabled != null) _enabled = enabled;
    if (growthPerDay != null && growthPerDay >= 0) _growthPerDay = growthPerDay;
    _displayed.value = trueBase;
  }

  /// بدء المؤقّت الذي يُحدّث الرقم المعروض كل ثانيتين.
  void start() {
    _ticker?.cancel();
    if (!_enabled) return;
    _displayed.value = computeDisplayed(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      _displayed.value = computeDisplayed(DateTime.now());
    });
  }

  /// إيقاف المؤقّت (يُستدعى في dispose).
  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// كشف الرقم الحقيقي لثوانٍ (يُستدعى بالضغط الخفي).
  void revealTrueNumber() {
    _reveal.value = true;
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 4), () {
      _reveal.value = false;
    });
  }

  /// الرقم المعروض في لحظة [now]:
  /// - الثانية 0..5 : الرقم الحقيقي (بدون انحراف).
  /// - الثانية 5..60: انحراف سلس صعودًا وهبوطًا يعود للأصل بنهاية الدقيقة.
  int computeDisplayed(DateTime now) {
    final base = trueBase;
    final sec = now.second;

    if (sec < 5) return base; // أول 5 ثوانٍ = الرقم الحقيقي

    final u = ((sec - 5) / 55.0).clamp(
      0.0,
      1.0,
    ); // 0 عند الثانية 5 → 1 قرب الثانية 60

    // بذرة حتمية ثابتة خلال الدقيقة الواحدة (لا تشويش عشوائي مرئي).
    final seed =
        now.year * 100000000 +
        now.month * 1000000 +
        now.day * 10000 +
        now.hour * 100 +
        now.minute;
    final rng = Random(seed);

    // سعة الانحراف ~2% من الأساس مع تنويع طفيف لكل دقيقة.
    final amplitude = base * 0.02 * (0.80 + 0.45 * rng.nextDouble());

    // موجتا جيبيتان: صعود وهبوط طبيعي، والأطراف = 0 (لا قفزة عند تغيّر الدقيقة).
    final wave = 0.65 * sin(2 * pi * u) + 0.35 * sin(4 * pi * u);
    final drift = (amplitude * wave).round();

    return base + drift;
  }
}
