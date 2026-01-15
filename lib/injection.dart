import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sense/core/network/api_client.dart';
import 'package:smart_sense/core/services/storage_service.dart';
import 'package:smart_sense/core/utils/logger.dart';
import 'package:smart_sense/core/constants/api_routes.dart';
import 'package:smart_sense/theme/theme_bloc.dart';

// Shared
import 'package:smart_sense/shared/services/location_config_service.dart';
import 'package:smart_sense/shared/services/floor_plan_cache_service.dart';
import 'package:smart_sense/shared/services/destinations_cache_service.dart';
import 'package:smart_sense/shared/services/debug_config_service.dart';
import 'package:smart_sense/shared/services/recent_destinations_service.dart';
import 'package:smart_sense/shared/data/datasources/place_remote_datasource.dart';
import 'package:smart_sense/shared/presentation/bloc/location_settings_bloc.dart';

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
import 'package:smart_sense/features/navigation/domain/usecases/get_route_usecase.dart';
import 'package:smart_sense/features/navigation/presentation/bloc/navigation_bloc.dart';

// Locate Me
import 'package:smart_sense/features/locate_me/data/datasources/locate_me_remote_datasource.dart';
import 'package:smart_sense/features/locate_me/data/repositories/locate_me_repository_impl.dart';
import 'package:smart_sense/features/locate_me/domain/repositories/locate_me_repository.dart';
import 'package:smart_sense/features/locate_me/domain/usecases/get_floor_plan_usecase.dart';
import 'package:smart_sense/features/locate_me/domain/usecases/localize_user_usecase.dart';
import 'package:smart_sense/features/locate_me/domain/usecases/get_destinations_usecase.dart';
import 'package:smart_sense/features/locate_me/presentation/bloc/locate_me_bloc.dart';

// Auth
import 'package:smart_sense/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:smart_sense/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:smart_sense/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:smart_sense/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_sense/features/auth/domain/usecases/login_usecase.dart';
import 'package:smart_sense/features/auth/domain/usecases/signup_usecase.dart';
import 'package:smart_sense/features/auth/domain/usecases/logout_usecase.dart';
import 'package:smart_sense/features/auth/presentation/bloc/auth_bloc.dart';

// Profile
import 'package:smart_sense/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:smart_sense/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:smart_sense/features/profile/domain/repositories/profile_repository.dart';
import 'package:smart_sense/features/profile/domain/usecases/get_me_usecase.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Core
  getIt.registerLazySingleton<AppLogger>(() => AppLogger());
  getIt.registerLazySingleton<StorageService>(() => StorageService(getIt()));
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: ApiRoutes.baseUrl, logger: getIt()),
  );

  // Shared Services
  getIt.registerLazySingleton<LocationConfigService>(
    () => LocationConfigService(getIt()),
  );
  getIt.registerLazySingleton<FloorPlanCacheService>(
    () => FloorPlanCacheService(getIt()),
  );
  getIt.registerLazySingleton<DestinationsCacheService>(
    () => DestinationsCacheService(getIt()),
  );
  getIt.registerLazySingleton<DebugConfigService>(
    () => DebugConfigService(getIt()),
  );
  getIt.registerLazySingleton<RecentDestinationsService>(
    () => RecentDestinationsService(getIt()),
  );
  getIt.registerLazySingleton<PlaceRemoteDataSource>(
    () => PlaceRemoteDataSourceImpl(getIt()),
  );
  getIt.registerFactory(
    () => LocationSettingsBloc(
      placeRemoteDataSource: getIt(),
      locationConfigService: getIt(),
      floorPlanCacheService: getIt(),
      destinationsCacheService: getIt(),
    ),
  );

  // Auth Feature
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () =>
        AuthRepositoryImpl(remoteDataSource: getIt(), localDataSource: getIt()),
  );
  getIt.registerLazySingleton(() => LoginUseCase(getIt()));
  getIt.registerLazySingleton(() => SignupUseCase(getIt()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt()));

  // Profile Feature
  getIt.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      remoteDataSource: getIt(),
      authLocalDataSource: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => GetMeUseCase(getIt()));

  getIt.registerFactory(
    () => AuthBloc(
      loginUseCase: getIt(),
      signupUseCase: getIt(),
      getMeUseCase: getIt(),
      logoutUseCase: getIt(),
    ),
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
    () => DestinationRemoteDataSourceImpl(
      getIt(),
      getIt<LocationConfigService>(),
    ),
  );
  getIt.registerLazySingleton<DestinationRepository>(
    () => DestinationRepositoryImpl(
      remoteDataSource: getIt(),
      destinationsCacheService: getIt(),
      locationConfigService: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => SearchDestinationsUseCase(getIt()));
  getIt.registerLazySingleton(() => SelectDestinationUseCase(getIt()));
  getIt.registerFactory(
    () => DestinationBloc(
      searchDestinationsUseCase: getIt(),
      selectDestinationUseCase: getIt(),
      recentDestinationsService: getIt(),
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
  getIt.registerLazySingleton(() => GetRouteUseCase(getIt()));
  getIt.registerFactory(
    () => NavigationBloc(
      getRouteUseCase: getIt(),
      getFloorPlanUseCase: getIt(),
      locationConfigService: getIt(),
      floorPlanCacheService: getIt(),
      debugConfigService: getIt(),
    ),
  );

  // Locate Me Feature
  getIt.registerLazySingleton<LocateMeRemoteDataSource>(
    () => LocateMeRemoteDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<LocateMeRepository>(
    () => LocateMeRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerLazySingleton(() => GetFloorPlanUseCase(getIt()));
  getIt.registerLazySingleton(() => LocalizeUserUseCase(getIt()));
  getIt.registerLazySingleton(() => GetDestinationsUseCase(getIt()));
  getIt.registerFactory(
    () => LocateMeBloc(
      getFloorPlanUseCase: getIt(),
      localizeUserUseCase: getIt(),
      getDestinationsUseCase: getIt(),
      locationConfigService: getIt(),
      floorPlanCacheService: getIt(),
      destinationsCacheService: getIt(),
    ),
  );

  // Theme
  getIt.registerLazySingleton<ThemeBloc>(() => ThemeBloc(getIt()));
}
