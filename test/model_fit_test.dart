import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/models/reward_type.dart';
import 'package:jannti/three/asset_map.dart';
import 'package:jannti/three/model_fit.dart';
import 'package:jannti/three/model_texture.dart';
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
          // نفس ترتيب _loadGLB بالحرف: توسيع الفهرس ثم ضبط المحور ثم النسخ.
          makeModelCloneable(scene);
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

          // كل غرسة بعد الأولى في الحديقة هي clone للموديل المحفوظ، وthree_dart
          // بيرمي `clone need support` على أي فهرس ٣٢-بت. الاستثناء ده كان
          // بيوقّع الاستبدال بصمت والشجرة الإجرائية تفضل مكانها.
          late three.Object3D copy;
          expect(
            () => copy = scene.clone(true),
            returnsNormally,
            reason: 'الموديل مش قابل للنسخ: ${c.path}',
          );

          final copyBox = three.Box3().setFromObject(copy);
          expect(
            copyBox.getSize(three.Vector3()).y,
            closeTo(target, target * 0.01),
            reason: 'النسخة مش بنفس الارتفاع',
          );
          expect(
            copyBox.min.y.abs(),
            lessThan(0.05),
            reason: 'النسخة مش على الأرض',
          );

          // النسخة لازم تكون مستقلة: تدوير واحدة ما لازمش يحرّك الأصل.
          copy.scale.set(1, 1, 1);
          expect(scene.scale.x, isNot(1.0));
        },
      );
    }
  });

  group('تكستشرات الموديلات', () {
    // كل ملف مدمج مرة واحدة: التكستشر بتتقرأ من الملف، لازم تتحوّل لبكسلات
    // خام قبل العرض، وإلا WebGL بيعتبر التكستشر ناقص ويرجّع أسود بالكامل.
    for (final path in kBundledModelAssets) {
      test('${path.split('/').last} بيتحوّل لبكسلات RGBA', () async {
        final gltf = await three_jsm.GLTFLoader().loadAsync(path);
        final scene = gltf?["scene"];
        expect(scene, isNotNull, reason: 'الملف ما اتحلّش: $path');

        final converted = makeTexturesUploadable(scene);
        expect(converted, greaterThan(0), reason: 'مفيش تكستشر اتحوّل: $path');

        var checked = 0;
        scene.traverse((child) {
          if (child is! three.Mesh) return;
          final materials = child.material is List
              ? child.material as List
              : [child.material];
          for (final mat in materials) {
            final texture = mat?.map;
            if (texture == null) continue;
            checked++;

            // المسار اللي بيقرأ `image.data` بيفضل تكستشر ناقص على الويب،
            // وDataTexture هي اللي بترفع البكسلات الخام على المنصتين.
            expect(
              texture,
              isA<three.DataTexture>(),
              reason: 'التكستشر ما اتحوّلش لـDataTexture: $path',
            );

            final image = texture.image;
            expect(image, isA<three.ImageElement>(), reason: path);
            expect(image.width, greaterThan(0), reason: path);
            expect(image.height, greaterThan(0), reason: path);

            final data = image.data;
            expect(
              data.length,
              image.width * image.height * 4,
              reason: 'أبعاد البكسلات مش مطابقة للصورة: $path',
            );

            // قصّ الأوراق معتمد على القناة الشفافة، فلازم الصورة تحتوي
            // بكسلات مقصوصة وبكسلات ظاهرة معًا.
            var opaque = 0;
            var transparent = 0;
            var colored = 0;
            for (var i = 0; i + 3 < data.length; i += 4) {
              final r = data[i] as int;
              final g = data[i + 1] as int;
              final b = data[i + 2] as int;
              final a = data[i + 3] as int;
              if (a > 200) {
                opaque++;
                if (r > 40 || g > 40 || b > 40) colored++;
              } else if (a < 20) {
                transparent++;
              }
            }
            expect(opaque, greaterThan(0), reason: 'مفيش بكسلات ظاهرة: $path');
            expect(
              transparent,
              greaterThan(0),
              reason: 'مفيش بكسلات مقصوصة: $path',
            );
            expect(
              colored,
              greaterThan(0),
              reason: 'كل البكسلات سوداء — الصورة ما اتفكّتش: $path',
            );
          }
        });
        expect(checked, greaterThan(0), reason: 'مفيش مادة بتكستشر: $path');
      });
    }
  });
}
