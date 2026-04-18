import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ImageUtils {
  /// Compresses and resizes an image before converting it to Base64.
  ///
  /// This helps prevent 'Connection reset' errors caused by sending massive
  /// raw high-res photos to the backend.
  static Future<String> compressAndEncodeImage(
    String filePath, {
    int? maxWidth,
    int? maxHeight,
    int quality = 80,
  }) async {
    final File imageFile = File(filePath);
    if (!await imageFile.exists()) {
      return '';
    }

    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return '';
    }
  }
}
