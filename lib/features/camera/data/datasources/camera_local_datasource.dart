import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/base/base_datasource.dart';
import '../../../../core/error/exceptions.dart';
import '../models/photo_model.dart';

abstract class CameraLocalDataSource {
  Future<PhotoModel> capturePhoto();
}

class CameraLocalDataSourceImpl extends BaseLocalDataSource
    implements CameraLocalDataSource {
  CameraController? _cameraController;
  final Uuid _uuid = const Uuid();

  @override
  Future<PhotoModel> capturePhoto() async {
    return executeCall<PhotoModel>(() async {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw AppException('No cameras available');
      }

      // Initialize camera controller
      try {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
      } catch (_) {
        await _cameraController?.dispose();
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
      }

      // Capture image
      final XFile image = await _cameraController!.takePicture();

      // Get app directory
      final directory = await getApplicationDocumentsDirectory();
      final photoId = _uuid.v4();
      final fileName = '$photoId.jpg';
      final filePath = '${directory.path}/$fileName';

      // Copy file to app directory
      await File(image.path).copy(filePath);

      // Dispose controller
      await _cameraController!.dispose();

      return PhotoModel(
        entityId: photoId,
        filePath: filePath,
        timestamp: DateTime.now(),
      );
    }, errorMessage: 'Failed to capture photo');
  }
}
