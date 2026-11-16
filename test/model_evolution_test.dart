import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/three/model_evolution.dart';

void main() {
  group('modelTierForCount', () {
    test('uses the 100 / 1000 / 5000 / 10000 boundaries', () {
      expect(modelTierForCount(0), 1);
      expect(modelTierForCount(1), 1);
      expect(modelTierForCount(99), 1);
      expect(modelTierForCount(100), 2);
      expect(modelTierForCount(999), 2);
      expect(modelTierForCount(1000), 3);
      expect(modelTierForCount(4999), 3);
      expect(modelTierForCount(5000), 4);
      expect(modelTierForCount(9999), 4);
      expect(modelTierForCount(10000), 5);
      expect(modelTierForCount(99999), 5);
    });
  });

  group('modelStageForCount', () {
    test('grows at the first sub-stage and colours at the second', () {
      const cases = <int, int>{
        1: 0,
        9: 0,
        10: 1,
        24: 1,
        25: 2,
        99: 2,
        100: 0,
        199: 0,
        200: 1,
        499: 1,
        500: 2,
        999: 2,
        1000: 0,
        1999: 0,
        2000: 1,
        2999: 1,
        3000: 2,
        4999: 2,
        5000: 0,
        5999: 0,
        6000: 1,
        7999: 1,
        8000: 2,
        9999: 2,
        10000: 0,
        14999: 0,
        15000: 1,
        19999: 1,
        20000: 2,
      };
      cases.forEach((count, expected) {
        expect(modelStageForCount(count), expected, reason: 'count $count');
      });
    });
  });

  group('modelDisplayCount', () {
    test('shows one seedling per reward before the first block of ten', () {
      expect(modelDisplayCount(0), 0);
      for (var count = 1; count <= 9; count++) {
        expect(modelDisplayCount(count), count);
      }
    });

    test('merges every ten rewards and keeps the remainder as seedlings', () {
      // ١٠ = نموذج واحد مكتمل.
      expect(modelDisplayCount(10), 1);
      // ١١ = النموذج المكتمل + الشتلة الحادية عشرة.
      expect(modelDisplayCount(11), 2);
      expect(modelDisplayCount(19), 10);
      // ٢٠ = الشتلات التسع اندمجت في النموذج الثاني.
      expect(modelDisplayCount(20), 2);
      expect(modelDisplayCount(21), 3);
      expect(modelDisplayCount(25), 7);
      expect(modelDisplayCount(99), 18);
    });

    test('a new tier collapses the type into one model', () {
      expect(modelDisplayCount(100), 1);
      expect(modelDisplayCount(999), 1);
      expect(modelDisplayCount(10000), 1);
    });

    test('modelFullCount counts completed blocks only', () {
      expect(modelFullCount(9), 0);
      expect(modelFullCount(10), 1);
      expect(modelFullCount(19), 1);
      expect(modelFullCount(20), 2);
      expect(modelFullCount(99), 9);
    });

    test('modelIsFull marks the first blocks, seedlings after them', () {
      expect(modelIsFull(11, 0), isTrue);
      expect(modelIsFull(11, 1), isFalse);
      expect(modelIsFull(19, 0), isTrue);
      expect(modelIsFull(19, 9), isFalse);
      expect(modelIsFull(25, 1), isTrue);
      expect(modelIsFull(25, 2), isFalse);
      // فوق المرتبة الأولى النموذج الوحيد مكتمل دائمًا.
      expect(modelIsFull(100, 0), isTrue);
      expect(modelIsFull(10000, 0), isTrue);
    });
  });

  group('modelScaleMultiplier', () {
    test('is 1.0 at the base of every tier', () {
      for (final count in <int>[1, 9, 100, 1000, 5000, 10000]) {
        expect(modelScaleMultiplier(count), 1.0, reason: 'count $count');
      }
    });

    test('adds the documented growth steps', () {
      expect(modelScaleMultiplier(10), closeTo(1.05, 0.0001));
      expect(modelScaleMultiplier(25), closeTo(1.13, 0.0001));
      expect(modelScaleMultiplier(200), closeTo(1.08, 0.0001));
      expect(modelScaleMultiplier(500), closeTo(1.16, 0.0001));
      expect(modelScaleMultiplier(2000), closeTo(1.08, 0.0001));
      expect(modelScaleMultiplier(3000), closeTo(1.16, 0.0001));
      expect(modelScaleMultiplier(6000), closeTo(1.08, 0.0001));
      expect(modelScaleMultiplier(8000), closeTo(1.16, 0.0001));
      expect(modelScaleMultiplier(15000), closeTo(1.08, 0.0001));
      expect(modelScaleMultiplier(20000), closeTo(1.16, 0.0001));
      expect(modelScaleMultiplier(30000), closeTo(1.24, 0.0001));
      expect(modelScaleMultiplier(40000), closeTo(1.25, 0.0001));
    });
  });

  group('modelTintForCount', () {
    test('is null before the second sub-stage', () {
      for (final count in <int>[1, 10, 24, 100, 200, 499, 1000, 2000, 2999]) {
        expect(modelTintForCount(count), isNull, reason: 'count $count');
      }
    });

    test('returns a tint from the second sub-stage onward', () {
      for (final count in <int>[25, 500, 3000, 8000, 20000, 40000]) {
        expect(modelTintForCount(count), isNotNull, reason: 'count $count');
      }
    });
  });

  group('modelScaleForStage / modelTintForStage', () {
    test('match the count-based helpers at every stage boundary', () {
      final counts = <int>[
        1,
        10,
        25,
        100,
        200,
        500,
        1000,
        2000,
        3000,
        5000,
        6000,
        8000,
        10000,
        15000,
        20000,
      ];
      for (final count in counts) {
        final tier = modelTierForCount(count);
        final stage = modelStageForCount(count);
        expect(
          modelScaleForStage(tier, stage),
          closeTo(modelScaleMultiplier(count), 0.0001),
          reason: 'scale at $count',
        );
        expect(
          modelTintForStage(tier, stage),
          modelTintForCount(count),
          reason: 'tint at $count',
        );
      }
    });

    test('stage 0 is always unscaled and untinted', () {
      for (var tier = 1; tier <= 5; tier++) {
        expect(modelScaleForStage(tier, 0), 1.0);
        expect(modelTintForStage(tier, 0), isNull);
      }
    });
  });

  test('stage boundaries are ordered inside every tier', () {
    for (var tier = 1; tier <= 5; tier++) {
      final stages = kModelSubStages[tier - 1];
      expect(stages.length, 2);
      expect(stages[0], lessThan(stages[1]));
      expect(stages[0], greaterThanOrEqualTo(kModelTierStarts[tier - 1]));
    }
  });
}
