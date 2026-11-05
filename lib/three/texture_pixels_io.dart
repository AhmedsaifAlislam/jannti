import 'package:image/image.dart' as img;
import 'package:three_dart_flutterflow/three_dart.dart' as three;

import 'texture_pixels.dart';

/// Device decoder.
///
/// The glTF loader already turns the PNG into a `package:image` picture and
/// then into raw bytes, so usually the pixels only need copying out of the GL
/// wrapper. A caller that hands over the picture itself is decoded here.
///
/// No flip is applied: the glTF loader decodes with `flipY` off, and glTF puts
/// v = 0 on the first row of the file, which is the first row of the buffer.
TexturePixels? decodeTexturePixels(dynamic image) {
  if (image is three.ImageElement) {
    final data = image.data;
    if (data is img.Image) {
      return _fromImage(data);
    }
    return texturePixelsFromBytes(data, image.width, image.height);
  }

  if (image is img.Image) {
    return _fromImage(image);
  }

  return null;
}

TexturePixels? _fromImage(img.Image image) {
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0) return null;

  final rgba = image.getBytes();
  if (rgba.length != width * height * 4) return null;

  return TexturePixels(width, height, rgba);
}
