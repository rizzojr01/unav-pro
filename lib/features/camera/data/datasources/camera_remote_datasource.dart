import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/photo_model.dart';

abstract class CameraRemoteDataSource {
  Future<bool> uploadPhoto(PhotoModel photo);
}

class CameraRemoteDataSourceImpl implements CameraRemoteDataSource {
  final ApiClient apiClient;

  CameraRemoteDataSourceImpl(this.apiClient);

  @override
  Future<bool> uploadPhoto(PhotoModel photo) async {
    try {
      final file = File(photo.filePath);
      final fileName = file.path.split('/').last;

      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          photo.filePath,
          filename: fileName,
        ),
        'id': photo.id,
        'timestamp': photo.timestamp.toIso8601String(),
      });

      await apiClient.post('/photos/upload', data: formData);

      return true;
    } catch (e) {
      throw ServerException('Failed to upload photo: $e');
    }
  }
}
