import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/services/spiritual_audio_service.dart';
import 'package:jannti/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبار مزج طبقات الطبيعة في [SpiritualAudioService].
///
/// يتحقق من:
/// - طبقة واحدة تعمل بكامل الجهارة (الافتراضية ٥٠٪).
/// - إضافة طبقة ثانية تخفض السقف إلى الجهارة ÷ √٢.
/// - طبقة واحدة فقط على السقف والباقي أدنى منها بنسب مختلفة.
/// - مجموع الطبقات لا يتجاوز الجهارة.
/// - تبادل البروز: بعد فترة يصعد صوت آخر إلى السقف.
/// - الإيقاف يوقف كل الطبقات.
/// - تتابع المقاطع داخل الطبقة: تبادل ناعم (٦ ثوانٍ) ثم إغلاق المقطع السابق.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.jannti/audio');

  testWidgets('المزيج: السقف والسلّم والتبادل', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService().init();

    // نحاكي الجانب الأصلي ونسجّل جهارة كل مشغّل.
    final played = <String, double>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?) ?? const <String, Object?>{};
          final id = args['id'] as String?;
          final volume = (args['volume'] as num?)?.toDouble();
          if (id != null) {
            switch (call.method) {
              case 'play':
                played[id] = volume ?? 1.0;
              case 'setVolume':
                played[id] = volume ?? 1.0;
              case 'stop':
                played.remove(id);
            }
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = SpiritualAudioService();
    final water = SpiritualAudioService.natureTracks[0];
    final wind = SpiritualAudioService.natureTracks[1];

    // --- طبقة واحدة: السقف = الجهارة (٠٫٥ افتراضيًا) ---
    await service.toggleLayer(water);
    await tester.pump(const Duration(seconds: 6));

    expect(service.isMixPlaying, isTrue);
    expect(service.masterVolume, closeTo(0.5, 0.001));
    expect(played[water.id], closeTo(0.5, 0.01));
    expect(
      service.isLeader(water.id),
      isFalse,
      reason: 'طبقة واحدة لا تُعلَم بارزة',
    );

    // --- طبقة ثانية: السقف = ٠٫٥ ÷ √٢ ---
    await service.toggleLayer(wind);
    await tester.pump(const Duration(seconds: 6));

    final double ceiling = 0.5 / math.sqrt(2);
    final double a = played[water.id] ?? 0;
    final double b = played[wind.id] ?? 0;

    expect(
      math.max(a, b),
      closeTo(ceiling, 0.01),
      reason: 'طبقة واحدة فقط على السقف',
    );
    expect(
      math.min(a, b),
      lessThan(ceiling * 0.95),
      reason: 'الباقي أدنى من السقف',
    );
    expect(
      math.max(a, b),
      lessThanOrEqualTo(0.5),
      reason: 'لا طبقة تتجاوز الجهارة',
    );
    expect(
      math.sqrt(a * a + b * b),
      lessThanOrEqualTo(0.501),
      reason: 'مجموع القدرة لا يتجاوز الجهارة',
    );
    expect(service.isLeader(water.id) != service.isLeader(wind.id), isTrue);

    // --- التبادل: بعد ٢٠–٤٠ ثانية يصعد الصوت الآخر إلى السقف ---
    final leaderId = a > b ? water.id : wind.id;
    final otherId = a > b ? wind.id : water.id;
    var swapped = false;
    for (var step = 0; step < 14; step++) {
      await tester.pump(const Duration(seconds: 5));
      if ((played[otherId] ?? 0) >= ceiling * 0.9) {
        swapped = true;
        break;
      }
    }
    expect(swapped, isTrue, reason: 'لم يتبادل البروز خلال ٧٠ ثانية');
    expect(service.isLeader(otherId), isTrue);
    expect(
      played[leaderId],
      lessThan(ceiling * 0.95),
      reason: 'الرائد السابق هبط',
    );

    // --- إضافة طبقة ثالثة: السقف = ٠٫٥ ÷ √٣ ---
    final birds = SpiritualAudioService.natureTracks[2];
    await service.toggleLayer(birds);
    await tester.pump(const Duration(seconds: 6));
    final ceiling3 = 0.5 / math.sqrt(3);
    final values = [
      played[water.id] ?? 0,
      played[wind.id] ?? 0,
      played[birds.id] ?? 0,
    ];
    expect(values.reduce(math.max), closeTo(ceiling3, 0.01));
    expect(
      math.sqrt(values.fold<double>(0, (s, v) => s + v * v)),
      lessThanOrEqualTo(0.501),
      reason: 'مجموع القدرة لا يتجاوز الجهارة مع ثلاث طبقات',
    );

    // --- الإيقاف: كل المشغّلات تُغلق ---
    await service.stopMix();
    await tester.pump(const Duration(seconds: 1));
    expect(played, isEmpty);
    expect(service.isMixPlaying, isFalse);
    expect(
      service.activeLayers.length,
      3,
      reason: 'الاختيار يبقى محفوظًا بعد الإيقاف',
    );
  });

  testWidgets('تتابع المقاطع: تبادل ناعم داخل الطبقة', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService().init();

    final played = <String, double>{};
    final started = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?) ?? const <String, Object?>{};
          final id = args['id'] as String?;
          final volume = (args['volume'] as num?)?.toDouble();
          if (id != null) {
            switch (call.method) {
              case 'play':
                started[id] = (args['url'] as String?) ?? '';
                played[id] = volume ?? 1.0;
              case 'setVolume':
                played[id] = volume ?? 1.0;
              case 'stop':
                played.remove(id);
                started.remove(id);
            }
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = SpiritualAudioService();
    // تنظيف حالة الاختبار السابق (الخدمة Singleton).
    await service.stopMix();
    for (final track in SpiritualAudioService.natureTracks) {
      if (service.isLayerActive(track.id)) await service.toggleLayer(track);
    }
    played.clear();
    started.clear();

    final water = SpiritualAudioService.natureTracks[0];
    final secondKey = '${water.id}#1';
    expect(water.segments.length, 3, reason: 'الماء ثلاثة مقاطع متتابعة');

    await service.toggleLayer(water);
    await tester.pump(const Duration(seconds: 6));

    expect(started[water.id], water.segments.first.url);
    expect(played[water.id], closeTo(0.5, 0.02));

    // --- قبل نهاية المقطع بـ٦ ثوانٍ يبدأ التبادل ---
    await tester.pump(const Duration(milliseconds: 48600)); // ~٥٤٫٦ ث
    expect(
      played.containsKey(secondKey),
      isTrue,
      reason: 'المقطع التالي بدأ قبل انتهاء الحالي',
    );
    expect(started[secondKey], water.segments[1].url);

    final base = service.layerGain(water.id);
    final out = played[water.id] ?? 0;
    final inn = played[secondKey] ?? 0;
    expect(
      out + inn,
      closeTo(base, 0.03),
      reason: 'منحنى التبادل يحفظ جهارة الطبقة',
    );
    expect(
      out,
      greaterThan(inn),
      reason: 'الخارج ما زال أعلى في بداية التبادل',
    );
    expect(math.max(out, inn), lessThanOrEqualTo(0.501));

    // --- بعد ٦ ثوانٍ يُغلق المقطع السابق ويبقى الجديد ---
    await tester.pump(const Duration(seconds: 6));
    expect(played.containsKey(water.id), isFalse);
    expect(played[secondKey], closeTo(0.5, 0.03));

    // --- الدورة تكتمل: المقطع الثالث يعود إلى الخانة الأولى ---
    await tester.pump(const Duration(seconds: 49)); // ~١٠٩٫٦ ث
    expect(
      played.containsKey(water.id),
      isTrue,
      reason: 'المقطع الثالث يعود إلى الخانة الأساسية',
    );
    expect(started[water.id], water.segments[2].url);
    await tester.pump(const Duration(seconds: 6));
    expect(played.containsKey(secondKey), isFalse);
    expect(played[water.id], closeTo(0.5, 0.03));

    await service.stopMix();
    await tester.pump(const Duration(seconds: 1));
    expect(played, isEmpty);
    expect(started, isEmpty);
  });
}
