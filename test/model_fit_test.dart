import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/models/reward_type.dart';
import 'package:jannti/three/asset_map.dart';
import 'package:jannti/three/model_fit.dart';
import 'package:three_dart_flutterflow/three_dart.dart' as three;
import 'package:three_dart_jsm_flutterflow/three_dart_jsm.dart' as three_jsm;

/// These tests parse the real files with the same loader the scene uses, so a
/// model that no longer decodes, or one whose pivot drifts, fails here instead
/// of showing up as a tree sunk into the ground on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ارتفاع المراحل', () {
    test('المراحل ١..٥ ترتفع ٧/٩/١١/١٤/١٨، وأي قيمة غريبة ترجع ١٠', () {
      expect([for (var t = 1; t <= 5; t++) tierHeight(t)], [7, 9, 11, 14, 18]);
      expect(tierHeight(0), 10);
      expect(tierHeight(9), 10);
    });
  });

  group('قراءة الموديلات المدمجة', () {
    final cases = <({RewardType type, int tier, String path})>[
      for (final type in [RewardType.palmTree, RewardType.tree])
        for (var tier = 1; tier <= 5; tier++)
          (type: type, tier: tier, path: resolveTierModelPath(type, tier)!),
    ];

    for (final c in cases) {
      test(
        '${c.type.name} مرحلة ${c.tier}: ${c.path.split('/').last}',
        () async {
          final loader = three_jsm.GLTFLoader();
          final gltf = await loader.loadAsync(c.path);
          final scene = gltf?["scene"];
          expect(scene, isNotNull, reason: 'الملف ما اتحلّش: ${c.path}');

          // الملف الخام لا يقف على نقطة الأصل — نتحقق إن التصحيح شغال.
          final before = three.Box3().setFromObject(scene);
          expect(before.getSize(three.Vector3()).y, greaterThan(0.5));

          final target = tierHeight(c.tier);
          fitModelToGround(scene, target);

          final after = three.Box3().setFromObject(scene);
          final size = after.getSize(three.Vector3());

          expect(
            size.y,
            closeTo(target, target * 0.01),
            reason: 'الارتفاع بعد الضبط',
          );

          // القاعدة على الأرض، والجسم متمركز حول المحور، وإلا دارت الشجرة
          // في قوس أثناء إعطاء مجموعة الدوران زاوية عشوائية.
          expect(
            after.min.y.abs(),
            lessThan(0.05),
            reason: 'القاعدة مش على الأرض',
          );
          expect(
            (after.min.x + after.max.x) / 2,
            closeTo(0, 0.05),
            reason: 'مش متمركز على x',
          );
          expect(
            (after.min.z + after.max.z) / 2,
            closeTo(0, 0.05),
            reason: 'مش متمركز على z',
          );
        },
      );
    }
  });
}
