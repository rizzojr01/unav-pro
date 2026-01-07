import 'package:flutter/material.dart';

import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';
import 'dart:math' as math;

class MapViewWidget extends StatefulWidget {
  final LocationEntity currentLocation;
  final RouteEntity route;
  final bool isNavigating;

  const MapViewWidget({
    super.key,
    required this.currentLocation,
    required this.route,
    this.isNavigating = false,
  });

  @override
  State<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends State<MapViewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _MapPainter(
                animationValue: widget.isNavigating ? _controller.value : 0.0,
                primaryColor: theme.primaryColor,
                waypoints: widget.route.waypoints,
                currentLocation: widget.currentLocation,
                theme: theme,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final List<LocationEntity> waypoints;
  final LocationEntity currentLocation;
  final ThemeData theme;

  _MapPainter({
    required this.animationValue,
    required this.primaryColor,
    required this.waypoints,
    required this.currentLocation,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Tech Background Grid
    _drawGrid(canvas, size);

    // 2. Draw Simplified Floor Plan
    _drawFloorPlan(canvas, size);

    if (waypoints.isEmpty) return;

    // 3. Normalize coordinates to fit screen
    final points = _normalizeWaypoints(size);

    // 4. Draw Navigation Path
    _drawPath(canvas, points);

    // 5. Draw Markers
    _drawMarkers(canvas, points, size);

    // 6. Draw User Location
    _drawUserLocation(canvas, points);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const spacing = 40.0;

    for (var i = 0.0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (var i = 0.0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  void _drawFloorPlan(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = theme.colorScheme.onSurface.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    // Draw some schematic "rooms" and "corridors"
    final rooms = [
      Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.35, h * 0.25),
      Rect.fromLTWH(w * 0.6, h * 0.05, w * 0.35, h * 0.35),
      Rect.fromLTWH(w * 0.05, h * 0.65, w * 0.4, h * 0.3),
      Rect.fromLTWH(w * 0.55, h * 0.55, w * 0.4, h * 0.4),
    ];

    for (final room in rooms) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(room, const Radius.circular(8)),
        wallPaint,
      );
    }

    // Corridor lines
    canvas.drawLine(Offset(0, h * 0.45), Offset(w, h * 0.45), wallPaint);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), wallPaint);
  }

  List<Offset> _normalizeWaypoints(Size size) {
    if (waypoints.isEmpty) return [];

    double minLat = waypoints.map((w) => w.latitude).reduce(math.min);
    double maxLat = waypoints.map((w) => w.latitude).reduce(math.max);
    double minLng = waypoints.map((w) => w.longitude).reduce(math.min);
    double maxLng = waypoints.map((w) => w.longitude).reduce(math.max);

    // Add padding to normalization
    double latRange = (maxLat - minLat).abs();
    double lngRange = (maxLng - minLng).abs();

    if (latRange == 0) latRange = 0.0001;
    if (lngRange == 0) lngRange = 0.0001;

    final padding = 60.0;
    final drawW = size.width - (padding * 2);
    final drawH = size.height - (padding * 2);

    return waypoints.map((w) {
      // Map lat/lng to 0..1 then to screen coordinates
      double x = padding + ((w.longitude - minLng) / lngRange) * drawW;
      double y = padding + (1.0 - (w.latitude - minLat) / latRange) * drawH;
      return Offset(x, y);
    }).toList();
  }

  void _drawPath(Canvas canvas, List<Offset> points) {
    final pathPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final activePathPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, pathPaint);

    // Dash effect for path
    _drawDashedPath(canvas, path, activePathPaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 8.0;
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawMarkers(Canvas canvas, List<Offset> points, Size size) {
    // Start Marker
    canvas.drawCircle(points.first, 8, Paint()..color = Colors.blue);

    // Destination Marker with Pulse
    final destPos = points.last;
    final pulse = (math.sin(animationValue * math.pi * 2) + 1) / 2;

    // Outer Glow
    canvas.drawCircle(
      destPos,
      12 + (10 * pulse),
      Paint()..color = primaryColor.withValues(alpha: 0.2 * (1 - pulse)),
    );

    // Core
    canvas.drawCircle(destPos, 8, Paint()..color = primaryColor);
    canvas.drawCircle(destPos, 4, Paint()..color = theme.colorScheme.surface);

    _drawLabel(canvas, destPos, "DESTINATION");
  }

  void _drawUserLocation(Canvas canvas, List<Offset> points) {
    // Animate user location along path segments
    int segmentCount = points.length - 1;
    double progress = animationValue * segmentCount;
    int index = progress.floor();
    if (index >= segmentCount) index = segmentCount - 1;
    double t = progress - index;

    Offset p1 = points[index];
    Offset p2 = points[index + 1];

    Offset userPos = Offset(
      p1.dx + (p2.dx - p1.dx) * t,
      p1.dy + (p2.dy - p1.dy) * t,
    );

    // Glow
    canvas.drawCircle(
      userPos,
      14,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Arrow pointing towards next waypoint
    double angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    _drawLocationArrow(canvas, userPos, angle);
  }

  void _drawLocationArrow(Canvas canvas, Offset pos, double angle) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    final path = Path();
    path.moveTo(12, 0);
    path.lineTo(-8, -8);
    path.lineTo(-4, 0);
    path.lineTo(-8, 8);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, Offset pos, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy + 15),
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}
