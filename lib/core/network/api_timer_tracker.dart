import 'package:flutter/foundation.dart';

/// One tracked API request: label, start time, and (once done) duration.
class ApiTimerEntry {
  final String label;
  final DateTime start;
  Duration? elapsed; // null while in flight
  bool failed = false;

  ApiTimerEntry(this.label) : start = DateTime.now();
}

/// Process-wide record of in-flight and recent API requests, fed by the
/// ApiClient interceptor and rendered by ApiTimerOverlay in debug mode.
class ApiTimerTracker extends ChangeNotifier {
  ApiTimerTracker._();
  static final ApiTimerTracker instance = ApiTimerTracker._();

  static const _maxRecent = 30;
  int _nextId = 0;

  final Map<int, ApiTimerEntry> inFlight = {};
  final List<ApiTimerEntry> recent = [];

  int begin(String label) {
    final id = _nextId++;
    inFlight[id] = ApiTimerEntry(label);
    notifyListeners();
    return id;
  }

  void end(int id, {bool failed = false}) {
    final entry = inFlight.remove(id);
    if (entry == null) return;
    entry.elapsed = DateTime.now().difference(entry.start);
    entry.failed = failed;
    recent.insert(0, entry);
    if (recent.length > _maxRecent) recent.removeLast();
    notifyListeners();
  }
}
