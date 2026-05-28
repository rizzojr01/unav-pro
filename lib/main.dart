import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_sense/app.dart';
import 'package:smart_sense/core/constants/api_routes.dart';
import 'package:smart_sense/injection.dart';
import 'package:smart_sense/core/utils/logger.dart';
import 'package:smart_sense/shared/services/fcm_service.dart';
import 'package:smart_sense/shared/services/location_config_service.dart';
import 'package:smart_sense/shared/services/map_download_service.dart';

import 'package:smart_sense/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pass all unhandled errors from the framework to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Pass all errors outside of Flutter framework to Crashlytics.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize dependencies
  await initializeDependencies();

  // Initialize FCM (get token + start listening for data messages)
  // FCM is non-critical — app should still work without push notifications
  try {
    await getIt<FcmService>().init();
  } catch (e) {
    getIt<AppLogger>().error('FCM initialization failed', error: e);
  }

  // Pre-download floor plan images for the current building in the background.
  // This populates the FloorPlanCacheService so navigation works without
  // per-floor API calls. Runs fire-and-forget — won't block app startup.
  _syncMapsInBackground();

  runApp(const App());
}

/// Fire-and-forget map sync. Downloads all floor maps for the currently
/// configured building using the catalog API and caches them locally.
void _syncMapsInBackground() {
  final config = getIt<LocationConfigService>();
  final downloadService = getIt<MapDownloadService>();

  downloadService
      .syncMapsForBuilding(
    place: config.place,
    building: config.building,
    baseUrl: ApiRoutes.baseUrl,
    force: false, // Don't clear cache on startup; just download missing maps
  )
      .then((result) {
    if (result.success) {
      print(
        '[MapSync] Downloaded ${result.downloadedFloors.length} floors '
        'for ${config.building}',
      );
    } else {
      print('[MapSync] Failed: ${result.errorMessage}');
    }
  }).catchError((e) {
    print('[MapSync] Error: $e');
    return null;
  });
}
