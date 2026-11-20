import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_gl_flutterflow/flutter_gl.dart' show Float32Array;
import 'package:three_dart_flutterflow/three_dart.dart' as three;

import 'celestial_river_route.dart';
import 'ground_texture.dart';
import 'nature_layout.dart';

// =============================================================================
// 🌊 النهر السماوي — الماء والجدار والشلالان والمصابّ والرغوة
// =============================================================================
//
// المسار والأرقام كلها في `celestial_river_route.dart`. هنا **الهندسة فقط**:
// شريط ماء يتبع المنحنى، حافة مبلَّلة، جدار حجري يحتويه، شلال M15، شلال حافة
// الجزيرة، مصبّان إلى البحيرتين، حجارة مخاضات، ورغوة.
//
// ثلاث قواعد هندسية لا تُخالف:
// 1. **اتجاه الالتفاف هو ما يُظهر السطح.** المواد `FrontSide` افتراضيًا في
//    three_dart، والوجه المعكوس يُقصّ. شريط الماء يُبنى بعمودين (+الناظم ثم
//    −الناظم) فيأتي الالتفاف `[a,b,c, b,d,c]` بناظم لأعلى، وجدار الضفة يُبنى
//    بعمودين (داخلي ثم خارجي) فيأتي بالتفاف معكوس على الضفة اليمنى.
// 2. **لا سرير تحت الماء.** الشريط المبلَّل ٠٫٣٥ فقط خارج حدّ الماء، وسطحه
//    أخفض ٤ سم. السرير الكامل تحت الماء بنفس المستوى يسبب z-fighting يظهر
//    كخطوط سوداء تتقافز مع حركة الكاميرا.
// 3. **الوقت يبدأ من صفر المشهد** لا من طابع Unix: float32 عند ١٫٧×10⁹
//    خطوته ≈٢٥٦ ثانية، فيتجمّد تحريك الخامة بعد دقائق. الشاشة تمرّر ثواني
//    المشهد، ونفس القاعدة مطبَّقة في `model_sway.dart`.

/// ماء النهر: شريط + مصبّان + بركة استقبال، وكلها تشترك في خامة واحدة.
const String _kFallbackNote =
    'بلا خامة ماء: اللون الفيروزي في المادة يبقى بديلًا مقروءًا.';

/// نصف عرض فتحة المصبّ (العرض ١٫٢٤).
const double _kInletStart = 1.55;
const double _kInletBankStart = 1.90;
const double _kInletLipInner = 0.68;
const double _kInletLipOuter = 1.05;
const double _kInletLipY = 0.30;
const double _kInletFootY = -0.85;
const double _kInletFallLipY = -0.55;
const double _kInletLakeY = -0.78;

/// تكرار الخامة على طول الماء (وحدة عالمية لكل دورة).
const double _kWaterVTile = 5.0;

/// سرعات تحريك UV (دورة/ثانية) — الماء أسرع من الشلال لأن الشلال أطول ظاهريًا.
const double _kWaterScroll = 0.16;
const double _kFallScroll = 0.42;

/// عمق طمر الصف العلوي من شلال M15 تحت سطح الصخر المقيس.
///
/// المقيس أعلى السطح بـ٠٫٢٢، فالطمر ٠٫٥ يضع الصف على ٠٫٢٨ **داخل** الصخر.
const double _kFallCrestTuck = 0.50;

/// النهر كاملًا: أضف [group] إلى المشهد واستدعِ [update] كل إطار.
class CelestialRiver {
  CelestialRiver._();

  final three.Group group = three.Group();

  final CelestialRiverRoute _route = kCelestialRiverRoute;
  final List<_UvScroll> _scrolls = <_UvScroll>[];
  final List<_FoamBit> _foam = <_FoamBit>[];
  final math.Random _rng = math.Random(20261119);

