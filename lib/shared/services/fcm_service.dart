import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/utils/logger.dart';

/// Represents an FCM data message event from the backend.
class FcmEvent {
  final String eventType;
  final String message;
  final String? endpoint;
  final String? attempt;
  final String? maxAttempts;

  FcmEvent({
    required this.eventType,
    required this.message,
    this.endpoint,
    this.attempt,
    this.maxAttempts,
  });

  factory FcmEvent.fromData(Map<String, dynamic> data) {
    return FcmEvent(
      eventType: data['event_type'] ?? 'unknown',
      message: data['message'] ?? '',
      endpoint: data['endpoint'],
      attempt: data['attempt'],
      maxAttempts: data['max_attempts'],
    );
  }

  @override
  String toString() =>
      'FcmEvent(type: $eventType, message: $message, attempt: $attempt/$maxAttempts)';
}

/// Service that manages FCM token retrieval and foreground message listening.
///
/// The backend sends data-only FCM messages for retry, fallback, and error
/// events. This service exposes:
/// - [token]: the current FCM device token (nullable)
/// - [eventStream]: a broadcast stream of [FcmEvent]s for UI consumption
class FcmService {
  final AppLogger _logger;

  String? _token;
  final _eventController = StreamController<FcmEvent>.broadcast();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  FcmService({required AppLogger logger}) : _logger = logger;

  /// The current FCM device token. May be null if not yet retrieved.
  String? get token => _token;

  /// Stream of FCM data message events for the UI to listen to.
  Stream<FcmEvent> get eventStream => _eventController.stream;

  /// Initialize FCM: request permissions, get token, and start listening.
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (required on iOS, no-op on Android for data messages)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the FCM device token
    _token = await messaging.getToken();
    _logger.info('FCM token obtained');

    // Listen for token refreshes
    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      _logger.debug('FCM token refreshed');
    });

    // Listen for foreground data messages
    _messageSub = FirebaseMessaging.onMessage.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final event = FcmEvent.fromData(data);
    _logger.info('FCM event received: ${event.eventType}');
    _eventController.add(event);
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _eventController.close();
  }
}
