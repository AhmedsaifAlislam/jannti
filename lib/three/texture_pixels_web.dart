// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:three_dart_flutterflow/three_dart.dart' as three;

import 'texture_pixels.dart';

/// Browser decoder.
///
/// The loader gives an `<img>` that has already decoded the PNG. Reading it
/// back through a 2D canvas is the only way to get at the pixels: a canvas is
/// transparent until something is drawn on it, so a failed draw leaves an
/// all-zero buffer rather than stale data.
///
/// No flip is applied. The rows come out top first, which is what glTF expects
/// and what the device path produces.
TexturePixels? decodeTexturePixels(dynamic image) {
  final source = image is three.ImageElement ? image.data : image;

  if (source is html.ImageElement) {
    final width = source.naturalWidth;
    final height = source.naturalHeight;
    if (width <= 0 || height <= 0) return null;

    final canvas = html.CanvasElement(width: width, height: height);
    final context = canvas.context2D..drawImage(source, 0, 0);
    final data = context.getImageData(0, 0, width, height).data;

    return TexturePixels(width, height, Uint8List.fromList(data));
  }

  if (source is html.CanvasElement) {
    final width = source.width ?? 0;
    final height = source.height ?? 0;
    if (width <= 0 || height <= 0) return null;

    final context = source.context2D;
    final data = context.getImageData(0, 0, width, height).data;
    return TexturePixels(width, height, Uint8List.fromList(data));
  }

  if (image is three.ImageElement) {
    return texturePixelsFromBytes(source, image.width, image.height);
  }

  return null;
}