  /// يبني كل شبكات النهر. الخامة تُحمَّل هنا، وفشلها لا يمنع بناء الماء.
  static Future<CelestialRiver> build() async {
    final water = await loadGroundTexture(kRiverWaterTexture);
    if (water == null) {
      debugPrint('⚠️ $_kFallbackNote');
    }

    final river = CelestialRiver._();
    final inlets = river._planInlets();
    river
      .._buildWater(water)
      .._buildWetEdges()
      .._buildKerbs(inlets)
      .._buildMainFall(water)
      .._buildPlungePool(water)
      .._buildEdgeFall(water)
      .._buildFords()
      .._buildInlets(water, inlets)
      .._buildFoam(inlets);
    river._updateFoam(0);
    debugPrint(
      '🌊 celestial river ready (${river._route.length.toStringAsFixed(1)} u)',
    );
    return river;
  }

  /// يُحرّك خامات الماء والشلال والرغوة. [seconds] ثوانٍ منذ بدء المشهد.
  void update(double seconds) {
    for (final scroll in _scrolls) {
      final shift = (seconds * scroll.speed) % 1.0;
      final array = scroll.attribute.array;
      final base = scroll.base;
      for (var i = 0; i < base.length; i++) {
        array[i] = i.isOdd ? base[i] - shift : base[i];
      }
      scroll.attribute.needsUpdate = true;
    }
    _updateFoam(seconds);
  }

  // ===========================================================================
  // ١. الماء والضفتان
  // ===========================================================================

  void _buildWater(three.Texture? map) {
    final rows = <List<double>>[];
    final uvs = <List<double>>[];
    for (final sample in _route.samples) {
      final hw = _route.halfWidthAt(sample.s);
      final v = sample.s / _kWaterVTile;
      // العمود ٠ = +الناظم، العمود ١ = −الناظم. هذا الترتيب هو ما يعطي
      // `[a,b,c, b,d,c]` ناظمًا لأعلى (انظر القاعدة ١ في رأس الملف).
      rows.add(<double>[
        sample.x + sample.nx * hw,
        kCelestialRiverWaterY,
        sample.z + sample.nz * hw,
        sample.x - sample.nx * hw,
        kCelestialRiverWaterY,
        sample.z - sample.nz * hw,
      ]);
      uvs.add(<double>[0.0, v, 1.18, v]);
    }
    group.add(
      _mesh(rows, uvs, _waterMaterial(map), flip: false, scroll: _kWaterScroll),
    );
  }

  /// شريط الحافة المبلَّلة: ٠٫٣٥ خارج الماء بانخفاض ٤ سم، يخفي حدّ الشريط.
  void _buildWetEdges() {
    final material = three.MeshPhongMaterial({
      "color": 0x1F403C,
      "emissive": 0x06100E,
      "specular": 0x3E6E66,
      "shininess": 26,
      "flatShading": false,
    });

    for (final side in const <double>[1.0, -1.0]) {
      final rows = <List<double>>[];
      final uvs = <List<double>>[];
      for (final sample in _route.samples) {
        final hw = _route.halfWidthAt(sample.s);
        // صف واحد بعمودين (الداخلي ثم الخارجي). بناء صفّين بعمود واحد
        // يترك `_mesh` بلا مثلثات، ويفشل أثناء بناء الشبكة.
        final inner = hw;
        final outer = hw + kCelestialRiverBedEdge;
        rows.add(<double>[
          sample.x + sample.nx * inner * side,
          kCelestialRiverBedY,
          sample.z + sample.nz * inner * side,
          sample.x + sample.nx * outer * side,
          kCelestialRiverBedY,
          sample.z + sample.nz * outer * side,
        ]);
        final v = sample.s / 3.0;
        uvs.add(<double>[0.0, v, 0.42, v]);
      }
      group.add(_mesh(rows, uvs, material, flip: side > 0));
    }
  }

