import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// Target height, in world units, of each growth stage.
///
/// A model is scaled so its own height matches the stage, which keeps a palm
/// and a tree of the same tier the same size even though the source files are
/// modelled at wildly different scales.
double tierHeight(int tier) {
  switch (tier) {
    case 1:
      return 7;
    case 2:
      return 9;
    case 3:
      return 11;
    case 4:
      return 14;
    case 5:
      return 18;
    default:
      return 10;
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
