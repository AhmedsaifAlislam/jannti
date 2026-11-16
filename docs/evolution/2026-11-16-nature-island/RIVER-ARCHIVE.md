# أرشيف: المرج المتدرّج والنهر (٢٠٢٦-١١-١٦)

**الحالة:** مُزال من المشهد، محفوظ هنا للرجوع.

استُبدلت الأرض المسطّحة ذات النهر المحفور بجزيرة `PP_FreeLowPolyForest_v3.0`
كاملة (جبال + بحيرتان + ممرات + مرج). النهر لم يعد موجودًا: الماء الآن بحيرتان
من المشهد المرجعي. هذا الملف يحفظ الكود القديم كاملًا في حال احتجنا نهرًا
متعرّجًا مرة أخرى، أو احتجنا فكرة منه (شريط يتبع منحنى، رقعة رغوة تنساب).

كل ما هنا كان في `lib/screens/jannati_3d_screen.dart` قبل الحذف.

---

## ١. الثوابت

```dart
static const double _kGroundW = 280.0;
static const double _kGroundD = 180.0;

// ---- النهر: قناة منحنية لا شريط مستقيم ----
static const double _kRiverHalfWidth = 15.0;   // نصف عرض القناة
static const double _kRiverBedY = -1.75;       // قاع القناة المحفور
static const double _kRiverWaterY = 0.05;      // سطح الماء (العمق ~1.8)
static const double _kRiverClearance = 25.0;   // مسافة الإبعاد عن خط المنتصف
```

`_kGroundW` / `_kGroundD` بقيا في الملف: قشرة الجزيرة والجزر الطافية ما زالتا
تقرأهما.

---

## ٢. مسار النهر وارتفاع الأرض

```dart
  /// مركز النهر عند [z]: مسار متعرّج لا خط مستقيم.
  ///
  /// موجتان: الأولى تعطي الانحناءة الكبرى (سعة ١٧٫٥ على طول ٢٩٠ وحدة ≈
  /// تعرّج كامل واحد)، والثانية تلتوية صغيرة (سعة ٦) تكسر الانتظام.
  double _riverCenterX(double z) =>
      17.5 * sin(z * 0.0216) + 6.0 * sin(z * 0.058 + 1.9);

  /// ارتفاع سطح المرج (بلا الهضبة) عند ([x]، [z]).
  ///
  /// ثلاثة أقنعة تتضاعف:
  /// - **موجات التلال** — ثلاث موجات بأطوال مختلفة، مجموعها ±‎٣٫٩ نظريًا
  ///   و±‎٢٫٥ عمليًا.
  /// - **قناع الحدّ** — يصفر عند حدود ١٤٠×٩٠ كي تلتحم الحلقة العليا لقشرة
  ///   الجزيرة (y = 0) بالأرض بلا فراغ ولا درجة.
  /// - **قناع الضفة** — يصفر عند حافة القناة، فتنزل التلال إلى الماء بشاطئ
  ///   منحدر لا بجدار عمودي.
  double _terrainHeight(double x, double z) {
    final river = (x - _riverCenterX(z)).abs();
    if (river < _kRiverHalfWidth) return _kRiverBedY;

    final h =
        4.4 * sin(x * 0.019 + 0.7) * cos(z * 0.024 - 0.4) +
        2.3 * sin(x * 0.0455 - 1.1) * sin(z * 0.0362 + 2.2) +
        0.9 * sin(x * 0.093 + 2.4) * cos(z * 0.081 + 0.6);

    final edge = min(
      ((140.0 - x.abs()) / 10.0).clamp(0.0, 1.0).toDouble(),
      ((90.0 - z.abs()) / 10.0).clamp(0.0, 1.0).toDouble(),
    );
    final bank = ((river - _kRiverHalfWidth) / 9.0).clamp(0.0, 1.0).toDouble();

    return h * edge * bank;
  }

  /// ما يقف عليه اللاعب/الموديل: الهضبة إن كان داخلها، وإلا سطح المرج.
  double _calculateGroundElevation(double x, double z) {
    final dx = (x - _kPlateauX) / _kPlateauRadiusX;
    final dz = (z - _kPlateauZ) / _kPlateauRadiusZ;
    if (dx * dx + dz * dz < 1.0) return _kPlateauHeight;
    return _terrainHeight(x, z);
  }

  /// هل تقع النقطة في ماء النهر (لا على ضفته)؟
  bool _isInRiver(double x, double z) =>
      (x - _riverCenterX(z)).abs() < _kRiverClearance;
```

---