  /// الجدار الحجري: داخلي ١٫٩٥ عند ٠٫٢٢ ← أعلى ٢٫٤٥ عند ٠٫٤٠ ← قدم ٢٫٦٢.
  ///
  /// القدم ينزل إلى −٠٫٨٥ لأن أرض الجزيرة ليست مستوية: المرج ≈ −٠٫٠٤ لكن
  /// حوض البحيرات ينزل إلى −٠٫٦، وقدم عند −٠٫٠٦ كان يترك الجدار معلّقًا في
  /// الفراغ عند المصبّين. الجزء الزائد مدفون حيث الأرض أعلى.
  void _buildKerbs(List<_InletPlan> inlets) {
    final material = three.MeshPhongMaterial({
      "color": 0xA9A491,
      "emissive": 0x0D0C08,
      "specular": 0x4A4A42,
      "shininess": 16,
      "flatShading": false,
    });

    for (final side in const <double>[1.0, -1.0]) {
      final rows = <List<double>>[];
      final uvs = <List<double>>[];
      for (final sample in _route.samples) {
        final hw = _route.halfWidthAt(sample.s);
        // الفتحة عند المصبّ: أعلى الجدار يهبط تحت سطح الماء ٠٫٢٦ (٠٫٢٤)
        // فيصبح فمًا ينسكب منه الماء بدل جدار يسدّه.
        final gap = _gapFactor(sample.s, side, inlets);
        final height =
            (kCelestialRiverKerbTopY - kCelestialRiverBedY) *
            math.max(0.05, _route.kerbFactorAt(sample.s) * gap);
        // صف واحد بثلاثة أعمدة: السرير المبلَّل ← أعلى الجدار ← القدم.
        final lateral = <double>[
          hw + kCelestialRiverBedEdge,
          hw + kCelestialRiverKerbTopEdge,
          hw + kCelestialRiverKerbFootEdge,
        ];
        final heights = <double>[
          kCelestialRiverBedY,
          kCelestialRiverBedY + height,
          kCelestialRiverKerbFootY,
        ];
        final row = <double>[];
        for (var i = 0; i < lateral.length; i++) {
          row
            ..add(sample.x + sample.nx * lateral[i] * side)
            ..add(heights[i])
            ..add(sample.z + sample.nz * lateral[i] * side);
        }
        rows.add(row);
        final v = sample.s / 2.5;
        uvs.add(<double>[0.0, v, 0.55, v, 1.0, v]);
      }
      group.add(_mesh(rows, uvs, material, flip: side > 0));
    }
  }

  /// معامل إغلاق الجدار على ضفة المصبّ: ٠٫٠٦ عند المركز و١ بعد ١٫٦ وحدة.
  double _gapFactor(double s, double side, List<_InletPlan> inlets) {
    var gap = 1.0;
    for (final inlet in inlets) {
      if (inlet.side != side) continue;
      final t = ((s - inlet.s).abs() / 1.6).clamp(0.0, 1.0);
      final local = 0.06 + 0.94 * t;
      if (local < gap) gap = local;
    }
    return gap;
  }

  // ===========================================================================
  // ٢. الشلالات
  // ===========================================================================

  /// شلال M15: جدول ١٨ صفًا × ٥ أعمدة مقيس فوق الصخر بخلوص ٠٫٢٢.
  void _buildMainFall(three.Texture? map) {
    final profile = kCelestialFallProfile;
    final columns = kCelestialFallColumns;
    final rows = <List<double>>[];
    final uvs = <List<double>>[];

    for (var i = 0; i < profile.length; i++) {
      final z = profile[i][0];
      final isLast = i == profile.length - 1;
      // الصف الأول (أعلى الشلال) يُطمر ٠٫٥ تحت سطح الصخر المقيس: بلا ذلك
      // تظهر حافة الشلال قصّةً مستديرة معلّقة في الهواء (شوهدت 2026-11-19).
      // الطمر يجعل الماء يخرج من شقّ في الصخر بخط التقاء طبيعي، والجدول
      // المقيس نفسه لا يُعدَّل.
      final isCrest = i == 0;
      // صفٌّ واحد لكل z يحمل **الأعمدة الخمسة** ([x,y,z] × ٥). إضافة صفّ لكل
      // عمود تجعل `_mesh` يرى عمودًا واحدًا فلا يبني أي مثلث (خطأ 2026-11-19).
      final row = <double>[];
      final uvRow = <double>[];
      for (var c = 0; c < columns.length; c++) {
        // الصف الأخير يُنزل إلى ٠٫٢٤: سطح الماء ٠٫٢٦، والتطابق التام بين
        // السطحين ينتج z-fighting عند القدم.
        var y = isLast ? kCelestialFallMinY : profile[i][c + 1];
        if (isCrest) y -= _kFallCrestTuck;
        row
          ..add(columns[c])
          ..add(y)
          ..add(z);
        uvRow
          ..add(c / (columns.length - 1) * 1.45)
          ..add(i / (profile.length - 1) * 2.4);
      }
      rows.add(row);
      uvs.add(uvRow);
    }

    group.add(
      _mesh(
        rows,
        uvs,
        _fallMaterial(map, opacity: 0.9),
        flip: true,
        scroll: _kFallScroll,
      ),
    );
  }

