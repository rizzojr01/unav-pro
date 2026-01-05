import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sense/core/network/api_client.dart';
import 'package:smart_sense/core/services/storage_service.dart';
import 'package:smart_sense/core/utils/logger.dart';
import 'package:smart_sense/core/constants/app_constants.dart';
import 'package:smart_sense/theme/theme_bloc.dart';

// Camera
import 'package:smart_sense/features/camera/data/datasources/camera_local_datasource.dart';
import 'package:smart_sense/features/camera/data/datasources/camera_remote_datasource.dart';
import 'package:smart_sense/features/camera/data/repositories/camera_repository_impl.dart';
import 'package:smart_sense/features/camera/domain/repositories/camera_repository.dart';
import 'package:smart_sense/features/camera/domain/usecases/capture_photo_usecase.dart';
import 'package:smart_sense/features/camera/domain/usecases/upload_photo_usecase.dart';
import 'package:smart_sense/features/camera/presentation/bloc/camera_bloc.dart';

// Destination
import 'package:smart_sense/features/destination/data/datasources/destination_remote_datasource.dart';
import 'package:smart_sense/features/destination/data/repositories/destination_repository_impl.dart';
import 'package:smart_sense/features/destination/domain/repositories/destination_repository.dart';
import 'package:smart_sense/features/destination/domain/usecases/search_destinations_usecase.dart';
import 'package:smart_sense/features/destination/domain/usecases/select_destination_usecase.dart';
import 'package:smart_sense/features/destination/presentation/bloc/destination_bloc.dart';

// Navigation
import 'package:smart_sense/features/navigation/data/datasources/navigation_local_datasource.dart';
import 'package:smart_sense/features/navigation/data/datasources/navigation_remote_datasource.dart';
import 'package:smart_sense/features/navigation/data/repositories/navigation_repository_impl.dart';
import 'package:smart_sense/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:smart_sense/features/navigation/domain/usecases/get_current_location_usecase.dart';
import 'package:smart_sense/features/navigation/domain/usecases/get_route_usecase.dart';
import 'package:smart_sense/features/navigation/domain/usecases/watch_location_usecase.dart';
import 'package:smart_sense/features/navigation/presentation/bloc/navigation_bloc.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Core
  getIt.registerLazySingleton<AppLogger>(() => AppLogger());
  getIt.registerLazySingleton<StorageService>(() => StorageService(getIt()));
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: AppConstants.baseUrl, logger: getIt()),
  );

  // Camera Feature
  getIt.registerLazySingleton<CameraLocalDataSource>(
    () => CameraLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<CameraRemoteDataSource>(
    () => CameraRemoteDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<CameraRepository>(
    () => CameraRepositoryImpl(
      localDataSource: getIt(),
      remoteDataSource: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => CapturePhotoUseCase(getIt()));
  getIt.registerLazySingleton(() => UploadPhotoUseCase(getIt()));
  getIt.registerFactory(
    () => CameraBloc(capturePhotoUseCase: getIt(), uploadPhotoUseCase: getIt()),
  );

  // Destination Feature
  getIt.registerLazySingleton<DestinationRemoteDataSource>(
    () => DestinationRemoteDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<DestinationRepository>(
    () => DestinationRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerLazySingleton(() => SearchDestinationsUseCase(getIt()));
  getIt.registerLazySingleton(() => SelectDestinationUseCase(getIt()));
  getIt.registerFactory(
    () => DestinationBloc(
      searchDestinationsUseCase: getIt(),
      selectDestinationUseCase: getIt(),
    ),
  );

  // Navigation Feature
  getIt.registerLazySingleton<NavigationLocalDataSource>(
    () => NavigationLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<NavigationRemoteDataSource>(
    () => NavigationRemoteDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<NavigationRepository>(
    () => NavigationRepositoryImpl(
      localDataSource: getIt(),
      remoteDataSource: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => GetCurrentLocationUseCase(getIt()));
  getIt.registerLazySingleton(() => GetRouteUseCase(getIt()));
  getIt.registerLazySingleton(() => WatchLocationUseCase(getIt()));
  getIt.registerFactory(
    () => NavigationBloc(
      getCurrentLocationUseCase: getIt(),
      getRouteUseCase: getIt(),
      watchLocationUseCase: getIt(),
    ),
  );

  // Theme
  getIt.registerLazySingleton<ThemeBloc>(() => ThemeBloc(getIt()));
}