## ٣. شريط يتبع المنحنى (`_riverRibbon`)

```dart
  /// شريط يتبع خط منتصف النهر.
  ///
  /// [offsets] مسافات أفقية من المركز (كلها سالبة أو كلها موجبة لضفة واحدة)،
  /// و[heightAt] ارتفاع كل نقطة. الماء والقاع والحصى والضفتان كلها أشرطة
  /// بنفس الدالة، فتبقى متلاصقة مهما انحنى المسار.
  three.Mesh _riverRibbon({
    required List<double> offsets,
    required double Function(double x, double z) heightAt,
    required three.Material material,
    required double uSpan,
    required double vTile,
    int samples = 140,
  }) {
    final positions = <double>[];
    final uvs = <double>[];
    final indices = <int>[];
    final cols = offsets.length;

    for (var i = 0; i < samples; i++) {
      final z = -_kGroundD / 2 + _kGroundD * i / (samples - 1);
      final cx = _riverCenterX(z);
      for (var j = 0; j < cols; j++) {
        final x = cx + offsets[j];
        positions.addAll([x, heightAt(x, z), z]);
        uvs.addAll([uSpan * j / (cols - 1), z / vTile]);
      }
    }

    for (var i = 0; i < samples - 1; i++) {
      for (var j = 0; j < cols - 1; j++) {
        final a = i * cols + j;
        final b = a + 1;
        final c = (i + 1) * cols + j;
        final d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
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
    return three.Mesh(geometry, material);
  }
```

---

## ٤. أشرطة حصى الضفتين (كانت في نهاية `_buildRollingMeadow`)

```dart
    // حصى الضفتين: شريطان يتبعان انحناء النهر وارتفاع الأرض، بارتفاع ٢ سم
    // فوق العشب حتى لا يتزاحم السطحان.
    parent.add(
      _riverRibbon(
        offsets: const [-22.5, -20.0, -17.5, -15.2, -13.2],
        heightAt: (x, z) => _terrainHeight(x, z) + 0.02,
        material: bankMat,
        uSpan: 1.2,
        vTile: 10.0,
      ),
    );
    parent.add(
      _riverRibbon(
        offsets: const [13.2, 15.2, 17.5, 20.0, 22.5],
        heightAt: (x, z) => _terrainHeight(x, z) + 0.02,
        material: bankMat,
        uSpan: 1.2,
        vTile: 10.0,
      ),
    );
```

---

## ٥. الماء والرغوة والحصى (`_buildRiverAndFeatures`)

```dart
  void _buildRiverAndFeatures() {
    // 1. ماء النهر: شريط يتبع الانحناء بدل مستطيل ٣٠×١٨٤ مستقيم.
    final waterMat = three.MeshPhongMaterial({
      // الخامة نفسها زرقاء باردة، والتيل هنا يخفّضها إلى عمق ماء النهر.
      "color": 0x9FBCCB,
      "emissive": 0x0A2030,
      "specular": 0x9CBAC6,
      // لمعان ضيّق: بلمعان ٧٠ كان انعكاس الشمس يغسل الجزء القريب من النهر.
      "shininess": 140,
      "transparent": true,
      // أقل عتامة = عمق حقيقي: قاع النهر والحصى يظهران تحت السطح.
      "opacity": 0.82,
      "side": three.DoubleSide,
    });
    _waterMat = waterMat;
    _waterMesh = _riverRibbon(
      offsets: const [-15.6, 15.6],
      heightAt: (x, z) => _kRiverWaterY,
      material: waterMat,
      uSpan: 2,
      // مربع الخامة ~١٥×١٣ وحدة (٣١÷٢، ١٨٤÷١٤) كما كان.
      vTile: 13.0,
    );
    _scene.add(_waterMesh!);

    // 2. رقاع الرغوة المنسابة
    _riverRipples.clear();
    _riverRippleOffsets.clear();
    final rippleMat = three.MeshBasicMaterial({
      "color": 0xE0F7FA,
      "transparent": true,
      "opacity": 0.45,
      "side": three.DoubleSide,
    });

    for (int r = 0; r < 24; r++) {
      final rGeo = three.PlaneGeometry(2.5 + _rng.nextDouble() * 4.0, 0.35);
      final ripple = three.Mesh(rGeo, rippleMat);
      ripple.rotation.x = -three.Math.pi / 2;
      final rz = (_rng.nextDouble() * _kGroundD) - (_kGroundD / 2);
      final off = (_rng.nextDouble() * 16.0) - 8.0;
      // الرغوة تسبح على سطح الماء نفسه لا فوق مركز النهر القديم.
      ripple.position.set(_riverCenterX(rz) + off, _kRiverWaterY + 0.03, rz);
      _riverRipples.add(ripple);
      _riverRippleOffsets.add(off);
      _scene.add(ripple);
    }

    // 3. قاع النهر الفحمي المزرق
    final bedMat = three.MeshPhongMaterial({
      "color": 0x16232E,
      "side": three.DoubleSide,
    });
    _scene.add(
      _riverRibbon(
        offsets: const [-14.6, 14.6],
        heightAt: (x, z) => _kRiverBedY + 0.08,
        material: bedMat,
        uSpan: 1,
        vTile: 10.0,
      ),
    );

    // 4. حصى القاع
    _buildRiverPebbles();

    // 5. الجسر الحجري
    _buildStoneBridge();

    // 6. زنابق الماء
    _buildWaterLilies();
  }

  void _buildRiverPebbles() {
    final stoneColors = [0x607D8B, 0x455A64, 0x795548, 0x90A4AE, 0x8D6E63];

    for (int i = 0; i < 45; i++) {
      final z = (_rng.nextDouble() * _kGroundD * 0.8) - (_kGroundD * 0.4);
      final x = _riverCenterX(z) + ((_rng.nextDouble() * 18.0) - 9.0);
      final cMat = three.MeshPhongMaterial({
        "color": stoneColors[i % stoneColors.length],
        "shininess": 25,
        "flatShading": true,
      });

      final size = 0.6 + _rng.nextDouble() * 0.9;
      final stone = three.Mesh(three.DodecahedronGeometry(size), cMat);
      stone.position.set(x, _kRiverBedY + 0.14 + size * 0.3, z);
      stone.scale.set(1.3, 0.6, 1.2);
      stone.rotation.set(
        _rng.nextDouble() * 3,
        _rng.nextDouble() * 3,
        _rng.nextDouble() * 3,
      );
      _scene.add(stone);
    }
  }
```