  /// بركة استقبال دائرية عند قدم الشلال: تدفن وصلة الشريط في الصخر.
  void _buildPlungePool(three.Texture? map) {
    final mesh = three.Mesh(
      three.CircleGeometry(radius: kCelestialFallPlungeRadius, segments: 36),
      _waterMaterial(map, opacity: 0.92),
    );
    mesh.rotation.x = -three.Math.pi / 2;
    mesh.position.set(
      kCelestialFallFoot[0],
      kCelestialRiverWaterY - 0.007,
      kCelestialFallFoot[1],
    );
    group.add(mesh);
    _registerUv(mesh, speed: 0.11);
  }

  /// شلال حافة الجزيرة: ثلاث شرائح شفافة متدرجة + كتلتا سدّ عند الفجوة.
  void _buildEdgeFall(three.Texture? map) {
    final rows = kCelestialEdgeFall;
    for (var i = 0; i < rows.length - 1; i++) {
      final top = rows[i];
      final bottom = rows[i + 1];
      final quad = <List<double>>[
        <double>[30 - top[2], top[1], top[0], 30 + top[2], top[1], top[0]],
        <double>[
          30 - bottom[2],
          bottom[1],
          bottom[0],
          30 + bottom[2],
          bottom[1],
          bottom[0],
        ],
      ];
      final uvs = <List<double>>[
        <double>[0.0, 0.0, 1.2, 0.0],
        <double>[0.0, 1.5, 1.2, 1.5],
      ];
      group.add(
        _mesh(
          quad,
          uvs,
          _fallMaterial(map, opacity: 0.85 - i * 0.22),
          flip: true,
          scroll: _kFallScroll * (0.8 + i * 0.15),
        ),
      );
    }

    // كتلتان تسدّان الفراغ بين آخر الجدار والشلال: بدونها يُرى تحت الحافة.
    final plugMat = three.MeshPhongMaterial({
      "color": 0x9A9481,
      "emissive": 0x0B0A07,
      "specular": 0x3E3E36,
      "shininess": 14,
    });
    for (final side in const <double>[-1.75, 1.75]) {
      final plug = three.Mesh(three.BoxGeometry(0.35, 0.5, 0.9), plugMat);
      plug.position.set(30 + side, 0.05, 81.7);
      group.add(plug);
    }
  }

  // ===========================================================================
  // ٣. المخاضات والمصابّ
  // ===========================================================================

  /// ١٢ حجر عبور (٣ لكل مخاضة) فوق سطح الماء.
  void _buildFords() {
    final geometry = three.DodecahedronGeometry(0.45);
    final material = three.MeshPhongMaterial({
      "color": 0x9AA39C,
      "emissive": 0x0A0F0C,
      "specular": 0x44514B,
      "shininess": 24,
      "flatShading": true,
    });

    for (final ford in kCelestialFords) {
      final sample = _route.at(ford[0]);
      for (var j = -1; j <= 1; j++) {
        final lateral = j * 0.95;
        // إزاحة صغيرة على المماس تكسر صفّ الحجارة المنتظم.
        final along = j == 0 ? 0.05 : (j > 0 ? 0.22 : -0.18);
        final x = sample.x + sample.nx * lateral + sample.tx * along;
        final z = sample.z + sample.nz * lateral + sample.tz * along;
        final stone = three.Mesh(geometry, material);
        stone.position.set(x, kCelestialRiverWaterY + 0.02, z);
        stone.scale.set(1.35, 0.4, 1.05);
        stone.rotation.set(
          (_rng.nextDouble() - 0.5) * 0.4,
          _rng.nextDouble() * math.pi,
          (_rng.nextDouble() - 0.5) * 0.3,
        );
        group.add(stone);
      }
    }
  }

