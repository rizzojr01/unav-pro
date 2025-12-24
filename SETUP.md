# Quick Setup Guide

## 📱 Platform Configuration

### Android Configuration

1. **Open** `android/app/src/main/AndroidManifest.xml`

2. **Add permissions** inside the `<manifest>` tag (before `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

3. **Update minimum SDK** in `android/app/build.gradle.kts`:
```kotlin
minSdk = 21
```

### iOS Configuration

1. **Open** `ios/Runner/Info.plist`

2. **Add permissions** before the closing `</dict>` tag:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture photos for navigation assistance</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to provide navigation directions</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to provide continuous navigation</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to provide navigation services</string>
```

## 🌐 Backend Configuration

### API Endpoint Setup

1. **Open** `lib/core/constants/app_constants.dart`

2. **Update the baseUrl**:
```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://your-actual-api.com/api', // Change this
);
```

### Expected API Endpoints

Your backend should implement these endpoints:

#### 1. Photo Upload
```
POST /photos/upload
Content-Type: multipart/form-data

Body:
- photo: File
- id: String
- timestamp: ISO8601 DateTime

Response: { "success": true, "message": "Photo uploaded" }
```

#### 2. Search Destinations
```
GET /destinations/search?q={query}

Response: {
  "data": [
    {
      "id": "string",
      "name": "string",
      "latitude": number,
      "longitude": number,
      "address": "string" (optional)
    }
  ]
}
```

#### 3. Get Route
```
POST /navigation/route
Content-Type: application/json

Body: {
  "origin": {
    "latitude": number,
    "longitude": number,
    "timestamp": ISO8601 DateTime
  },
  "destination": {
    "latitude": number,
    "longitude": number,
    "timestamp": ISO8601 DateTime
  }
}

Response: {
  "data": {
    "id": "string",
    "origin": { ... },
    "destination": { ... },
    "waypoints": [ { latitude, longitude, timestamp } ],
    "distanceInMeters": number,
    "durationInSeconds": number
  }
}
```

## 🚀 Running the App

### Development Mode

```bash
# Default backend URL
flutter run

# With custom backend URL
flutter run --dart-define=BASE_URL=https://staging-api.example.com/api

# With release mode
flutter run --release
```

### Building for Production

#### Android APK
```bash
flutter build apk --release --dart-define=BASE_URL=https://api.example.com/api
```

#### Android App Bundle
```bash
flutter build appbundle --release --dart-define=BASE_URL=https://api.example.com/api
```

#### iOS
```bash
flutter build ios --release --dart-define=BASE_URL=https://api.example.com/api
```

## 🧪 Testing Without Backend

For testing without a backend, you can modify the data sources to return mock data:

1. **Camera**: Already works offline (captures locally)
2. **Destination**: Mock data in `DestinationRemoteDataSourceImpl`
3. **Navigation**: Mock route calculation in `NavigationRemoteDataSourceImpl`

Example mock implementation:

```dart
// In destination_remote_datasource.dart
@override
Future<List<DestinationModel>> searchDestinations(String query) async {
  // Mock data for testing
  await Future.delayed(const Duration(seconds: 1));
  return [
    const DestinationModel(
      id: '1',
      name: 'Central Park',
      latitude: 40.785091,
      longitude: -73.968285,
      address: 'New York, NY 10024',
    ),
    // Add more mock destinations...
  ];
}
```

## 🔍 Debugging

### Enable Logging

The app uses the `logger` package. All logs are visible in the console:

- 🟢 **Debug**: General information
- 🔵 **Info**: Important events
- 🟡 **Warning**: Warnings
- 🔴 **Error**: Errors with stack traces

### Common Issues

1. **Camera not working**
   - Check permissions are added to AndroidManifest.xml / Info.plist
   - Grant camera permission when app asks

2. **Location not working**
   - Check location permissions
   - Enable location services on device
   - Make sure GPS is enabled

3. **Network errors**
   - Verify backend URL is correct
   - Check internet connection
   - Ensure backend is running and accessible

## 📦 Additional Tools

### Generate Icons
```bash
flutter pub add flutter_launcher_icons --dev
```

### Generate Splash Screen
```bash
flutter pub add flutter_native_splash --dev
```

### Code Generation (if adding JSON serialization)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🎨 Customization

### Update App Name
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`

### Update App Icon
Replace icons in:
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### Update Theme
Edit `lib/theme/app_theme.dart` to customize colors and styles.

## 💡 Tips

1. **Hot Reload**: Press `r` in terminal or use IDE hot reload button
2. **Hot Restart**: Press `R` or use IDE restart button
3. **DevTools**: Run `flutter pub global activate devtools` then `devtools`
4. **Widget Inspector**: Use Flutter Inspector in VS Code or Android Studio

## 📚 Next Steps

1. Implement actual map view (Google Maps / Mapbox)
2. Add authentication
3. Implement offline caching
4. Add unit and widget tests
5. Set up CI/CD pipeline
6. Add analytics and crash reporting

## ❓ Need Help?

- Check the [README.md](README.md) for architecture details
- Review code comments in individual files
- Consult Flutter documentation: https://flutter.dev/docs
- BLoC documentation: https://bloclibrary.dev/
