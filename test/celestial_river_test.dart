import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/three/celestial_river.dart';
import 'package:jannti/three/celestial_river_route.dart';
import 'package:jannti/three/nature_layout.dart';
import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// Guards the measured geometry of the celestial river (phase 9.4).
///
/// Every number here was measured from the island meshes themselves
/// (2026-11-19): the route on the meadow, the two spillways into the lakes,
/// the waterfall over the southern mountains and the edge fall. A figure that
/// drifts means the river now cuts through a lake, floats over the basin, or
/// buries itself in rock — so the test fails instead of the scene.
void main() {
  final route = kCelestialRiverRoute;

  /// صفوف جدول الطبيعة لشبكة معيّنة.
  List<List<double>> rowsOf(int mesh) =>
      kNatureInstances.where((List<double> r) => r[0].toInt() == mesh).toList();

  group('بناء الشبكات', () {
    test(
      'النهر يُبنى كاملًا: ٦٧ شبكة والتحريك لا يرمي',
      () async {
        // الحارس الذي كشف خطأَي الصفوف: `_mesh` يحتاج **صفًّا لكل عيّنة** لا
        // صفًّا لكل عمود. حين بُنيت الحافة المبلَّلة والجدار والمصبّان بصفوف
        // أحادية العمود، مرّ التحليل والاختبارات الرقمية وسقط البناء في
        // المتصفح بـRangeError، فلم يظهر النهر أصلًا.
        final river = await CelestialRiver.build();
        expect(river.group.children.length, greaterThan(50));
        // التحريك يكتب في مصفوفات UV الحقيقية؛ فشله يعني ماءً متجمّدًا.
        river.update(0.0);
        river.update(1.25);
        expect(river.group.children.length, greaterThan(50));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'كل شبكة مرسومة فعلًا: فهرس مثلثات غير فارغ ولا ناظم NaN',
      () async {
        // الحارس الذي كشف شلال M15 المفقود (2026-11-19): بُني صفًّا لكل نقطة
        // بدل صفٍّ لكل z، فرأى `_mesh` عمودًا واحدًا، فخرج الفهرس فارغًا
        // والنواظم NaN — والمجسّم موجود بأبعاد سليمة لكنه لا يرسم مثلثًا.
        // فحص الحدود وحده لا يكشف ذلك، فالحارس هنا على الفهرس والنواظم.
        final river = await CelestialRiver.build();
        var meshes = 0;
        for (final child in river.group.children) {
          if (child is! three.Mesh) continue;
          final geometry = child.geometry;
          if (geometry == null) continue;
          meshes++;
          final index = geometry.index;
          final position = geometry.getAttribute('position');
          final vertices = position == null ? 0 : position.count;
          // `DodecahedronGeometry` (حجارة المخاضات) غير مفهرسة بطبيعتها، فالمقياس
          // الصحيح هو عدد المثلثات: الفهرس إن وُجد وإلا عدد الرؤوس.
          final triangles = index == null ? vertices : index.count;
          expect(
            triangles,
            greaterThan(0),
            reason:
                'شبكة بلا مثلثات عند الطفل رقم $meshes '
                '(index=${index?.count} verts=$vertices)',
          );
          final normal = geometry.getAttribute('normal');
          if (normal == null) continue;
          for (final value in normal.array.toDartList()) {
            expect(
              (value as num).isNaN,
              isFalse,
              reason: 'ناظم NaN في الشبكة رقم $meshes',
            );
          }
        }
        expect(meshes, greaterThan(50));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('مسار النهر', () {
    test('الطول ١٥٠٫٩٤ وحدة و٤٣٣ عيّنة بتباعد ٠٫٣٥', () {
      expect(kCelestialRiverSampleStep, 0.35);
      expect(route.length, closeTo(150.937, 0.02));
      expect(route.samples.length, 433);
      expect(route.samples.first.s, 0.0);
      expect(route.samples.last.s, closeTo(route.length, 1e-9));
    });

    test('يبدأ عند قدم شلال M15 لا في المرج', () {
      final first = route.samples.first;
      expect(first.x, closeTo(-1.55, 0.02));
      expect(first.z, closeTo(-36.10, 0.02));
      // القدم المعلنة في جدول الشلال على بعد أقل من نصف عيّنة.
      final dx = first.x - kCelestialFallFoot[0];
      final dz = first.z - kCelestialFallFoot[1];
      expect(math.sqrt(dx * dx + dz * dz), lessThan(0.2));
      // المماس الأول يتجه غربًا وشمالًا (نحو المرج)، لا شرقًا إلى الصخر.
      expect(first.tx, lessThan(0.0));
      expect(first.tz, greaterThan(0.0));
      expect(first.tx, closeTo(-0.7234, 0.001));
      expect(first.tz, closeTo(0.6904, 0.001));
    });

    test('لا انثناء حاد: أقصى تغيّر في المماس أقل من ٠٫١ راديان', () {
      var worst = 0.0;
      for (var i = 1; i < route.samples.length; i++) {
        final a = route.samples[i - 1];
        final b = route.samples[i];
        final dot = (a.tx * b.tx + a.tz * b.tz).clamp(-1.0, 1.0);
        final angle = math.acos(dot);
        if (angle > worst) worst = angle;
      }
      // المقيس ٠٫٠٤٧ راديان (٢٫٧°) عند s ≈ ٩٦٫٨.
      expect(worst, lessThan(0.10));
    });

    test('الناظم والمماس متعامدان ووحديان في كل عيّنة', () {
      for (final sample in route.samples) {
        expect(
          sample.tx * sample.tx + sample.tz * sample.tz,
          closeTo(1.0, 1e-6),
        );
        expect(
          sample.tx * sample.nx + sample.tz * sample.nz,
          closeTo(0.0, 1e-9),
        );
        // الناظم = المماس مُدارًا ٩٠° في المستوى.
        expect(sample.nx, closeTo(sample.tz, 1e-12));
        expect(sample.nz, closeTo(-sample.tx, 1e-12));
      }
    });

    test('عرض الماء ٤٫٧ عند القدم ثم ٣٫٢ بعد ست وحدات', () {
      expect(route.halfWidthAt(0), closeTo(kCelestialRiverHeadHalfWidth, 1e-9));
      expect(kCelestialRiverHeadHalfWidth, 2.35);
      expect(route.halfWidthAt(6.0), closeTo(kCelestialRiverHalfWidth, 1e-9));
      expect(route.halfWidthAt(80.0), closeTo(kCelestialRiverHalfWidth, 1e-9));
      // يتناقص بلا قفزات بين الطرفين.
      var previous = double.infinity;
      for (var s = 0.0; s < 6.0; s += 0.5) {
        final w = route.halfWidthAt(s);
        expect(w, lessThanOrEqualTo(previous + 1e-9));
        previous = w;
      }
    });

    test('الجدار يغرق عند الطرفين ويكتمل في الوسط', () {
      expect(route.kerbFactorAt(0.0), 0.0);
      expect(route.kerbFactorAt(route.length), 0.0);
      expect(route.kerbFactorAt(route.length / 2), 1.0);
      expect(route.kerbFactorAt(0.9), closeTo(0.5, 1e-9));
      expect(route.kerbFactorAt(route.length - 0.9), closeTo(0.5, 1e-9));
    });

    test('مناسيب الماء والسرير والجدار مرتّبة', () {
      expect(kCelestialRiverWaterY, 0.26);
      expect(kCelestialRiverBedY, 0.22);
      expect(kCelestialRiverKerbTopY, 0.40);
      expect(kCelestialRiverBedY, lessThan(kCelestialRiverWaterY));
      expect(kCelestialRiverKerbTopY, greaterThan(kCelestialRiverWaterY));
      // القدم نزل إلى −٠٫٨٥ ليدفن في حوض البحيرتين (−٠٫٤/−٠٫٦).
      expect(kCelestialRiverKerbFootY, -0.85);
      expect(kCelestialRiverKerbFootY, lessThan(-0.6));
      // خلوص الزرع يغطي الماء + كامل الجدار وهامشًا.
      expect(kCelestialRiverPlantClearance, 3.45);
      expect(
        kCelestialRiverPlantClearance,
        greaterThan(kCelestialRiverHalfWidth + kCelestialRiverKerbTopEdge),
      );
      expect(
        kCelestialRiverKerbFootEdge,
        greaterThan(kCelestialRiverKerbTopEdge),
      );
    });
  });

  group('البحيرتان والمصبّان', () {
    test('المسار لا يدخل أي بحيرة: خلوص ٥٫٨٨ و٩٫٤٨ من حدّ الماء', () {
      for (var i = 0; i < kNatureLakes.length; i++) {
        final lake = kNatureLakes[i];
        var best = double.infinity;
        for (final sample in route.samples) {
          final d = math.sqrt(
            math.pow(sample.x - lake[0], 2) + math.pow(sample.z - lake[1], 2),
          );
          final clearance = d - lake[2];
          if (clearance < best) best = clearance;
        }
        expect(best, greaterThan(i == 0 ? 5.8 : 9.4), reason: 'البحيرة $i');
      }
    });

    test('المصبّان يصلان حدّ ماء البحيرتين بالحساب لا بالتقدير', () {
      expect(kCelestialInlets.length, 2);

      for (final spec in kCelestialInlets) {
        final s = spec[0];
        final lake = kNatureLakes[spec[1].toInt()];
        final sample = route.at(s);

        // الناظم يُقلب ليشير إلى البحيرة، كما في `_planInlets`.
        var nx = sample.nx;
        var nz = sample.nz;
        final toward = (lake[0] - sample.x) * nx + (lake[1] - sample.z) * nz;
        if (toward < 0) {
          nx = -nx;
          nz = -nz;
        }
        expect(
          (lake[0] - sample.x) * nx + (lake[1] - sample.z) * nz,
          greaterThan(0.0),
        );

        // بداية القناة على بعد ١٫٥٥ من خط المنتصف (عرض فم المصبّ).
        final sx = sample.x + nx * 1.55;
        final sz = sample.z + nz * 1.55;

        double rayTo(double radius) {
          final fx = sx - lake[0];
          final fz = sz - lake[1];
          final b = 2 * (fx * nx + fz * nz);
          final c = fx * fx + fz * fz - radius * radius;
          final disc = b * b - 4 * c;
          expect(disc, greaterThanOrEqualTo(0.0));
          final root = math.sqrt(disc);
          final first = (-b - root) / 2;
          final second = (-b + root) / 2;
          expect(second, greaterThan(0.0));
          return first > 0 ? first : second;
        }

        final shore = rayTo(lake[3]);
        final water = rayTo(lake[2]);
        // المقيس من بعد ١٫٥٥ عن خط المنتصف: ٢٫٥٠/٤٫٣٦ للبحيرة ٠
        // و٥٫٨٧/٨٫٢٧ للبحيرة ١ (البوابة عند ٤٫٠٥ و٧٫٤٢ عن المركز).
        expect(shore, closeTo(spec[1].toInt() == 0 ? 2.50 : 5.87, 0.05));
        expect(water, closeTo(spec[1].toInt() == 0 ? 4.36 : 8.27, 0.05));
        expect(shore, lessThan(water));
        // نهاية القناة (water + 0.45) داخل ماء البحيرة لا على شاطئها.
        final ex = sx + nx * (water + 0.45);
        final ez = sz + nz * (water + 0.45);
        final endDistance = math.sqrt(
          math.pow(ex - lake[0], 2) + math.pow(ez - lake[1], 2),
        );
        expect(endDistance, lessThan(lake[2]));
        // وبدايتها خارج الجدار فلا قناة تخترق الماء.
        expect(1.55 + shore, greaterThan(kCelestialRiverHalfWidth + 0.85));
      }
    });

    test('عرض قناة المصبّ والانخفاض مطابقان للهندسة', () {
      expect(kCelestialInletHalfWidth, 0.62);
      expect(kCelestialInletEdgeDrop, 0.20);
      // القناة أضيق من الماء، فلا تبتلع الجدار عند الفتحة.
      expect(kCelestialInletHalfWidth, lessThan(kCelestialRiverHalfWidth));
    });
  });

  group('شلال M15', () {
    test('الجدول ١٨ صفًا × ٥ أعمدة، وكل عمود يهبط بلا صعود', () {
      expect(kCelestialFallProfile.length, 18);
      expect(kCelestialFallColumns.length, 5);
      for (final row in kCelestialFallProfile) {
        expect(row.length, 1 + kCelestialFallColumns.length);
        // z يتقدّم جنوبًا إلى الشمال صفًا بعد صف.
      }
      for (var c = 0; c < kCelestialFallColumns.length; c++) {
        for (var i = 1; i < kCelestialFallProfile.length; i++) {
          expect(
            kCelestialFallProfile[i][c + 1],
            lessThanOrEqualTo(kCelestialFallProfile[i - 1][c + 1] + 1e-9),
            reason: 'العمود $c يهبط',
          );
        }
      }
      // الأعمدة مرتّبة من الغرب إلى الشرق.
      for (var c = 1; c < kCelestialFallColumns.length; c++) {
        expect(
          kCelestialFallColumns[c],
          greaterThan(kCelestialFallColumns[c - 1]),
        );
      }
    });

    test('الهبوط ٩٫١٦ والقدم عند سطح الماء', () {
      final top = kCelestialFallProfile.first
          .skip(1)
          .reduce((double a, double b) => a > b ? a : b);
      expect(top, closeTo(9.42, 0.01));
      // الشبكة نفسها تنزل إلى ٠٫٢٤ عند القدم (kCelestialFallMinY).
      expect(top - kCelestialFallMinY, greaterThan(9.0));
      expect(kCelestialFallMinY, 0.24);
      expect(kCelestialFallMinY, lessThan(kCelestialRiverWaterY));
      // الصف الأخير لا ينزل تحت مستوى الماء المصحّح.
      for (final y in kCelestialFallProfile.last.skip(1)) {
        expect(y, greaterThanOrEqualTo(kCelestialFallMinY));
        expect(y, lessThan(1.0));
      }
      // آخر صف عند z = −36.0، وقدم المسار على بعد ٥ سم منه.
      expect(kCelestialFallProfile.last[0], -36.0);
      expect(kCelestialFallFoot[1], closeTo(-36.05, 0.01));
      expect(kCelestialFallPlungeRadius, 2.10);
    });

    test('فتحة الشلال تغطّي قدم المسار أفقيًا', () {
      final start = route.samples.first;
      expect(start.x, greaterThanOrEqualTo(kCelestialFallColumns.first));
      expect(start.x, lessThanOrEqualTo(kCelestialFallColumns.last));
      // القدم في وسط الجدول تمامًا.
      final center =
          (kCelestialFallColumns.first + kCelestialFallColumns.last) / 2;
      expect(start.x, closeTo(center, 0.2));
    });

    test(
      'الصف العلوي مطمور تحت الصخر فلا حافة معلّقة',
      () async {
        // الطمر يخفي القصّة المستديرة التي ظهرت 2026-11-19: الشبكة يجب أن
        // تبدأ **أخفض** من أعلى قيمة في الجدول المقيس.
        final river = await CelestialRiver.build();
        three.Mesh? fall;
        for (final child in river.group.children) {
          if (child is! three.Mesh) continue;
          final geometry = child.geometry;
          if (geometry == null) continue;
          geometry.computeBoundingBox();
          final box = geometry.boundingBox;
          if (box == null) continue;
          if ((box.min.x - kCelestialFallColumns.first).abs() < 0.01 &&
              (box.max.x - kCelestialFallColumns.last).abs() < 0.01 &&
              (box.max.z - kCelestialFallProfile.last[0]).abs() < 0.01) {
            fall = child;
          }
        }
        expect(fall, isNotNull, reason: 'شبكة شلال M15 غير موجودة');
        final top = kCelestialFallProfile.first
            .skip(1)
            .reduce((double a, double b) => a > b ? a : b);
        final meshTop = fall!.geometry!.boundingBox!.max.y;
        expect(meshTop, lessThan(top - 0.3));
        expect(meshTop, greaterThan(top - 0.8));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('شلال الحافة', () {
    test('أربع نقاط تنزل من ٠٫٢٦ إلى −١٢ وتتّسع كلما هبطت', () {
      expect(kCelestialEdgeFall.length, 4);
      expect(kCelestialEdgeFall.first[1], kCelestialRiverWaterY);
      expect(kCelestialEdgeFall.last[1], -12.0);
      for (var i = 1; i < kCelestialEdgeFall.length; i++) {
        expect(
          kCelestialEdgeFall[i][0],
          greaterThan(kCelestialEdgeFall[i - 1][0]),
        );
        expect(
          kCelestialEdgeFall[i][1],
          lessThan(kCelestialEdgeFall[i - 1][1]),
        );
        expect(
          kCelestialEdgeFall[i][2],
          greaterThan(kCelestialEdgeFall[i - 1][2]),
        );
      }
    });

    test('يبدأ عند آخر عيّنة من المسار تمامًا', () {
      final last = route.samples.last;
      expect(last.x, closeTo(30.0, 1e-9));
      expect(last.z, closeTo(82.0, 1e-9));
      expect(route.distanceTo(30.0, 82.0), lessThan(1e-9));
    });
  });

  group('المخاضات', () {
    test('أربع بلاطات مسار، كل واحدة على خط المنتصف', () {
      expect(kCelestialFords.length, 4);
      expect(rowsOf(10), isNotEmpty);
      final seen = <double>[];
      for (final ford in kCelestialFords) {
        final s = ford[0];
        final x = ford[1];
        final z = ford[2];
        // البلاطة موجودة فعلًا في جدول الطبيعة (شبكة ١٠ = meadow_path).
        final match = rowsOf(10).where((List<double> r) {
          return (r[13] - x).abs() < 0.01 && (r[15] - z).abs() < 0.01;
        }).toList();
        expect(match.length, 1, reason: 'بلاطة المخاضة ($x، $z)');
        // البلاطة تعبر المجرى: مركزها داخل حدّ الجدار الخارجي (٢٫٤٥)،
        // ولا تتجاوزه إلى المرج. المقيس ١٫٥٧ و٠٫٧٢ و٠٫٧٤ و٠٫٠١.
        expect(route.distanceTo(x, z), lessThan(2.45));
        final sample = route.at(s);
        final dx = sample.x - x;
        final dz = sample.z - z;
        expect(math.sqrt(dx * dx + dz * dz), lessThan(2.45));
        // و`s` هي أقرب طول على المسار إلى مركز البلاطة (لا طول اعتباطي):
        var nearest = route.samples.first;
        var nearestDistance = double.infinity;
        for (final candidate in route.samples) {
          final ddx = candidate.x - x;
          final ddz = candidate.z - z;
          final d = ddx * ddx + ddz * ddz;
          if (d < nearestDistance) {
            nearestDistance = d;
            nearest = candidate;
          }
        }
        expect((nearest.s - s).abs(), lessThan(0.4));
        seen.add(s);
      }
      // المسافات متزايدة على طول المسار.
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
      expect(seen.first, closeTo(11.25, 1e-9));
      expect(seen.last, closeTo(112.50, 1e-9));
    });
  });

  group('الجسر', () {
    test('المسار لا يمرّ تحت الجسر: خلوص ≥ ٨ وحدات', () {
      // الجسر يمتد x ∈ [−١٢٫٩٩، ١٩٫٠١] عند z = −٥٫٨.
      var best = double.infinity;
      for (final sample in route.samples) {
        final cx = sample.x.clamp(-12.99, 19.01);
        final dx = sample.x - cx;
        final dz = sample.z + 5.8;
        final d = math.sqrt(dx * dx + dz * dz);
        if (d < best) best = d;
      }
      // المقيس ٨٫٢٣.
      expect(best, greaterThan(8.0));
    });
  });

  group('الإزاحات المعتمدة', () {
    test('ثلاثة مجسّمات طبيعية أُزيحت ولا واحد حُذف', () {
      expect(kCelestialPropShifts.length, 3);
      for (final shift in kCelestialPropShifts) {
        final mesh = shift[0].toInt();
        final from = <double>[shift[1], shift[2]];
        final to = <double>[shift[3], shift[4]];
        // الصف الأصلي موجود مرة واحدة بالضبط (المطابقة بالشبكة والإحداثي).
        final matches = rowsOf(mesh).where((List<double> r) {
          return (r[13] - from[0]).abs() < 0.01 &&
              (r[15] - from[1]).abs() < 0.01;
        }).toList();
        expect(matches.length, 1, reason: 'المجسّم $mesh عند $from');

        final distance = math.sqrt(
          math.pow(to[0] - from[0], 2) + math.pow(to[1] - from[1], 2),
        );
        // إزاحة صغيرة: ٢–٤ وحدات، لا نقل مجسّم إلى الجهة الأخرى.
        expect(distance, greaterThanOrEqualTo(1.8));
        expect(distance, lessThanOrEqualTo(4.2));

        // كان على المسار/الجدار، وصار خارجه.
        expect(route.distanceTo(from[0], from[1]), lessThan(2.45));
        expect(
          route.distanceTo(to[0], to[1]),
          greaterThanOrEqualTo(3.45),
          reason: 'المجسّم $mesh بعد الإزاحة',
        );
      }
    });

    test('كل الشجر (لا العشب) خارج الجدار بعد الإزاحات', () {
      const treeMeshes = <int>{0, 1, 15, 16};
      for (final row in kNatureInstances) {
        final mesh = row[0].toInt();
        if (!treeMeshes.contains(mesh)) continue;
        var x = row[13];
        var z = row[15];
        for (final shift in kCelestialPropShifts) {
          if (shift[0].toInt() != mesh) continue;
          if ((x - shift[1]).abs() > 0.01) continue;
          if ((z - shift[2]).abs() > 0.01) continue;
          x = shift[3];
          z = shift[4];
        }
        expect(
          route.distanceTo(x, z),
          greaterThan(kCelestialRiverHalfWidth + kCelestialRiverKerbTopEdge),
          reason: 'شجرة في المجرى عند ($x، $z)',
        );
      }
    });

    test('tree_b يبقى على الضفة كما هو (خلوص ٢٫٩٧)', () {
      final rows = rowsOf(16).where((List<double> r) {
        return (r[13] - (-4.73)).abs() < 0.01 &&
            (r[15] - (-28.92)).abs() < 0.01;
      }).toList();
      expect(rows.length, 1);
      expect(route.distanceTo(-4.73, -28.92), closeTo(2.97, 0.05));
    });

    test('الجيودان البلوريان نُقلا غربًا ولم يُحذفا', () {
      expect(kCelestialGeodeShifts.length, 2);
      for (final shift in kCelestialGeodeShifts) {
        final oldDistance = route.distanceTo(shift[0], shift[1]);
        final newDistance = route.distanceTo(shift[2], shift[3]);
        // كانا على المسار فعلًا.
        expect(oldDistance, lessThan(1.5));
        expect(newDistance, greaterThanOrEqualTo(4.5));
        // الإزاحة ٥ وحدات غربًا تقريبًا.
        expect(shift[2], lessThan(shift[0]));
        expect((shift[3] - shift[1]).abs(), lessThan(1.2));
      }
    });
  });
}