  /// المصبّان: قناة V عند ٠٫٢٦ تنحدر إلى شلال ٠٫٨١ ثم تنحدر إلى ماء البحيرة.
  ///
  /// أرض الحوض حول البحيرتين أخفض من المرج بـ٠٫٤–٠٫٦ (مقيس)، فالقناة تبدو
  /// معلّقة لو تركت عارية. لذلك يحيط بها **جداران حجريان** من u=١٫٩ إلى
  /// حافة الشلال، وقدمهما −٠٫٨٥ مدفون في الحوض.
  void _buildInlets(three.Texture? map, List<_InletPlan> inlets) {
    final bankMaterial = three.MeshPhongMaterial({
      "color": 0xA9A491,
      "emissive": 0x0D0C08,
      "specular": 0x4A4A42,
      "shininess": 16,
      "flatShading": false,
    });

    for (final inlet in inlets) {
      final shore = _kInletStart + inlet.shoreDistance;
      final water = _kInletStart + inlet.waterDistance;
      final sections = <List<double>>[
        // أول مقطع أخفض ٦ مم من ماء النهر: يختفي تحته في الوصلة بدل أن
        // يتقاطع معه في نفس المستوى.
        <double>[_kInletStart, kCelestialRiverWaterY - 0.006],
        <double>[2.2, kCelestialRiverWaterY],
        <double>[3.0, kCelestialRiverWaterY],
        <double>[shore, kCelestialRiverWaterY],
        <double>[shore + 0.18, _kInletFallLipY],
        <double>[water + 0.45, _kInletLakeY],
      ];

      final rows = <List<double>>[];
      final uvs = <List<double>>[];
      for (final section in sections) {
        final d = section[0];
        final y = section[1];
        final isFall = y <= _kInletFallLipY + 0.01;
        final vDeep = isFall
            ? math.max(_kInletLakeY, y - kCelestialInletEdgeDrop)
            : y - kCelestialInletEdgeDrop;
        final cx = inlet.sample.x + inlet.nx * d;
        final cz = inlet.sample.z + inlet.nz * d;
        // صف واحد بثلاثة أعمدة: ضفة ← وسط V ← ضفة.
        final row = <double>[];
        for (var c = -1; c <= 1; c++) {
          final edge = c == 0 ? vDeep : y;
          row
            ..add(cx + inlet.sample.tx * c * kCelestialInletHalfWidth)
            ..add(edge)
            ..add(cz + inlet.sample.tz * c * kCelestialInletHalfWidth);
        }
        rows.add(row);
        final v = d / 2.5;
        uvs.add(<double>[0.0, v, 0.5, v, 1.0, v]);
      }
      group.add(
        _mesh(
          rows,
          uvs,
          _waterMaterial(map),
          flip: false,
          scroll: _kWaterScroll,
        ),
      );

      // الجداران: يبدآن عند الجدار الحجري الرئيسي وينتهيان عند حافة الشلال.
      for (final side in const <double>[1.0, -1.0]) {
        final bankRows = <List<double>>[];
        final bankUvs = <List<double>>[];
        final bankTo = shore + 0.18;
        for (final d in <double>[_kInletBankStart, bankTo]) {
          final cx = inlet.sample.x + inlet.nx * d;
          final cz = inlet.sample.z + inlet.nz * d;
          // صف واحد بعمودين: الحرف الداخلي عند ٠٫٣٠ والقدم المدفون عند −٠٫٨٥.
          final row = <double>[];
          for (final p in <List<double>>[
            <double>[_kInletLipInner, _kInletLipY],
            <double>[_kInletLipOuter, _kInletFootY],
          ]) {
            row
              ..add(cx + inlet.sample.tx * p[0] * side)
              ..add(p[1])
              ..add(cz + inlet.sample.tz * p[0] * side);
          }
          bankRows.add(row);
          bankUvs.add(<double>[0.0, d, 0.3, d]);
        }
        // جانب +t خارجي ناظمه +t؛ الجانب الآخر يُعكس.
        group.add(_mesh(bankRows, bankUvs, bankMaterial, flip: side < 0));
      }
    }
  }

