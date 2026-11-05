import 'dart:typed_data';

import 'package:flutter_gl_flutterflow/flutter_gl.dart' show Uint8Array;

/// Raw pixels of a decoded model texture: four channels per pixel, top row
/// first.
class TexturePixels {
  const TexturePixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;
}

/// Wraps bytes the loader already decoded, when they are the right size.
///
/// Both plants hand three_dart the pixels through a `Uint8Array`, but only one
/// of them says how wide the picture is, so the dimensions come from the
/// surrounding `ImageElement` and are checked against the buffer here.
TexturePixels? texturePixelsFromBytes(dynamic data, int width, int height) {
  if (data is! Uint8Array) return null;
  if (width <= 0 || height <= 0) return null;

  final expected = width * height * 4;
  if (data.length != expected) return null;

  return TexturePixels(width, height, Uint8List.fromList(data.toDartList()));
}

/// Decodes the image a texture currently holds into raw pixels.
///
/// The default implementation knows nothing, so a platform without a decoder
/// simply leaves the texture as it found it.
TexturePixels? decodeTexturePixels(dynamic image) => null;
