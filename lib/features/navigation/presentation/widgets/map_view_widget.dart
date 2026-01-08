import 'package:flutter/material.dart';

import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';

class MapViewWidget extends StatefulWidget {
  final LocationEntity currentLocation;
  final RouteEntity route;

  const MapViewWidget({
    super.key,
    required this.currentLocation,
    required this.route,
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
      color: theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/lighthouse_map.png',
                  fit: BoxFit.cover,
                ),
              ),
              // Subtle grid overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    theme.dividerColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
