import '../../../../core/base/base_datasource.dart';
import '../models/photo_model.dart';

abstract class CameraRemoteDataSource {
  Future<bool> uploadPhoto(PhotoModel photo);
}

class CameraRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CameraRemoteDataSource {
  CameraRemoteDataSourceImpl(super.apiClient);

  @override
  Future<bool> uploadPhoto(PhotoModel photo) async {
    // TODO: Uncomment when backend is ready
    // return executeCall<bool>(() async {
    //   final file = File(photo.filePath);
    //   final fileName = file.path.split('/').last;
    //
    //   final formData = FormData.fromMap({
    //     'photo': await MultipartFile.fromFile(
    //       photo.filePath,
    //       filename: fileName,
    //     ),
    //     'id': photo.id,
    //     'timestamp': photo.timestamp.toIso8601String(),
    //   });
    //
    //   await post(ApiRoutes.uploadPhoto, data: formData);
    //   return true;
    // }, errorMessage: 'Failed to upload photo');

    // Mock implementation - simulate upload delay
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
