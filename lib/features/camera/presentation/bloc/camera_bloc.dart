import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/base/usecase.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/usecases/capture_photo_usecase.dart';
import '../../domain/usecases/upload_photo_usecase.dart';
import 'camera_event.dart';
import 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final CapturePhotoUseCase capturePhotoUseCase;
  final UploadPhotoUseCase uploadPhotoUseCase;

  CameraBloc({
    required this.capturePhotoUseCase,
    required this.uploadPhotoUseCase,
  }) : super(const CameraInitial()) {
    on<InitializeCameraEvent>(_onInitializeCamera);
    on<CapturePhotoEvent>(_onCapturePhoto);
    on<UploadPhotoEvent>(_onUploadPhoto);
  }

  Future<void> _onInitializeCamera(
    InitializeCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    emit(const CameraReady());
  }

  Future<void> _onCapturePhoto(
    CapturePhotoEvent event,
    Emitter<CameraState> emit,
  ) async {
    emit(const CameraCapturing());

    // If a file path is provided from the UI camera controller, use it directly
    if (event.filePath != null && event.filePath!.isNotEmpty) {
      final photo = PhotoEntity(
        entityId: 'photo-${DateTime.now().millisecondsSinceEpoch}',
        filePath: event.filePath!,
        timestamp: DateTime.now(),
      );
      emit(
        CameraPhotoCaptured(
          photo,
          floor: event.floor,
          heading: event.heading,
          capturedArPose: event.capturedArPose,
        ),
      );
      return;
    }

    // Fallback to use case (mock or separate camera initialization)
    final result = await capturePhotoUseCase(const NoParams());

    result.fold(
      (failure) => emit(CameraError(failure.message)),
      (photo) => emit(
        CameraPhotoCaptured(
          photo,
          floor: event.floor,
          heading: event.heading,
          capturedArPose: event.capturedArPose,
        ),
      ),
    );
  }

  Future<void> _onUploadPhoto(
    UploadPhotoEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraPhotoCaptured) return;

    final photo = (state as CameraPhotoCaptured).photo;
    emit(CameraUploading(photo));

    final result = await uploadPhotoUseCase(photo);

    result.fold(
      (failure) => emit(CameraError(failure.message)),
      (_) => emit(CameraPhotoUploaded(photo)),
    );
  }
}
