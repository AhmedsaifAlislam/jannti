import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/models/reward_type.dart';
import 'package:jannti/three/asset_map.dart';

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
}
