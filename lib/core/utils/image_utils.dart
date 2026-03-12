import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Compresses and resizes an image before converting it to Base64.
  ///
  /// This helps prevent 'Connection reset' errors caused by sending massive
  /// raw high-res photos to the backend.
  static Future<String> compressAndEncodeImage(
    String filePath, {
    int? maxWidth,
    int? maxHeight,
    int quality = 100,
  }) async {
    final File imageFile = File(filePath);
    if (!await imageFile.exists()) {
      return '';
    }

    final Uint8List bytes = await imageFile.readAsBytes();

    // Decode the image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return '';

    // Resize if needed
    if (maxWidth != null || maxHeight != null) {
      image = img.copyResize(
        image,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // Encode to JPEG with specified quality
    final Uint8List compressedBytes = Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );

    return base64Encode(compressedBytes);
  }
}