  List<_InletPlan> _planInlets() {
    final plans = <_InletPlan>[];
    for (final spec in kCelestialInlets) {
      final s = spec[0];
      final lake = kNatureLakes[spec[1].toInt()];
      final sample = _route.at(s);
      var nx = sample.nx;
      var nz = sample.nz;
      if ((lake[0] - sample.x) * nx + (lake[1] - sample.z) * nz < 0) {
        nx = -nx;
        nz = -nz;
      }

      final sx = sample.x + nx * _kInletStart;
      final sz = sample.z + nz * _kInletStart;
      double? rayTo(double radius) {
        final fx = sx - lake[0];
        final fz = sz - lake[1];
        final b = 2 * (fx * nx + fz * nz);
        final c = fx * fx + fz * fz - radius * radius;
        final disc = b * b - 4 * c;
        if (disc < 0) return null;
        final root = math.sqrt(disc);
        final first = (-b - root) / 2;
        final second = (-b + root) / 2;
        if (second <= 0) return null;
        return first > 0 ? first : second;
      }

      final shore = rayTo(lake[3]);
      final water = rayTo(lake[2]);
      if (shore == null || water == null) {
        debugPrint('⚠️ inlet at s=$s misses its lake; skipped');
        continue;
      }
      plans.add(
        _InletPlan(
          s: s,
          sample: sample,
          nx: nx,
          nz: nz,
          shoreDistance: shore,
          waterDistance: water,
          side: (nx * sample.nx + nz * sample.nz) >= 0 ? 1.0 : -1.0,
        ),
      );
    }
    return plans;
  }

  // ===========================================================================
  // ٤. الرغوة
  // ===========================================================================

