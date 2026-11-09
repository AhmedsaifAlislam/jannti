import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// Target height, in world units, of each growth stage.
///
/// A model is scaled so its own height matches the stage, which keeps a palm
/// and a tree of the same tier the same size even though the source files are
/// modelled at wildly different scales.
///
/// One unit is roughly one metre: the marble bridge has a 1.2-thick deck, a
/// 7.5-wide walkway and 3.3-high lanterns, so a person standing on it would be
/// about 1.7. The first ladder (7 / 9 / 11 / 14 / 18) therefore made the
/// *seedling* files — tier 1 is a nursery sapling — seven metres tall, which
/// is what made every new planting dwarf the bridge and the river. The stages
/// now follow the procedural seedlings they replace (the tier-1 palm is about
/// 2.4 units high before the GLB swap) and only the mature stages reach tree
/// size.
double tierHeight(int tier) {
  switch (tier) {
    case 1:
      return 3.0;
    case 2:
      return 4.2;
    case 3:
      return 6.0;
    case 4:
      return 9.0;
    case 5:
      return 13.0;
    default:
      return 7.0;
  }
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
/// The exports do not share a pivot. Some models, like the house, sit on
/// y = 0; the palms hang well below it, the mature one reaching y = -2.6 before
/// any scaling. Scaling alone therefore buries half the garden in the ground,
/// and an off-centre pivot makes a rotating tree orbit instead of turning in
/// place. So after scaling the model is re-measured and moved so its base
/// rests on y = 0 and its footprint is centred on x = z = 0.
///
/// The rotation and translation of [obj] itself are not affected by its own
/// scale, which is why the box is measured in the parent's space and the
/// result can be subtracted straight from `position`.
void fitModelToGround(three.Object3D obj, double targetHeight) {
  try {
    obj.updateMatrixWorld(true);
    final box = three.Box3().setFromObject(obj);
    final size = box.getSize(three.Vector3());
    final height = size.y.abs();
    if (height > 0.001) {
      final s = targetHeight / height;
      obj.scale.set(s, s, s);
    }

    obj.updateMatrixWorld(true);
    final fitted = three.Box3().setFromObject(obj);
    final minY = fitted.min.y;
    final cx = (fitted.min.x + fitted.max.x) / 2;
    final cz = (fitted.min.z + fitted.max.z) / 2;
    if (!minY.isFinite || !cx.isFinite || !cz.isFinite) return;

    obj.position.y -= minY;
    obj.position.x -= cx;
    obj.position.z -= cz;
  } catch (_) {
    // A malformed bounding box must not take the scene down; the model is
    // still usable, just possibly mis-seated.
  }
}
