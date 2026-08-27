import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages switching the app's backend between the local/dev server and the
/// hosted Koyeb server. The active choice is persisted and exposed live via
/// [serverKeyNotifier] so both the UI and the network layer can react
/// immediately without a restart.
class ServerConfigService {
  final SharedPreferences _prefs;

  static const String _keyServer = 'server_mode';

  static const String localKey = 'local';
  static const String koyebKey = 'koyeb';

  static const String _defaultLocalUrl = 'http://3.234.213.229:8080';
  static const String _defaultKoyebUrl =
      'https://territorial-mavis-taggedweb-nyu-3d762b6d.koyeb.app';

  ServerConfigService(this._prefs);

  /// Live notifier for the selected server key ('local' | 'koyeb').
  late final ValueNotifier<String> serverKeyNotifier =
      ValueNotifier(_prefs.getString(_keyServer) ?? localKey);

  static String get localUrl =>
      dotenv.get('BASE_URL', fallback: _defaultLocalUrl);

  static String get koyebUrl =>
      dotenv.get('KOYEB_BASE_URL', fallback: _defaultKoyebUrl);

  /// The currently selected server key.
  String get currentKey => serverKeyNotifier.value;

  /// The base URL the app should use right now.
  String get currentUrl =>
      currentKey == koyebKey ? koyebUrl : localUrl;

  /// Convenience flag for the Koyeb (hosted) endpoint.
  bool get isKoyeb => currentKey == koyebKey;

  /// Select a server by key ('local' | 'koyeb'). Unknown values default to
  /// local. No-op if the key is already active.
  Future<void> setServer(String key) async {
    final next = key == koyebKey ? koyebKey : localKey;
    if (next == currentKey) return;
    serverKeyNotifier.value = next;
    await _prefs.setString(_keyServer, next);
  }

  /// Toggle helper: [useKoyeb] true selects Koyeb, false selects local.
  Future<void> setUseKoyeb(bool useKoyeb) =>
      setServer(useKoyeb ? koyebKey : localKey);
}

/// Middle-truncates a URL so it fits on small screens while keeping the
/// scheme and the end of the host/path readable.
String truncateUrl(String url, {int head = 24, int tail = 12}) {
  if (url.length <= head + tail + 1) return url;
  return '${url.substring(0, head)}…${url.substring(url.length - tail)}';
}
