import 'package:flutter_gl_flutterflow/flutter_gl.dart' show Uint8Array;
import 'package:three_dart_flutterflow/three_dart.dart' as three;

import 'texture_pixels.dart'
    if (dart.library.io) 'texture_pixels_io.dart'
    if (dart.library.html) 'texture_pixels_web.dart';

/// Replaces every texture of [root] with one that carries raw RGBA pixels.
///
/// The loader wraps the platform's own image — a browser `HTMLImageElement`,
/// or the bytes of a decoded picture on a device — in a plain `Texture`. For a
/// plain texture three_dart uploads through a path that reads `image.data`,
/// so the GL layer was handed something it cannot read as pixels and ended up
/// with an incomplete texture. WebGL samples those as opaque black, which is
/// exactly how every model arrived on screen: a black silhouette.
///
/// A `DataTexture` uploads through the sized path instead, and that one writes
/// a byte array on both platforms. So the pixels are decoded once here, the
/// sampling settings are carried over, and the material points at the new
/// texture. Instances cloned from this model share it.
///
/// Returns how many textures were converted.
int makeTexturesUploadable(three.Object3D root) {
  final replaced = Map<three.Texture, three.Texture>.identity();
  var converted = 0;

  root.traverse((child) {
    if (child is! three.Mesh) return;
    final materials = child.material is List
        ? child.material as List
        : [child.material];

    for (final mat in materials) {
      if (mat == null) continue;

      final texture = mat.map as three.Texture?;
      if (texture == null) continue;

      final existing = replaced[texture];
      if (existing != null) {
        mat.map = existing;
        mat.needsUpdate = true;
        continue;
      }

      final pixels = decodeTexturePixels(texture.image);
      if (pixels == null) continue;

      final copy =
          three.DataTexture(
              Uint8Array.from(pixels.rgba),
              pixels.width,
              pixels.height,
              three.RGBAFormat,
              three.UnsignedByteType,
            )
            ..name = texture.name
            ..wrapS = texture.wrapS
            ..wrapT = texture.wrapT
            ..magFilter = texture.magFilter
            // No mip chain: the uploader allocates the levels through
            // `texStorage2D` but only ever fills level 0, and WebGL zero-fills
            // the rest. Anything drawn smaller than its texture — which is every
            // tree in this garden — samples a black, fully transparent mip and
            // the cutout throws it away. A single-level texture samples the
            // pixels we actually uploaded.
            ..minFilter = three.LinearFilter
            ..anisotropy = texture.anisotropy
            ..encoding = texture.encoding
            ..generateMipmaps = false
            // three_dart's DataTexture omits the `needsUpdate = true` that
            // three.js sets in its own constructor. Without it `version` stays
            // zero, the renderer never uploads the texture, and every model
            // samples an incomplete texture and draws black — no matter how
            // correct the pixels we just decoded are.
            ..needsUpdate = true;

      replaced[texture] = copy;
      mat.map = copy;
      mat.needsUpdate = true;
      converted++;
    }
  });

  return converted;
}
