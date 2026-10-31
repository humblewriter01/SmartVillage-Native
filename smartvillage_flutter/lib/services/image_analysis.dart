import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Simple RGBA bitmap container used by the offline computer-vision services.
///
/// The React blueprint decoded images with an HTML `<canvas>`; on Flutter we
/// use `dart:ui` to decode into raw RGBA bytes, which gives identical pixels
/// without any third-party image package.
class RgbaImage {
  RgbaImage({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes; // RGBA8888

  int get pixelCount => width * height;

  int r(int x, int y) => bytes[(y * width + x) * 4];

  int g(int x, int y) => bytes[(y * width + x) * 4 + 1];

  int b(int x, int y) => bytes[(y * width + x) * 4 + 2];

  double brightness(int x, int y) => (r(x, y) + g(x, y) + b(x, y)) / 3.0;
}

class ImageAnalyzer {
  const ImageAnalyzer._();

  /// Decodes [bytes] and rescales to [size] x [size] like the web version
  /// (`ctx.drawImage(img, 0, 0, 224, 224)`).
  static Future<RgbaImage?> decode(
    Uint8List bytes, {
    int size = 224,
  }) async {
    if (bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size,
        targetHeight: size,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();
      if (byteData == null) return null;
      return RgbaImage(
        width: width,
        height: height,
        bytes: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
    } catch (error) {
      debugPrint('[ImageAnalyzer] decode failed: $error');
      return null;
    }
  }
}

/// Pixel ratios consumed by the crop disease heuristic.
class ImageMetrics {
  const ImageMetrics({
    required this.greenRatio,
    required this.rustRatio,
    required this.purpleRatio,
    required this.yellowRatio,
    required this.darkRatio,
  });

  final double greenRatio;
  final double rustRatio;
  final double purpleRatio;
  final double yellowRatio;
  final double darkRatio;

  static const ImageMetrics empty = ImageMetrics(
    greenRatio: 0,
    rustRatio: 0,
    purpleRatio: 0,
    yellowRatio: 0,
    darkRatio: 0,
  );

  @override
  String toString() => 'green=${greenRatio.toStringAsFixed(2)} '
      'rust=${rustRatio.toStringAsFixed(2)} '
      'purple=${purpleRatio.toStringAsFixed(2)} '
      'yellow=${yellowRatio.toStringAsFixed(2)} '
      'dark=${darkRatio.toStringAsFixed(2)}';
}
