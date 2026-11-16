import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/models/reward_type.dart';
import 'package:jannti/three/asset_map.dart';
import 'package:jannti/three/model_evolution.dart';
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
    test('المراحل ١..٥ ترتفع ٠٫٦/٢٫٣/٣٫٤/٥٫٥/٩، وأي قيمة غريبة ترجع ٣٫٤', () {
      expect(
        [for (var t = 1; t <= 5; t++) tierHeight(t)],
        [0.6, 2.3, 3.4, 5.5, 9.0],
      );
      expect(tierHeight(0), 3.4);
      expect(tierHeight(9), 3.4);
    });

    test('نموذج المرتبة ١ المكتمل أعلى من الفسلة ولا يتجاوز المرتبة ٢', () {
      final seedling = modelInstanceHeight(1, 0, 1.0);
      final grown = modelInstanceHeight(1, 1, modelScaleForStage(1, 1));
      final coloured = modelInstanceHeight(1, 2, modelScaleForStage(1, 2));

      // الفسلة قصيرة: داخل عشب المروج (٠٫٣٥–٠٫٧٠) لا فوقه بكثير.
      expect(seedling, closeTo(0.6, 1e-9));
      // النموذج المكتمل يقارب ٢٫٥ ضعف الفسلة، فالفرق يُرى من أول نظرة.
      expect(grown, greaterThan(seedling * 2.0));
      expect(coloured, greaterThan(grown));
      // ولا يسبق المرتبة التالية، فلا يحدث انكماش عند ١٠٠ مكافأة.
      expect(coloured, lessThan(tierHeight(2)));
    });

    test('المراتب ٢..٥ تستخدم ارتفاع المرتبة كما هو', () {
      for (var tier = 2; tier <= 5; tier++) {
        expect(
          modelInstanceHeight(tier, 2, 1.13),
          closeTo(tierHeight(tier) * 1.13, 1e-9),
        );
      }
    });
  });

  /// القاعدة التي طلبها المستخدم: «أكبر موديل في مرتبة لا يكون أكبر من أصغر
  /// موديل في المرتبة التالية». الحارس هنا يقيس الطرفين عند عتبة الترقية
  /// الفعلية (٩٩ ← ١٠٠ … ٩٩٩٩ ← ١٠٠٠٠)، لا القيم النظرية فقط.
  group('سلّم الأحجام لا ينكمش عند الترقية', () {
    double heightAt(int count) => modelInstanceHeight(
      modelTierForCount(count),
      modelStageForCount(count),
      modelScaleMultiplier(count),
    );

    test('داخل المرتبة: كل مرحلة أطول من التي قبلها', () {
      for (var tier = 1; tier <= 5; tier++) {
        final heights = <double>[
          for (var stage = 0; stage <= 2; stage++)
            modelInstanceHeight(tier, stage, modelScaleForStage(tier, stage)),
        ];
        expect(
          heights[0],
          lessThan(heights[1]),
          reason: 'تير $tier: المرحلة ١ ليست أطول من ٠',
        );
        expect(
          heights[1],
          lessThan(heights[2]),
          reason: 'تير $tier: المرحلة ٢ ليست أطول من ١',
        );
      }
    });

    test('عند كل عتبة ترقية: الموديل الجديد أطول ٢٠٪ على الأقل', () {
      for (var tier = 1; tier < 5; tier++) {
        final lastOfTier = heightAt(kModelTierStarts[tier] - 1);
        final firstOfNext = heightAt(kModelTierStarts[tier]);
        expect(
          firstOfNext,
          greaterThanOrEqualTo(lastOfTier * 1.2),
          reason:
              'الترقية $tier ← ${tier + 1}: '
              '${lastOfTier.toStringAsFixed(2)} ← '
              '${firstOfNext.toStringAsFixed(2)} أقل من ٢٠٪',
        );
      }
    });

    test('سقف المرتبة الخامسة ١١٫٢٥ وحدة ولا يزيد بعد ٤٠٠٠٠', () {
      expect(modelInstanceHeight(5, 2, 1.25), closeTo(11.25, 1e-9));
      // ٣٠٠٠٠ يأخذ دفعة واحدة فقط (1.24)، والسقف 1.25 يُدرَك عند ٤٠٠٠٠.
      expect(modelScaleMultiplier(30000), closeTo(1.24, 1e-9));
      expect(modelScaleMultiplier(40000), closeTo(1.25, 1e-9));
      expect(modelScaleMultiplier(999999), closeTo(1.25, 1e-9));
    });
  });

  /// الدفن يخفّض الارتفاع المرئي، فيجب أن تبقى قاعدة «الترقية لا تُقصّر»
  /// محققة بعد الدفن أيضًا لا قبله فقط.
  group('الدفن في الأرض', () {
    test('نسب الدفن: نخلة ٤٠/١٦/١٣/١٣/١٥٪، شجرة ١٠٪', () {
      const heights = <double>[0.6, 2.3, 3.4, 5.5, 9.0];
      for (var tier = 1; tier <= 5; tier++) {
        final h = heights[tier - 1];
        expect(
          modelGroundSink(isPalm: true, tier: tier, height: h),
          closeTo(h * kPalmGroundSink[tier - 1], 1e-9),
          reason: 'تير $tier',
        );
        expect(
          modelGroundSink(isPalm: false, tier: tier, height: h),
          closeTo(h * kTreeGroundSink, 1e-9),
          reason: 'شجرة تير $tier',
        );
      }
    });

    test('الارتفاع الظاهر بعد الدفن يظل تصاعديًا عبر العتبات', () {
      double visibleAt(int count) {
        final tier = modelTierForCount(count);
        final height = modelInstanceHeight(
          tier,
          modelStageForCount(count),
          modelScaleMultiplier(count),
        );
        return height -
            modelGroundSink(isPalm: true, tier: tier, height: height);
      }

      for (var tier = 1; tier < 5; tier++) {
        final lastOfTier = visibleAt(kModelTierStarts[tier] - 1);
        final firstOfNext = visibleAt(kModelTierStarts[tier]);
        expect(
          firstOfNext,
          greaterThanOrEqualTo(lastOfTier * 1.2),
          reason:
              'بعد الدفن، الترقية $tier ← ${tier + 1}: '
              '${lastOfTier.toStringAsFixed(2)} ← '
              '${firstOfNext.toStringAsFixed(2)} أقل من ٢٠٪',
        );
      }
    });

    test('الدفن لا يبتلع الموديل: يبقى ارتفاع ظاهر موجب', () {
      for (var tier = 1; tier <= 5; tier++) {
        for (var stage = 0; stage <= 2; stage++) {
          final height = modelInstanceHeight(
            tier,
            stage,
            modelScaleForStage(tier, stage),
          );
          final sink = modelGroundSink(
            isPalm: true,
            tier: tier,
            height: height,
          );
          expect(sink, lessThan(height), reason: 'تير $tier مرحلة $stage');
          expect(height - sink, greaterThan(0));
        }
      }
    });

    test('المرتبة الأولى وحدها تُدفن ٤٠٪ لأن عشبها ٥٧٪ من الموديل', () {
      expect(
        modelGroundSink(isPalm: true, tier: 1, height: 1.0),
        closeTo(0.40, 1e-9),
      );
      expect(
        modelGroundSink(isPalm: true, tier: 0, height: 1.0),
        closeTo(0.40, 1e-9),
      );
      expect(
        modelGroundSink(isPalm: true, tier: 99, height: 1.0),
        closeTo(0.15, 1e-9),
      );
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

          // الملف الخام مش لازم يكون بطول المرتبة ولا على نقطة الأصل — الفسلة
          // مثلًا ٠٫١٧ فقط. المهم إن فيه هندسة حقيقية: صندوق فاضي بيرجّع
          // ارتفاعًا غير منتهٍ، و`fitModelToGround` بعدها يقيس صفرًا ويترك
          // الموديل كما هو. الطول النهائي هو اللي بيثبت إن الضبط اشتغل.
          final before = three.Box3().setFromObject(scene);
          final rawHeight = before.getSize(three.Vector3()).y;
          expect(rawHeight.isFinite, isTrue, reason: 'صندوق فاضي: ${c.path}');
          expect(
            rawHeight,
            greaterThan(0),
            reason: 'الملف بلا هندسة: ${c.path}',
          );

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

          // إعادة الضبط على نسخة خرجت من الكاش مضبوطة أصلًا لازم تفضل بنفس
          // الارتفاع. `scale.set(...)` كان يمحو الضبط السابق، فترتد النخلة إلى
          // 10.74 وحدة أصلية وتظهر الشتلات أضخم من النموذج المكتمل.
          fitModelToGround(copy, target);
          final refitBox = three.Box3().setFromObject(copy);
          expect(
            refitBox.getSize(three.Vector3()).y,
            closeTo(target, target * 0.01),
            reason: 'إعادة الضبط رجّعت الموديل لحجمه الخام',
          );
          expect(
            refitBox.min.y.abs(),
            lessThan(0.05),
            reason: 'النسخة طلعت من الأرض',
          );

          if (c.tier == 1) {
            // وبعد الدمج: النموذج المكتمل أعلى من الشتلة، لا أصغر منها.
            final grown = modelInstanceHeight(1, 1, modelScaleForStage(1, 1));
            fitModelToGround(copy, grown);
            final grownBox = three.Box3().setFromObject(copy);
            expect(
              grownBox.getSize(three.Vector3()).y,
              closeTo(grown, grown * 0.01),
              reason: 'ارتفاع النموذج المكتمل',
            );
            expect(
              grownBox.min.y.abs(),
              lessThan(0.05),
              reason: 'النموذج المكتمل مش على الأرض',
            );
          }

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

            // قصّ الأوراق معتمد على القناة الشفافة، لكن مش كل موديل بيقصّ:
            // خامة النخيل معتمة بالكامل (`alphaMode` غائب = OPAQUE)، فطلب
            // بكسلات مقصوصة منها بيفشل على الفاضي. الشرط بيتفعّل بس على مادة
            // بتعلن قصًّا — `MASK` بيوصل هنا كـalphaTest، و`BLEND` كـtransparent.
            final cutout = mat.alphaTest > 0 || mat.transparent == true;

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
            if (cutout) {
              expect(
                transparent,
                greaterThan(0),
                reason: 'مفيش بكسلات مقصوصة: $path',
              );
            }
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
