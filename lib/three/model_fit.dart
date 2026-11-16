import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// Target height, in world units, of each growth stage.
///
/// A model is scaled so its own height matches the stage, which keeps a palm
/// and a tree of the same tier the same size even though the source files are
/// modelled at wildly different scales.
///
/// One unit is roughly one metre: the marble bridge has a 1.2-thick deck, a
/// 7.5-wide walkway and 3.3-high lanterns, so a person standing on it would be
/// about 1.7. The meadow grass is 0.35–0.70 high. Tier 1 is **0.6**: a single
/// reward is a sprout inside the grass, not a tree. A completed block of ten is
/// lifted back up to ~1.5 by [modelInstanceHeight], so the jump from nine
/// seedlings to the first grown model is what the player actually notices.
/// Later stages keep a clear, readable jump: a mature palm reaches 9 units,
/// roughly the height of a real date palm.
///
/// **القاعدة: الترقية لا تُقصّر الموديل.** أقصر موديل في مرتبة يجب أن يتجاوز
/// أطول موديل في المرتبة السابقة بنحو ٢٠٪ على الأقل، وإلا بدا النمو تراجعًا
/// (تير ١ الذهبي = ١٫٨٣ وكان تير ٢ = ٢٫٠، أي +٩٪ فقط). أي تعديل هنا يحرسه
/// `test/model_fit_test.dart` ← «سلّم الأحجام لا ينكمش عند الترقية».
double tierHeight(int tier) {
  switch (tier) {
    case 1:
      return 0.6;
    case 2:
      return 2.3;
    case 3:
      return 3.4;
    case 4:
      return 5.5;
    case 5:
      return 9.0;
    default:
      return 3.4;
  }
}

/// كم يُدفن الموديل تحت سطح الأرض، كنسبة من ارتفاعه.
///
/// ملفات النخيل تحمل قاعدتها العشبية داخلها. قياس توزيع الرؤوس يقول إن هذه
/// القاعدة تشغل **٥٧٪** من ارتفاع `palm_seedling`، و١٥–٢٣٪ من بقية المراتب.
/// عند الجلوس على y = 0 تظهر القاعدة كاملة فوق المرج، فتبدو الشتلة «عشبًا
/// بطول الموديل» لا نخلة نابتة. دفن معظم القاعدة يُبقي طرفًا رقيقًا عند خط
/// الأرض فقط. الشجر يبدأ بجذع لا بعشب، فيُدفن أقل بقليل لإخفاء قطع القاعدة.
const List<double> kPalmGroundSink = <double>[0.40, 0.16, 0.13, 0.13, 0.15];
const double kTreeGroundSink = 0.10;

/// عمق الدفن بالوحدات العالمية لموديل ارتفاعه [height].
double modelGroundSink({
  required bool isPalm,
  required int tier,
  required double height,
}) {
  if (height <= 0) return 0;
  final fraction = isPalm
      ? kPalmGroundSink[tier.clamp(1, kPalmGroundSink.length) - 1]
      : kTreeGroundSink;
  return height * fraction;
}

/// How much taller a *completed* tier-1 model stands over one seedling.
///
/// Tier 1 is the only tier that draws several models of the same type at once:
/// a sprout for every reward that has not merged yet, plus a model for each
/// completed block of ten. Both share `tierHeight(1)`, so without this lift the
/// block of ten (0.6 × 1.05) looked exactly like the nine sprouts next to it and
/// the merge was invisible. The lift stops under the 2.3 of tier 2, so a
/// promotion still never goes backwards.
const List<double> kTier1StageLift = <double>[1.0, 2.3, 2.7];

/// Height of one model instance, in world units, given its stage and extra
/// scale. Every tier except the first grows through [tierHeight] alone; tier 1
/// also lifts a completed block so it reads as a tree, not a bigger seedling.
double modelInstanceHeight(int tier, int stage, double scaleMultiplier) {
  final base = tierHeight(tier) * scaleMultiplier;
  if (tier != 1) return base;
  final lift = kTier1StageLift[stage.clamp(0, kTier1StageLift.length - 1)];
  return base * lift;
}

