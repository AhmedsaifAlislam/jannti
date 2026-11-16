import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/models/reward_type.dart';
import 'package:jannti/three/asset_map.dart';
import 'package:jannti/three/ground_texture.dart';
import 'package:jannti/three/nature_layout.dart';

/// The staged-model table is the only place that knows where a tier's GLB
/// lives, and `pubspec.yaml` is the only place that decides whether it reaches
/// the APK. If those two drift apart the scene silently keeps drawing its
/// procedural mesh, which is exactly the bug this suite exists to catch.
void main() {
  group('جدول المراحل', () {
    test('النخلة والشجرة لهما ٥ مراحل، والمباني بلا مراحل', () {
      expect(hasTierModels(RewardType.palmTree), isTrue);
      expect(hasTierModels(RewardType.tree), isTrue);

      for (final type in [
        RewardType.house,
        RewardType.palace,
        RewardType.mosque,
        RewardType.treasure,
      ]) {
        expect(hasTierModels(type), isFalse, reason: '$type');
        expect(tierRelativePath(type, 3), isNull);
        expect(resolveTierModelPath(type, 3), isNull);
      }

      for (final type in [RewardType.palmTree, RewardType.tree]) {
        for (var tier = 1; tier <= 5; tier++) {
          expect(
            tierRelativePath(type, tier),
            isNotNull,
            reason: '$type tier $tier',
          );
        }
      }
    });

    test('المراحل خارج النطاق تُقيَّد إلى ١..٥', () {
      expect(
        tierRelativePath(RewardType.tree, 0),
        tierRelativePath(RewardType.tree, 1),
      );
      expect(
        tierRelativePath(RewardType.tree, 9),
        tierRelativePath(RewardType.tree, 5),
      );
    });

    test('كل مسار مدمج موجود على القرص', () {
      for (final asset in kBundledModelAssets) {
        expect(File(asset).existsSync(), isTrue, reason: 'ناقص: $asset');
      }
    });

    test('كل مسار مُعاد هو ملف مدمج فعلي', () {
      for (final type in [RewardType.palmTree, RewardType.tree]) {
        for (var tier = 1; tier <= 5; tier++) {
          final path = resolveTierModelPath(type, tier);
          expect(path, isNotNull, reason: '$type/$tier');
          expect(
            kBundledModelAssets,
            contains(path),
            reason: '$type/$tier أشار إلى $path وهو غير معلن',
          );
          expect(File(path!).existsSync(), isTrue, reason: path);
        }
      }
    });

    test('pubspec يعلن كل ملف مدمج، ولا يعلن ملفًا غير موجود', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      final declared = <String>{
        for (final line in pubspec.split('\n'))
          if (line.trim().startsWith('- assets/3d/'))
            line.trim().substring(2).trim(),
      };

      // `assets/3d/` covers the files sitting directly in that folder; Flutter
      // does not expand it into the tier subfolders.
      if (declared.remove('assets/3d/')) {
        for (final f in Directory(
          'assets/3d',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.glb'))) {
          declared.add(f.path.replaceAll('\\', '/'));
        }
      }

      for (final asset in kBundledModelAssets) {
        expect(
          declared,
          contains(asset),
          reason: 'معلن في asset_map ومش في pubspec: $asset',
        );
      }
      for (final asset in kBundledModelTextures) {
        expect(
          declared,
          contains(asset),
          reason: 'خامة الموديل مش معلنة في pubspec: $asset',
        );
      }
      for (final type in RewardType.values) {
        expect(
          declared,
          contains(assetForRewardType(type)),
          reason: 'الملف العام غير معلن: $type',
        );
      }
      for (final asset in declared) {
        expect(
          File(asset).existsSync(),
          isTrue,
          reason: 'pubspec بيعلن ملف مش موجود: $asset',
        );
      }
    });

    test('خامات الأرض مدمجة وموجودة بمقاس ٢٥٦', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      for (final asset in [kGrassBaseTexture, kGroundSpotTexture]) {
        final file = File(asset);
        expect(file.existsSync(), isTrue, reason: 'ناقص: $asset');
        expect(
          pubspec.contains('- $asset'),
          isTrue,
          reason: 'مش معلن في pubspec: $asset',
        );

        // PNG: التوقيع ٨ بايت، ثم طول IHDR (٤) ونوعه (٤)، فالعرض والارتفاع
        // كل واحد ٤ بايت big-endian. القياس هنا بلا فكّ ترميز كامل.
        final head = file.readAsBytesSync().sublist(0, 24);
        final width =
            (head[16] << 24) | (head[17] << 16) | (head[18] << 8) | head[19];
        final height =
            (head[20] << 24) | (head[21] << 16) | (head[22] << 8) | head[23];
        // ٢٥٦ لا ٥١٢: three_dart لا يبني سلسلة mip لخامة `DataTexture`، فكل
        // تفصيل إضافي في الخامة يظهر رجفة عند البعد بدل أن يذوب في المستوى
        // التالي. المقاس مصغّر عن قصد في `tool/assets/prep_textures.py`.
        expect(width, 256, reason: '$asset عرض');
        expect(height, 256, reason: '$asset ارتفاع');
      }
    });

    test('كل موديل مدمج بيشير لصورة خارجية جانبيه', () {
      // الصورة المدفونة داخل الـGLB تُمرَّر إلى محمّل الويب كـ`Blob` خاص
      // بـthree_dart، وهو لا يعرفه: يرمي استثناءً داخل `onLoad` ولا يكتمل
      // الـFuture أبدًا، فيموت الموديل على مهلة ١٥ ثانية. الفصل هنا ليس
      // تجميلًا — هو الفرق بين موديل يظهر وآخر لا يظهر.
      for (final model in kBundledModelAssets) {
        final file = File(model);
        expect(file.existsSync(), isTrue, reason: 'ناقص: $model');

        final bytes = file.readAsBytesSync();
        final jsonLength =
            bytes[12] |
            (bytes[13] << 8) |
            (bytes[14] << 16) |
            (bytes[15] << 24);
        final json =
            jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
                as Map<String, dynamic>;

        final images = (json['images'] as List?) ?? const [];
        expect(images, isNotEmpty, reason: 'الموديل بلا خامة: $model');

        final image = images.first as Map<String, dynamic>;
        expect(
          image.containsKey('bufferView'),
          isFalse,
          reason: '$model لسه مدفون جواه الصورة (bufferView)',
        );

        final uri = image['uri'] as String?;
        expect(uri, isNotNull, reason: '$model بلا uri');

        final sidecar = File(
          '${model.substring(0, model.lastIndexOf('/'))}/$uri',
        );
        expect(
          sidecar.existsSync(),
          isTrue,
          reason: 'صورة $model مش موجودة جانبيه: ${sidecar.path}',
        );
      }
    });

    test('التنزيل الخارجي له الأولوية على المدمج', () {
      final dir = Directory.systemTemp.createTempSync('jannti_models_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final rel = tierRelativePath(RewardType.palmTree, 3)!;
      final local = File('${dir.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [1, 2, 3]);

      expect(
        resolveTierModelPath(RewardType.palmTree, 3, localModelsDir: dir.path),
        local.path,
      );

      // ملف ناقص داخل مجلد التنزيل يجب أن يرجع للمدمج، ما يخليش الشجرة تختفي
      expect(
        resolveTierModelPath(RewardType.palmTree, 4, localModelsDir: dir.path),
        isNotNull,
      );
    });

    test('الدالة القديمة تظل ترجع مسارًا صالحًا', () {
      for (final type in RewardType.values) {
        final path = assetForRewardTypeAndTier(type, 3);
        expect(File(path).existsSync(), isTrue, reason: '$type -> $path');
      }
    });
  });

  group('جزر الطبيعة', () {
    test('كل شبكة يسردها nature_layout معلنة وموجودة', () {
      // `nature_layout.dart` مُولَّد: يسرد المسارات التي يطلبها المشهد ولا
      // يعرف شيئًا عن `pubspec.yaml`. غياب الأسطر هناك كان يعني ١٧ طلبًا
      // يرجع ٤٠٤ وجزيرة فارغة تمامًا — وهو بالضبط ما حدث قبل إضافة الحراسة.
      for (final mesh in kNatureMeshPaths) {
        expect(
          kBundledModelAssets,
          contains(mesh),
          reason: 'شبكة مش معلنة في pubspec/asset_map: $mesh',
        );
        expect(File(mesh).existsSync(), isTrue, reason: 'ناقص: $mesh');
      }
    });
  });
}
