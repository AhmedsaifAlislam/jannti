import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/widgets/paradise_loader.dart';

void main() {
  group('أطوار نمو الجزيرة', () {
    test('العتبات تقابل الوحدات الست للحاجب', () {
      expect(paradiseStageFor(0.0), ParadiseStage.soil);
      expect(paradiseStageFor(0.01), ParadiseStage.mountains);
      expect(paradiseStageFor(0.33), ParadiseStage.water);
      expect(paradiseStageFor(0.66), ParadiseStage.palms);
      expect(paradiseStageFor(1.0), ParadiseStage.ready);
    });

    test('الطور لا يتقهقر مع زيادة التقدّم', () {
      var last = paradiseStageFor(0.0).index;
      for (var i = 0; i <= 100; i++) {
        final current = paradiseStageFor(i / 100).index;
        expect(
          current,
          greaterThanOrEqualTo(last),
          reason: 'تقهقر عند ${i / 100}',
        );
        last = current;
      }
    });

    test('التقدّم خارج ٠..١ يُقصّ بلا رمي', () {
      expect(paradiseStageFor(-1.0), ParadiseStage.soil);
      expect(paradiseStageFor(2.0), ParadiseStage.ready);
      expect(paradiseStageFor(double.nan), ParadiseStage.soil);
    });

    test('كل طور له نص غير فارغ', () {
      for (final stage in ParadiseStage.values) {
        expect(stage.label.trim(), isNotEmpty);
      }
      expect(ParadiseStage.ready.label, contains('اكتملت'));
    });
  });

  group('ودجت الحاجب', () {
    testWidgets('يرسم ويتحرك بلا استثناء', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ParadiseLoader(progress: 0.5))),
        ),
      );
      // النبضة `repeat` لا تستقر أبدًا، فالتحقق بـ`pump` لا `pumpAndSettle`.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(ParadiseLoader), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('التقدّم الكامل لا يرمي', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ParadiseLoader(progress: 1.0))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
