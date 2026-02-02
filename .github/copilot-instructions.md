# Smart Sense - Flutter Clean Architecture AI Assistant Guidelines

## Project Overview
Smart Sense is a Flutter navigation app built with Clean Architecture, featuring photo capture, destination search, and real-time navigation. Currently uses mock data with backend integration commented out.

## Architecture Patterns

### Clean Architecture Layers
- **Domain**: Entities, repositories (interfaces), use cases
- **Data**: Models (DTOs), datasources (local/remote), repository implementations  
- **Presentation**: BLoC state management, pages, widgets

### State Management (BLoC Pattern)
```dart
// Events extend Equatable
abstract class FeatureEvent extends Equatable {
  @override List<Object?> get props => [];
}

// States extend BaseState (which extends Equatable)
abstract class FeatureState extends BaseState {}
class FeatureInitial extends FeatureState {}
class FeatureLoading extends FeatureState {}
class FeatureSuccess extends FeatureState { /* data */ }
class FeatureError extends FeatureState { final String message; }
```

### Dependency Injection (GetIt)
- `getIt.registerLazySingleton<>()` for single instances
- `getIt.registerFactory<>()` for new instances per request
- All dependencies injected in `lib/injection.dart`

### Error Handling
- **Domain**: `Either<Failure, T>` with custom failures
- **Data**: Custom exceptions thrown, converted to failures in repositories
- **Presentation**: BLoC handles failures, emits error states

### Networking
- Dio client wrapped in `ApiClient`
- `BaseRemoteDataSource` provides `get()`, `post()`, `put()`, `delete()` helpers
- All API calls wrapped in `executeCall<T>()` for error handling

## Key Conventions

### File Structure
```
lib/features/feature_name/
├── data/
│   ├── datasources/          # feature_remote/local_datasource.dart
│   ├── models/              # feature_model.dart (extends entity)
│   └── repositories/        # feature_repository_impl.dart
├── domain/
│   ├── entities/            # feature_entity.dart
│   ├── repositories/        # feature_repository.dart (abstract)
│   └── usecases/            # feature_usecase.dart
└── presentation/
    ├── bloc/                # feature_bloc.dart, _event.dart, _state.dart
    └── pages/               # feature_page.dart
```

### Naming Patterns
- Classes: `PascalCase`
- Files: `snake_case.dart`
- Variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`

### Import Organization
```dart
import 'package:flutter/material.dart';
// External packages
import 'package:package_name/...';
// Project imports (relative paths)
import '../../../core/...';
import '../../domain/...';
```

## Development Workflow

### Setup
```bash
# Install Flutter version via FVM
fvm install 3.38.5
fvm use 3.38.5

# Install dependencies
flutter pub get

# Run app
flutter run
```

### Testing
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

### Code Quality
- `flutter analyze` for linting (flutter_lints package)
- Follow Effective Dart guidelines
- All layers must maintain separation (domain knows nothing about data/presentation)

## Current Implementation Notes

### Mock Data Usage
- Backend calls are commented out in datasources
- Data loaded from `assets/mock_data/` JSON files
- Uncomment API calls in datasources when backend ready

### Navigation Flow
- GoRouter with named routes in `lib/routes/app_router.dart`
- Pass data via `state.extra` (e.g., destination entities)

### Permissions
- Camera, location permissions configured in platform manifests
- Handle permission denials gracefully in BLoCs

### Developer Options
- Debug features accessible via Profile → Developer Options section
- Includes "Floor Map Testing" for interactive coordinate selection
- DebugConfigService manages debug settings with SharedPreferences

## Common Patterns

### Repository Implementation
```dart
class FeatureRepositoryImpl implements FeatureRepository {
  final FeatureRemoteDataSource remoteDataSource;
  final FeatureLocalDataSource localDataSource;

  @override
  Future<Either<Failure, T>> method() async {
    try {
      final result = await remoteDataSource.method();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
```

### BLoC Event Handling
```dart
@override
Stream<FeatureState> mapEventToState(FeatureEvent event) async* {
  if (event is FeatureRequested) {
    yield FeatureLoading();
    final result = await usecase(event.params);
    yield* result.fold(
      (failure) async* { yield FeatureError(failure.message); },
      (data) async* { yield FeatureSuccess(data); },
    );
  }
}
```

### Use Case Pattern
```dart
class FeatureUseCase implements UseCase<T, Params> {
  final FeatureRepository repository;

  @override
  Future<Either<Failure, T>> call(Params params) {
    return repository.method(params);
  }
}
```

## Integration Points

### External Services
- **Camera**: `camera` package for photo capture
- **Location**: `geolocator` for GPS tracking  
- **Storage**: `shared_preferences` for local persistence
- **Networking**: `dio` for HTTP requests

### Environment Configuration
- `.env` file loaded via `flutter_dotenv`
- API base URL in `lib/core/constants/api_routes.dart`

## Key Files to Reference
- `lib/injection.dart` - Dependency registration patterns
- `lib/core/base/base_datasource.dart` - API call patterns
- `lib/core/error/failures.dart` - Error handling types
- `lib/routes/app_router.dart` - Navigation setup
- `assets/mock_data/` - Current data structures