`_buildWaterLilies` ما زالت في الملف: أُعيد توزيعها على البحيرتين عند
`kNatureWaterY`.

---

## ٦. حركة الماء في حلقة الرسم

```dart
    // 2. Dynamic River Wave & Flow Current
    if (_waterMesh != null) {
      _waterMesh!.position.y = 0.03 * sin(_frameCount * 0.04);
    }
    for (int r = 0; r < _riverRipples.length; r++) {
      final rip = _riverRipples[r];
      rip.position.z += 0.08; // Flows downstream
      if (rip.position.z > (_kGroundD / 2)) {
        rip.position.z = -(_kGroundD / 2);
      }
      // تتبع انحناء القناة: x محسوب من المنحنى + إزاحتها الثابتة.
      rip.position.x =
          _riverCenterX(rip.position.z) +
          (r < _riverRippleOffsets.length ? _riverRippleOffsets[r] : 0.0);
    }
```

---

## ٧. الحقول التي كانت تحمل الحالة

```dart
three.Mesh? _waterMesh;
final List<three.Mesh> _riverRipples = [];
final List<double> _riverRippleOffsets = [];
three.MeshPhongMaterial? _waterMat;
```

---

## ٨. كيف نُعيده

1. أعِد الثوابت الأربعة ودالتي `_riverCenterX` و`_terrainHeight`.
2. أعِد `_riverRibbon` و`_buildRiverAndFeatures` و`_buildRiverPebbles` والحقول.
3. في `_calculateGroundElevation`: بدّل `return 0.0;` بـ
   `return _terrainHeight(x, z);` — أو ادمج النهر في أرض الجزيرة عبر تعديل
   `_terrainHeight` لتقرأ ارتفاع المرج الجديد (صفر) وتطرح القناة فقط.
4. قواعد الزرع: بدّل `_isInLake`/`_isOnMountain` بـ`_isInRiver`، والحدود
   المستطيلة `_kPlantHalfWidth/Depth` بحدود الأرض الجديدة.
5. أضِف `_buildRiverAndFeatures()` بعد `_buildSculptedTerrain()` في `initPage`،
   وأعِد كتلة الحركة في `animate()`.

**تحذير:** الأرض الجديدة ليست مستوية عند الصفر تمامًا (بلاطات المرج تتذبذب
±٠٫٢)، فالماء عند `_kRiverWaterY = 0.05` سيبدو أعلى من بعض الحواف. أي إعادة
تفعيل تحتاج قياس ارتفاع البلاطات أولًا أو دفن الماء قليلًا.
