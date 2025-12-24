# Smart Sense - Flutter Clean Architecture

A Flutter application built with Clean Architecture principles for capturing photos, selecting destinations, and navigating with real-time location tracking.

## 📋 Features

- **Photo Capture**: Capture photos using the device camera
- **Photo Upload**: Upload captured photos to a backend server
- **Destination Search**: Search and select destinations
- **Navigation**: Real-time navigation from current location to selected destination
- **Location Tracking**: Continuous location updates during navigation

## 🏗️ Architecture

This project follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── core/                          # Core functionality shared across features
│   ├── base/                      # Base classes for entities, use cases, etc.
│   ├── constants/                 # App-wide constants
│   ├── error/                     # Error handling (failures & exceptions)
│   ├── network/                   # Network client (Dio)
│   ├── services/                  # Core services (storage, etc.)
│   └── utils/                     # Utilities (logger, etc.)
│
├── features/                      # Feature modules
│   ├── camera/                    # Camera feature
│   │   ├── data/
│   │   │   ├── datasources/       # Local and remote data sources
│   │   │   ├── models/            # Data models
│   │   │   └── repositories/      # Repository implementations
│   │   ├── domain/
│   │   │   ├── entities/          # Business entities
│   │   │   ├── repositories/      # Repository interfaces
│   │   │   └── usecases/          # Business logic
│   │   └── presentation/
│   │       ├── bloc/              # BLoC state management
│   │       └── pages/             # UI pages
│   │
│   ├── destination/               # Destination selection feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── navigation/                # Navigation feature
│       ├── data/
│       ├── domain/
│       └── presentation/
│
├── routes/                        # App routing
│   └── app_router.dart            # Centralized routing logic
│
├── theme/                         # App theming
│   └── app_theme.dart
│
├── injection.dart                 # Dependency injection setup
├── app.dart                       # Main app widget
└── main.dart                      # App entry point
```

## 🎯 Clean Architecture Layers

### 1. **Domain Layer** (Business Logic)
- **Entities**: Pure Dart classes representing business objects
- **Repositories**: Abstract interfaces defining data operations
- **Use Cases**: Single-responsibility business logic units

### 2. **Data Layer** (Data Management)
- **Models**: Data transfer objects (DTOs) that extend entities
- **Data Sources**: Local (device) and remote (API) data access
- **Repository Implementations**: Concrete implementations of domain repositories

### 3. **Presentation Layer** (UI)
- **BLoC**: Business Logic Component for state management
- **Pages**: Screen-level widgets
- **Widgets**: Reusable UI components

## 📦 Dependencies

### State Management
- `flutter_bloc` - BLoC pattern implementation
- `equatable` - Value equality for entities and states

### Dependency Injection
- `get_it` - Service locator for dependency injection

### Networking
- `dio` - HTTP client for API calls

### Storage
- `shared_preferences` - Local key-value storage

### Functional Programming
- `dartz` - Either monad for error handling

### Device Features
- `camera` - Camera access and photo capture
- `geolocator` - Location services and tracking
- `path_provider` - Access to device directories

### Utilities
- `logger` - Structured logging
- `uuid` - Unique ID generation

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.10.4 or higher)
- Dart SDK
- Android Studio / Xcode for platform-specific builds

### Installation

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure API endpoint**
   Edit `lib/core/constants/app_constants.dart`:
   ```dart
   static const String baseUrl = 'https://your-api.com/api';
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 🔧 Configuration

### Android Setup

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS Setup

Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location for navigation</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location for navigation</string>
```

## 📱 App Flow

1. **Camera Screen** (`/`)
   - User captures a photo
   - Photo is uploaded to backend
   - Navigate to destination selection

2. **Destination Screen** (`/destination`)
   - User searches for destinations
   - Selects a destination
   - Navigate to navigation screen

3. **Navigation Screen** (`/navigation`)
   - Displays route from current location to destination
   - Shows distance and estimated time
   - Real-time location tracking during navigation

## 🧪 Testing

Run tests:
```bash
flutter test
```

Run with coverage:
```bash
flutter test --coverage
```

## 🏗️ Key Design Patterns

1. **Repository Pattern**: Abstraction layer between data sources and business logic
2. **Dependency Injection**: Loose coupling through GetIt service locator
3. **BLoC Pattern**: Predictable state management with events and states
4. **Use Case Pattern**: Single responsibility business logic units
5. **Either Pattern**: Functional error handling with dartz

## 🔐 Environment Variables

Create environment-specific configuration:

Run with environment:
```bash
flutter run --dart-define=BASE_URL=https://your-api.com/api
```

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [BLoC Pattern Documentation](https://bloclibrary.dev/)
- [Effective Dart Style Guide](https://dart.dev/guides/language/effective-dart)

## 🤝 Contributing

1. Follow the existing architecture pattern
2. Write tests for new features
3. Update documentation
4. Follow Effective Dart guidelines
5. Keep layers separate and dependencies pointing inward

## 📄 License

This project is licensed under the MIT License.
