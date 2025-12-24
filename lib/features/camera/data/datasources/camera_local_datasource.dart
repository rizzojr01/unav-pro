import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../models/photo_model.dart';

abstract class CameraLocalDataSource {
  Future<PhotoModel> capturePhoto();
}

class CameraLocalDataSourceImpl implements CameraLocalDataSource {
  CameraController? _cameraController;
  final Uuid _uuid = const Uuid();

  @override
  Future<PhotoModel> capturePhoto() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw AppException('No cameras available');
      }

      // Initialize camera controller
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Capture image
      final XFile image = await _cameraController!.takePicture();

      // Get app directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${_uuid.v4()}.jpg';
      final filePath = '${directory.path}/$fileName';

      // Copy file to app directory
      await File(image.path).copy(filePath);

      // Dispose controller
      await _cameraController!.dispose();

      return PhotoModel(
        id: _uuid.v4(),
        filePath: filePath,
        timestamp: DateTime.now(),
      );
    } on PermissionException {
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Failed to capture photo: $e');
    }
  }
}
