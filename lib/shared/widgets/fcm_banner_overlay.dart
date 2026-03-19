import 'dart:async';
import 'package:flutter/material.dart';
import '../../injection.dart';
import '../services/fcm_service.dart';

/// An overlay widget that listens to FCM data messages and displays
/// in-app banners/snackbars for backend retry, fallback, and error events.
///
/// Wrap your [MaterialApp] with this widget so it can show notifications
/// over any screen.
class FcmBannerOverlay extends StatefulWidget {
  final Widget child;

  const FcmBannerOverlay({super.key, required this.child});

  @override
  State<FcmBannerOverlay> createState() => _FcmBannerOverlayState();
}

class _FcmBannerOverlayState extends State<FcmBannerOverlay> {
  StreamSubscription<FcmEvent>? _subscription;
  final List<FcmEvent> _activeEvents = [];

  @override
  void initState() {
    super.initState();
    _subscription = getIt<FcmService>().eventStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static const _maxVisibleBanners = 3;

  void _onEvent(FcmEvent event) {
    setState(() {
      // Cap at _maxVisibleBanners — drop oldest if exceeded
      while (_activeEvents.length >= _maxVisibleBanners) {
        _activeEvents.removeAt(0);
      }
      _activeEvents.add(event);
    });
    // Auto-dismiss after a delay
    final duration = _getDuration(event.eventType);
    Future.delayed(duration, () {
      if (mounted) {
        setState(() {
          _activeEvents.remove(event);
        });
      }
    });
  }

  Duration _getDuration(String eventType) {
    switch (eventType) {
      case 'retry':
      case 'localization_retry':
        return const Duration(seconds: 4);
      case 'fallback':
        return const Duration(seconds: 3);
      case 'service_error':
      case 'service_unavailable':
        return const Duration(seconds: 5);
      default:
        return const Duration(seconds: 3);
    }
  }

  Color _getBackgroundColor(String eventType) {
    switch (eventType) {
      case 'retry':
      case 'localization_retry':
        return const Color(0xFF1565C0); // Blue
      case 'fallback':
        return const Color(0xFF2E7D32); // Green
      case 'service_error':
        return const Color(0xFFC62828); // Red
      case 'service_unavailable':
        return const Color(0xFFE65100); // Orange
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  IconData _getIcon(String eventType) {
    switch (eventType) {
      case 'retry':
      case 'localization_retry':
        return Icons.refresh;
      case 'fallback':
        return Icons.info_outline;
      case 'service_error':
        return Icons.error_outline;
      case 'service_unavailable':
        return Icons.cloud_off;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
      children: [
        widget.child,
        // Banners stack from the top
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: Column(
            children: _activeEvents.map((event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildBanner(event),
              );
            }).toList(),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildBanner(FcmEvent event) {
    final bgColor = _getBackgroundColor(event.eventType);
    final icon = _getIcon(event.eventType);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTitle(event.eventType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _activeEvents.remove(event);
                });
              },
              child: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(String eventType) {
    switch (eventType) {
      case 'retry':
        return 'Retrying...';
      case 'localization_retry':
        return 'Localization Retry';
      case 'fallback':
        return 'Adjusting Settings';
      case 'service_error':
        return 'Error';
      case 'service_unavailable':
        return 'Service Unavailable';
      default:
        return 'Notification';
    }
  }
}
