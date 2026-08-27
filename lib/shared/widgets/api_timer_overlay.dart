import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_timer_tracker.dart';
import '../../injection.dart';
import '../services/location_config_service.dart';

/// Floating API request log, visible only when the debug banner toggle is
/// on. Collapsed: a small pill with in-flight count / last time. Tap to
/// expand into a scrollable box of live and completed request timings.
class ApiTimerOverlay extends StatefulWidget {
  const ApiTimerOverlay({super.key});

  @override
  State<ApiTimerOverlay> createState() => _ApiTimerOverlayState();
}

class _ApiTimerOverlayState extends State<ApiTimerOverlay> {
  final _tracker = ApiTimerTracker.instance;
  Timer? _ticker;
  bool _expanded = false;
  Offset? _pos; // null = default top-right; set once the user drags

  void _drag(BuildContext context, DragUpdateDetails d) {
    final screen = MediaQuery.of(context).size;
    final current = _pos ??
        Offset(screen.width - 278, MediaQuery.of(context).padding.top + 40);
    final next = current + d.delta;
    setState(() {
      _pos = Offset(
        next.dx.clamp(0.0, screen.width - 60),
        next.dy.clamp(MediaQuery.of(context).padding.top, screen.height - 60),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTrackerChanged);
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTrackerChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onTrackerChanged() {
    // Tick 5×/sec while anything is in flight so elapsed time counts up.
    if (_tracker.inFlight.isNotEmpty && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => setState(() {}),
      );
    } else if (_tracker.inFlight.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) => d.inSeconds >= 1
      ? '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s'
      : '${d.inMilliseconds}ms';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: getIt<LocationConfigService>().debugBannerNotifier,
      builder: (context, debugOn, _) {
        if (!debugOn ||
            (_tracker.inFlight.isEmpty && _tracker.recent.isEmpty)) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: _pos?.dx,
          top: _pos?.dy ?? MediaQuery.of(context).padding.top + 40,
          right: _pos == null ? 8 : null,
          child: Material(
            color: Colors.transparent,
            child: _expanded ? _expandedBox(context) : _collapsedPill(context),
          ),
        );
      },
    );
  }

  Widget _collapsedPill(BuildContext context) {
    final now = DateTime.now();
    final inFlight = _tracker.inFlight.values.toList();
    final String label;
    final Color color;
    if (inFlight.isNotEmpty) {
      label =
          'API ${inFlight.length}▶ ${_fmt(now.difference(inFlight.first.start))}…';
      color = Colors.orange;
    } else {
      final last = _tracker.recent.first;
      label = 'API ${_fmt(last.elapsed!)}';
      color = last.failed ? Colors.redAccent : Colors.greenAccent;
    }
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      onPanUpdate: (d) => _drag(context, d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: _style(color)),
      ),
    );
  }

  Widget _expandedBox(BuildContext context) {
    final now = DateTime.now();
    return Container(
      width: 270,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            onPanUpdate: (d) => _drag(context, d),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 4),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  Text('API REQUESTS', style: _style(Colors.white70)),
                  const Spacer(),
                  const Icon(Icons.expand_less,
                      color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              children: [
                for (final e in _tracker.inFlight.values)
                  _row(e.label, '${_fmt(now.difference(e.start))}…',
                      Colors.orange),
                for (final e in _tracker.recent)
                  _row(e.label, _fmt(e.elapsed!),
                      e.failed ? Colors.redAccent : Colors.greenAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _style(color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(time, style: _style(color)),
        ],
      ),
    );
  }

  TextStyle _style(Color color) => TextStyle(
        color: color,
        fontSize: 10,
        fontFamily: 'monospace',
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w600,
      );
}
