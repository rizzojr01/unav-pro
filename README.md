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

## 🚀 Deploy to TestFlight

### Prerequisites

1. **Apple Developer Account** - $99/year enrollment at [developer.apple.com](https://developer.apple.com)
2. **Xcode** - Latest version from Mac App Store
3. **CocoaPods** - Run `sudo gem install cocoapods`
4. **Flutter** - Installed and configured

---

### Step 1: Configure iOS Project in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your team in **Signing & Capabilities**:
   - Click on `Runner` in the project navigator
   - Go to **Signing & Capabilities** tab
   - Check "Automatically manage signing"
   - Select your Apple Developer Team from the dropdown
3. Verify the **Bundle Identifier** is unique (e.g., `com.yourcompany.pathlogic`)
4. Set the **Deployment Target** (iOS 12.0 or higher recommended)

---

### Step 2: Create App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Click **My Apps** → **+** → **New App**
4. Fill in the details:
   - **Platform**: iOS
   - **Name**: PathLogic
   - **Bundle ID**: Select your bundle identifier from Step 1
   - **SKU**: Unique identifier (e.g., `pathlogic001`)
   - **User Access**: Full access
5. Click **Create**

---

### Step 3: Build iOS App for Simulator

Before building for TestFlight, test on simulator:

```bash
cd /Users/surendharpalanisamy/Desktop/Freelance/taggedWeb/flutter-object-detection/smartsense-app
flutter build ios --simulator --no-codesign
```

---

### Step 4: Build iOS App for TestFlight

1. **Set Flutter to release mode**:
   ```bash
   flutter build ios --release
   ```

2. Or build with specific configuration:
   ```bash
   flutter build ipa --release
   ```

3. The build output will be in `build/ios/iphoneos/` (if `--release`) or you can find the `.ipa` file after the build completes.

---

### Step 5: Upload Build to App Store Connect

**Option A: Using Xcode (Recommended)**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to **Product** → **Archive**
3. Wait for the build to complete
4. In the Organizer window, click **Distribute App**
5. Select **App Store Connect** → **Upload**
6. Follow the prompts:
   - Select your team
   - Choose "Automatically manage signing"
   - Review and upload

**Option B: Using Transporter App**

1. Download **Transporter** from Mac App Store
2. Sign in with your Apple Developer account
3. Click **+** and select your `.ipa` or `.xcarchive` file
4. Click **Deliver**

---

### Step 6: Wait for Build Processing

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Navigate to your app → **TestFlight** tab
3. Wait for the build to appear (may take 10-30 minutes)
4. Build status should change from "Processing" to "Ready to Test"

---

### Step 7: Add Testers

**Internal Testers** (Your Team):
1. Go to **App Store Connect** → **Users and Access**
2. Invite team members with access

**External Testers**:
1. Go to your app → **TestFlight** → **External Testing**
2. Click **+** to create a new test
3. Add tester emails or use a public link:
   - Under **Test Information**, enable **Public Link**
   - Copy the link and share with testers
4. Add build to the test

---

### Step 8: Test on Device

1. Install **TestFlight** from App Store on your iOS device
2. Sign in with the Apple ID used for testing
3. Find PathLogic and tap **Install**
4. Open the app and test

---

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails with signing error | Check Bundle ID matches App Store Connect |
| No builds appearing in TestFlight | Wait for processing or check for compliance issues |
| "Build has one or more issues" | Check for missing permissions or invalid entitlements |
| Transporter upload fails | Ensure you have proper App Store Connect permissions |

---

### Quick Commands Summary

```bash
# Test on simulator
flutter build ios --simulator --no-codesign

# Build for TestFlight
flutter build ios --release

# Or build IPA
flutter build ipa --release

# Clean and rebuild
flutter clean
flutter pub get
flutter build ios --release
```

---

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
