import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Photo capture helpers.
///
/// The in-app [CameraPreview] flow lives in
/// `widgets/camera_capture_screen.dart`; this service is the quick path used
/// by the "Gallery" and "Quick camera" buttons on the diagnosis screens.
class MediaService {
  MediaService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<Uint8List?> pickFromGallery({int maxWidth = 1024}) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        imageQuality: 88,
      );
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (error) {
      debugPrint('[MediaService] gallery pick failed: $error');
      return null;
    }
  }

  Future<Uint8List?> captureWithSystemCamera({int maxWidth = 1024}) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: maxWidth.toDouble(),
        imageQuality: 90,
      );
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (error) {
      debugPrint('[MediaService] camera capture failed: $error');
      return null;
    }
  }
}