  /// رغوة ساكنة مدمجة عند القدم والمصبّين وحافة الشلال + ٣٦ رباعية منجرفة.
  void _buildFoam(List<_InletPlan> inlets) {
    final positions = <double>[];
    final uvs = <double>[];
    final indices = <int>[];

    void patch(
      double cx,
      double cz,
      double y,
      double length,
      double width,
      double angle,
    ) {
      final dx = math.cos(angle) * length * 0.5;
      final dz = math.sin(angle) * length * 0.5;
      final ex = -math.sin(angle) * width * 0.5;
      final ez = math.cos(angle) * width * 0.5;
      final base = positions.length ~/ 3;
      for (final corner in <List<double>>[
        <double>[cx - dx - ex, y, cz - dz - ez],
        <double>[cx + dx - ex, y, cz + dz - ez],
        <double>[cx - dx + ex, y, cz - dz + ez],
        <double>[cx + dx + ex, y, cz + dz + ez],
      ]) {
        positions.addAll(corner);
      }
      uvs.addAll(const <double>[0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]);
      indices.addAll(<int>[
        base,
        base + 1,
        base + 2,
        base + 1,
        base + 3,
        base + 2,
      ]);
    }

    // بركة الاستقبال.
    for (var i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final radius = 0.45 + _rng.nextDouble() * 1.45;
      patch(
        kCelestialFallFoot[0] + math.cos(angle) * radius,
        kCelestialFallFoot[1] + math.sin(angle) * radius,
        kCelestialRiverWaterY + 0.006,
        0.45 + _rng.nextDouble() * 0.55,
        0.18 + _rng.nextDouble() * 0.16,
        angle + math.pi / 2,
      );
    }

    // حافة شلال الجزيرة.
    for (var i = 0; i < 6; i++) {
      patch(
        30 - 1.35 + _rng.nextDouble() * 2.7,
        80.6 + _rng.nextDouble() * 1.3,
        kCelestialRiverWaterY + 0.005,
        0.5 + _rng.nextDouble() * 0.5,
        0.16 + _rng.nextDouble() * 0.14,
        math.pi / 2,
      );
    }

    // رغوة عند حافة كل مصبّ.
    for (final inlet in inlets) {
      final d = _kInletStart + inlet.shoreDistance - 0.2;
      for (var i = 0; i < 3; i++) {
        final lat = -0.35 + i * 0.35;
        patch(
          inlet.sample.x + inlet.nx * d + inlet.sample.tx * lat,
          inlet.sample.z + inlet.nz * d + inlet.sample.tz * lat,
          kCelestialRiverWaterY + 0.006,
          0.4 + _rng.nextDouble() * 0.3,
          0.18,
          math.atan2(inlet.sample.tz, inlet.sample.tx),
        );
      }
    }

    final geometry = three.BufferGeometry();
    geometry.setAttribute(
      'position',
      three.Float32BufferAttribute(Float32Array.from(positions), 3),
    );
    geometry.setAttribute(
      'uv',
      three.Float32BufferAttribute(Float32Array.from(uvs), 2),
    );
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    group.add(
      three.Mesh(
        geometry,
        three.MeshBasicMaterial({
          "color": 0xE9FEFF,
          "transparent": true,
          "opacity": 0.5,
          "side": three.DoubleSide,
          "depthWrite": false,
        }),
      ),
    );

    // الرغوة المنجرفة: رباعيات صغيرة تجري مع التيار ثم تعود إلى البداية.
    final foamMaterial = three.MeshBasicMaterial({
      "color": 0xE9FEFF,
      "transparent": true,
      "opacity": 0.34,
      "side": three.DoubleSide,
      "depthWrite": false,
    });
    final foamGeometry = three.PlaneGeometry(1.0, 0.32);
    for (var i = 0; i < 36; i++) {
      final mesh = three.Mesh(foamGeometry, foamMaterial);
      mesh.rotation.x = -math.pi / 2;
      mesh.scale.set(
        0.7 + _rng.nextDouble() * 0.7,
        0.65 + _rng.nextDouble() * 0.55,
        1.0,
      );
      group.add(mesh);
      _foam.add(
        _FoamBit(
          mesh: mesh,
          s0: _rng.nextDouble() * _route.length,
          speed: 0.8 + _rng.nextDouble() * 0.8,
          lat: (_rng.nextDouble() * 2.4) - 1.2,
          wobble: 0.25 + _rng.nextDouble() * 0.35,
          phase: _rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  void _updateFoam(double seconds) {
    for (final bit in _foam) {
      final s = (bit.s0 + seconds * bit.speed) % _route.length;
      final sample = _route.at(s);
      final lat = bit.lat + math.sin(seconds * bit.wobble + bit.phase) * 0.16;
      bit.mesh.position.set(
        sample.x + sample.nx * lat,
        kCelestialRiverWaterY + 0.012,
        sample.z + sample.nz * lat,
      );
      // المستوي مرقد بـ rotation.x = −π/2، فدورانه في مستواه الأم = rotation.z.
      bit.mesh.rotation.z = math.atan2(-sample.tz, sample.tx);
    }
  }

  // ===========================================================================
  // ٥. المواد والأدوات
  // ===========================================================================

  three.MeshPhongMaterial _waterMaterial(
    three.Texture? map, {
    double opacity = 0.9,
  }) {
    final material = three.MeshPhongMaterial({
      "color": 0xFFFFFF,
      "emissive": 0x0C3542,
      "specular": 0xB9F1FF,
      "shininess": 150,
      "transparent": true,
      "opacity": opacity,
      "side": three.DoubleSide,
    });
    if (map != null) material.map = map;
    return material;
  }

  three.MeshPhongMaterial _fallMaterial(
    three.Texture? map, {
    double opacity = 0.9,
  }) {
    final material = three.MeshPhongMaterial({
      "color": 0xE6FBFF,
      "emissive": 0x174A57,
      "specular": 0xFFFFFF,
      "shininess": 90,
      "transparent": true,
      "opacity": opacity,
      "side": three.DoubleSide,
    });
    if (map != null) material.map = map;
    return material;
  }

  /// شبكة من صفوف متتالية، كل صف قائمة ذرى مسطّحة `[x,y,z, ...]`.
  ///
  /// [flip] يقلب الالتفاف. القاعدة: إذا كان ترتيب الأعمدة يجري في اتجاه
  /// **زيادة** الإحداثي الجانبي (من الداخل إلى الخارج) على الضفة اليمنى،
  /// فالالتفاف معكوس عن شريط الماء. (مشتق مرة واحدة ومُتحقَّق بالعين.)
  three.Mesh _mesh(
    List<List<double>> rows,
    List<List<double>> uvs,
    three.Material material, {
    bool flip = false,
    double? scroll,
  }) {
    final columns = rows.first.length ~/ 3;
    final positions = <double>[];
    final flatUvs = <double>[];
    for (var i = 0; i < rows.length; i++) {
      positions.addAll(rows[i]);
      flatUvs.addAll(uvs[i]);
    }

    final indices = <int>[];
    for (var i = 0; i < rows.length - 1; i++) {
      for (var j = 0; j < columns - 1; j++) {
        final a = i * columns + j;
        final b = a + 1;
        final c = (i + 1) * columns + j;
        final d = c + 1;
        if (flip) {
          indices.addAll(<int>[a, c, b, b, c, d]);
        } else {
          indices.addAll(<int>[a, b, c, b, d, c]);
        }
      }
    }

    final geometry = three.BufferGeometry();
    final positionAttribute = three.Float32BufferAttribute(
      Float32Array.from(positions),
      3,
    );
    final uvAttribute = three.Float32BufferAttribute(
      Float32Array.from(flatUvs),
      2,
    );
    geometry
      ..setAttribute('position', positionAttribute)
      ..setAttribute('uv', uvAttribute)
      ..setIndex(indices)
      ..computeVertexNormals();

    if (scroll != null) {
      _scrolls.add(_UvScroll(uvAttribute, List<double>.of(flatUvs), scroll));
    }
    return three.Mesh(geometry, material);
  }

  /// يسجّل خامة شبكة جاهزة (البركة) في قائمة التحريك.
  void _registerUv(three.Mesh mesh, {required double speed}) {
    final attribute = mesh.geometry?.getAttribute('uv');
    if (attribute is! three.BufferAttribute) return;
    final base = attribute.array
        .toDartList()
        .map((num v) => v.toDouble())
        .toList();
    _scrolls.add(_UvScroll(attribute, base, speed));
  }
}

/// خامة تتحرك على طول v. `shift` يُطرح من v فيسير النمط نحو الأمام.
class _UvScroll {
  _UvScroll(this.attribute, this.base, this.speed);

  final three.BufferAttribute attribute;
  final List<double> base;
  final double speed;
}

/// رقعة رغوة منجرفة: موضعها يُعاد حسابه من طول المسار كل إطار.
class _FoamBit {
  _FoamBit({
    required this.mesh,
    required this.s0,
    required this.speed,
    required this.lat,
    required this.wobble,
    required this.phase,
  });

  final three.Mesh mesh;
  final double s0;
  final double speed;
  final double lat;
  final double wobble;
  final double phase;
}

/// مصبّ محسوب: موضعه على المسار ومسافاته إلى ضفة البحيرة ومائها.
class _InletPlan {
  _InletPlan({
    required this.s,
    required this.sample,
    required this.nx,
    required this.nz,
    required this.shoreDistance,
    required this.waterDistance,
    required this.side,
  });

  final double s;
  final CelestialRiverSample sample;
  final double nx;
  final double nz;

  /// من نقطة البداية (على بعد ١٫٥٥ من خط المنتصف) إلى حدّ الضفة.
  final double shoreDistance;

  /// من نقطة البداية إلى حدّ الماء.
  final double waterDistance;

  /// ضفة النهر التي يخرج منها المصبّ: +١ لجانب الناظم، −١ للمقابل.
  final double side;
}
