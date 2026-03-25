import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCK7bIMDSEl-UDLIsz3A0fW5d8f5MI2Jmw',
    appId: '1:1063603108029:android:bc976422d0fd5350545fd4',
    messagingSenderId: '1063603108029',
    projectId: 'pathlogic-app',
    storageBucket: 'pathlogic-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDrSDgzXcapW1mrkIA1ajIZiwl5Um8UIuo',
    appId: '1:1063603108029:ios:b21858ef2982e7b2545fd4',
    messagingSenderId: '1063603108029',
    projectId: 'pathlogic-app',
    storageBucket: 'pathlogic-app.firebasestorage.app',
    iosBundleId: 'com.taggedweb.pathlogic',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDrSDgzXcapW1mrkIA1ajIZiwl5Um8UIuo',
    appId: '1:1063603108029:ios:b21858ef2982e7b2545fd4',
    messagingSenderId: '1063603108029',
    projectId: 'pathlogic-app',
    storageBucket: 'pathlogic-app.firebasestorage.app',
    iosBundleId: 'com.taggedweb.pathlogic',
  );
}
