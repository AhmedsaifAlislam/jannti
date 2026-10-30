import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/three/day_palette.dart';

/// 🧪 اختبارات محرك دورة إضاءة اليوم (`lib/three/day_palette.dart`).
///
/// الهدف: ضمان أن الانتقال بين المحطات **متّصل بلا قفزات**، وأن مظهر
/// الظهيرة الأصلي لم يتغيّر إطلاقًا، وأن النجوم تتلاشى/تظهر تدريجيًا.
void main() {
  group('دورة اليوم', () {
    test('٨ محطات مرتّبة تصاعديًا داخل مدار ٢٤ ساعة', () {
      expect(dayCycle.length, 8);
      for (int i = 0; i < dayCycle.length; i++) {
        final double h = dayCycle[i].hour;
        expect(h, greaterThanOrEqualTo(0.0));
        expect(h, lessThan(24.0));
        if (i > 0) {
          expect(h, greaterThan(dayCycle[i - 1].hour), reason: 'ترتيب المحطات');
        }
        expect(dayCycle[i].label, isNotEmpty);
      }
    });

    test('الظهيرة (١٢:٣٠) = المظهر الأصلي بلا أي تغيير', () {
      final PhaseSpec s = specAtHour(12.5);
      expect(s.skyColor, 0x134C37);
      expect(s.fogColor, 0x134C37);
      expect(s.ambient, 0x4A6B56);
      expect(s.ambientIntensity, 0.55);
      expect(s.sun, 0xFFE082);
      expect(s.sunIntensity, 1.35);
      expect(s.fill, 0x388E3C);
      expect(s.fillIntensity, 0.40);
      expect(s.lightPos, [55, 90, 45]);
      expect(s.sunPos, [50, 90, -90]);
      expect(s.core, 0xFFFDF0);
      expect(s.corona, 0xFFE082);
      expect(s.cloud, 0xFFFAF0);
      expect(s.starOpacity, 0.0);
    });

    test('الليل كحلي والنجوم كاملة', () {
      final PhaseSpec s = specAtHour(0.5);
      expect(s.skyColor, 0x0C2138);
      // درجة الكحلي: الأزرق هو القناة الغالبة
      final int r = (s.skyColor >> 16) & 0xFF;
      final int b = s.skyColor & 0xFF;
      expect(b, greaterThan(r), reason: 'السماء ليلًا يجب أن تميل للأزرق');
      expect(s.starOpacity, 1.0);
      // القمر فوق الأفق ليلًا
      expect(s.sunPos[1], greaterThan(0.0));
    });

    test('النجوم متلاشية نهارًا وتظهر تدريجيًا عند الغسق', () {
      expect(specAtHour(9.0).starOpacity, 0.0);
      expect(specAtHour(12.0).starOpacity, 0.0);
      expect(specAtHour(15.0).starOpacity, 0.0);
      final double dusk = specAtHour(19.5).starOpacity;
      final double lateDusk = specAtHour(21.5).starOpacity;
      expect(dusk, greaterThan(0.0));
      expect(dusk, lessThan(lateDusk));
      expect(lateDusk, lessThanOrEqualTo(1.0));
    });

    test('القرص تحت الأفق في الفجر والغسق (شروق/غروب طبيعي)', () {
      expect(specAtHour(5.25).sunPos[1], lessThan(0.0), reason: 'القمر غرب');
      expect(specAtHour(20.5).sunPos[1], lessThan(0.0), reason: 'القمر شرق');
      // والشمس مرتفعة بينهما
      expect(specAtHour(6.25).sunPos[1], greaterThan(0.0));
      expect(specAtHour(18.75).sunPos[1], greaterThan(0.0));
    });

    test('التدوير على مدار ٢٤ ساعة متّصل (لا قفزة عند منتصف الليل)', () {
      expect(specAtHour(24.5).skyColor, specAtHour(0.5).skyColor);
      expect(specAtHour(-1.5).skyColor, specAtHour(22.5).skyColor);
      // لحظتان متجاورتان حول منتصف الليل لا تفترقان (لكل قناة لونية)
      final PhaseSpec before = specAtHour(23.999);
      final PhaseSpec after = specAtHour(0.001);
      for (final int shift in [16, 8, 0]) {
        final int c1 = (before.skyColor >> shift) & 0xFF;
        final int c2 = (after.skyColor >> shift) & 0xFF;
        expect((c1 - c2).abs(), lessThanOrEqualTo(2), reason: 'shift $shift');
      }
      expect((before.starOpacity - after.starOpacity).abs(), lessThan(0.01));
    });
  });

  group('الاستيفاء', () {
    test('كل عيّنة على مدار اليوم متّصلة بلا قفزات', () {
      const double step = 0.01;
      PhaseSpec? prev;
      for (double h = 0.0; h <= 24.0; h += step) {
        final PhaseSpec s = specAtHour(h);
        if (prev != null) {
          for (int i = 0; i < 3; i++) {
            expect(
              (s.lightPos[i] - prev.lightPos[i]).abs(),
              lessThan(4.0),
              reason: 'موضع الإضاءة عند الساعة $h',
            );
            expect(
              (s.sunPos[i] - prev.sunPos[i]).abs(),
              lessThan(4.0),
              reason: 'موضع القرص عند الساعة $h',
            );
          }
          expect(
            (s.starOpacity - prev.starOpacity).abs(),
            lessThan(0.02),
            reason: 'عتامة النجوم عند الساعة $h',
          );
        }
        prev = s;
      }
    });

    test('قنوات الألوان تتحرّك بسلاسة (كل قناة على حدة)', () {
      const double step = 0.02;
      int? prevR, prevG, prevB;
      for (double h = 0.0; h <= 24.0; h += step) {
        final int c = specAtHour(h).skyColor;
        final int r = (c >> 16) & 0xFF;
        final int g = (c >> 8) & 0xFF;
        final int b = c & 0xFF;
        if (prevR != null) {
          expect((r - prevR).abs(), lessThanOrEqualTo(2), reason: 'r عند $h');
          expect((g - prevG!).abs(), lessThanOrEqualTo(2), reason: 'g عند $h');
          expect((b - prevB!).abs(), lessThanOrEqualTo(2), reason: 'b عند $h');
        }
        prevR = r;
        prevG = g;
        prevB = b;
      }
    });

    test('lerpSpec يعطي الطرفين بالضبط', () {
      final PhaseSpec a = specAtHour(0.5);
      final PhaseSpec b = specAtHour(12.5);
      expect(lerpSpec(a, b, 0.0).skyColor, a.skyColor);
      expect(lerpSpec(a, b, 1.0).skyColor, b.skyColor);
      expect(
        lerpSpec(a, b, 0.5).starOpacity,
        (a.starOpacity + b.starOpacity) / 2,
      );
    });
  });

  group('الوضع والزر', () {
    test('الأوضاع الثابتة تُطابق محطاتها على الدورة', () {
      for (final DayLightMode m in DayLightMode.values) {
        if (m.isAuto) {
          expect(m.fixedHour, isNull);
          continue;
        }
        final double h = m.fixedHour!;
        expect(
          specForMode(m, 3.0).skyColor,
          specAtHour(h).skyColor,
          reason: '${m.label} يجب أن تتبع الساعة ${m.fixedHour}',
        );
      }
    });

    test('الوضع التلقائي يتبع الساعة المعطاة', () {
      expect(
        specForMode(DayLightMode.auto, 12.5).skyColor,
        specAtHour(12.5).skyColor,
      );
      expect(
        specForMode(DayLightMode.auto, 0.5).skyColor,
        specAtHour(0.5).skyColor,
      );
    });

    test('أسماء الفترات وأطوار الساعة منطقية', () {
      expect(periodLabelAtHour(0.5), 'ليل');
      expect(periodLabelAtHour(12.5), 'ظهيرة');
      expect(periodLabelAtHour(23.0), 'غسق');
      expect(periodLabelAtHour(6.0), 'فجر');
      expect(modeAtHour(6.0), DayLightMode.dawn);
      expect(modeAtHour(13.0), DayLightMode.noon);
      expect(modeAtHour(1.0), DayLightMode.night);
      expect(modeAtHour(21.0), DayLightMode.night);
    });

    test('إعدادات النجوم سليمة', () {
      expect(starField.count, greaterThan(0));
      expect(starField.size, greaterThan(0));
      expect(starField.haloSize, greaterThan(starField.size));
      expect(starField.haloOpacityRatio, inInclusiveRange(0.0, 1.0));
      expect(kManualTransitionSeconds, greaterThan(0));
      expect(kAutoRefreshFrames, greaterThan(0));
    });
  });
}