/// Narrows 32-bit index buffers to 16 bits so the model can be duplicated.
///
/// `Mesh.clone()` clones the geometry, and `BufferAttribute.clone()` in
/// three_dart only knows `Float32`, `Uint8` and `Uint16` — anything else throws
/// `BufferAttribute type: … clone need support`. The exports index with 32-bit
/// values, so the scene cached a model and then failed on `scene.clone(true)`,
/// leaving the procedural mesh on screen with no visible error.
///
/// Every model we ship indexes at most a few thousand vertices, so 16 bits is
/// lossless — and `setIndex` picks the narrowest buffer itself. A model that
/// genuinely needs more than 65535 indices is left untouched rather than
/// corrupted; it simply keeps the procedural mesh.
void makeModelCloneable(three.Object3D root) {
  try {
    root.traverse((child) {
      if (child is! three.Mesh) return;
      final geometry = child.geometry;
      if (geometry == null) return;

      final index = geometry.index;
      if (index == null || index.type != 'Uint32BufferAttribute') return;

      final count = index.count;
      final values = List<int>.generate(
        count,
        (i) => index.array[i].toInt(),
        growable: false,
      );
      final maxIndex = values.isEmpty
          ? 0
          : values.reduce((a, b) => a > b ? a : b);
      if (maxIndex > 65535) return;

      geometry.setIndex(values);
    });
  } catch (_) {
    // Nothing here is worth losing a model over; the worst case is that the
    // clone fails and the scene keeps the mesh it already has.
  }
}

/// Scales [obj] to [targetHeight] and seats it on its own origin.
///
/// Idempotent: calling it again on an already-fitted model re-measures the
/// current world height and multiplies the existing scale, so the result is
/// exactly [targetHeight] whether the model is fresh or came out of the cache.
///
/// The exports do not share a pivot. Some models, like the house, sit on
/// y = 0; the palms hang well below it, the mature one reaching y = -2.6 before
/// any scaling. Scaling alone therefore buries half the garden in the ground,
/// and an off-centre pivot makes a rotating tree orbit instead of turning in
/// place. So after scaling the model is re-measured and moved so its base
/// rests on y = 0 and its footprint is centred on x = z = 0.
///
/// [sink] lowers the model by that many world units *after* the base is placed
/// at y = 0, so part of its own root/grass base sits inside the terrain. The
/// measured height is unaffected, which keeps the call idempotent: the next
/// call re-seats the base at 0 and applies the same sink once.
///
/// The rotation and translation of [obj] itself are not affected by its own
/// scale, which is why the box is measured in the parent's space and the
/// result can be subtracted straight from `position`.
void fitModelToGround(
  three.Object3D obj,
  double targetHeight, {
  double sink = 0,
}) {
  try {
    obj.updateMatrixWorld(true);
    final box = three.Box3().setFromObject(obj);
    final size = box.getSize(three.Vector3());
    final height = size.y.abs();
    if (height > 0.001) {
      // نضرب المقياس القائم بدل استبداله: النسخة قد تكون خرجت من الكاش
      // مضبوطة أصلًا، والارتفاع المقيس يشمل ذلك الضبط. `scale.set(s)` هنا
      // كان يمحو الضبط السابق فيرتد الموديل إلى حجمه الأصلي (نخلة الشتلة
      // 10.74 وحدة!) بدل 0.6.
      obj.scale.multiplyScalar(targetHeight / height);
    }

    obj.updateMatrixWorld(true);
    final fitted = three.Box3().setFromObject(obj);
    final minY = fitted.min.y;
    final cx = (fitted.min.x + fitted.max.x) / 2;
    final cz = (fitted.min.z + fitted.max.z) / 2;
    if (!minY.isFinite || !cx.isFinite || !cz.isFinite) return;

    obj.position.y -= minY + sink;
    obj.position.x -= cx;
    obj.position.z -= cz;
  } catch (_) {
    // A malformed bounding box must not take the scene down; the model is
    // still usable, just possibly mis-seated.
  }
}
