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
}
