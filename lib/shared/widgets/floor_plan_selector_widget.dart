import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smart_sense/shared/widgets/map_markers.dart';

/// Reusable widget for selecting a location on a floor plan
class FloorPlanSelectorWidget extends StatefulWidget {
  final String? base64FloorPlan;
  final Function(double x, double y) onLocationSelected;
  final String confirmButtonText;

  const FloorPlanSelectorWidget({
    super.key,
    required this.base64FloorPlan,
    required this.onLocationSelected,
    this.confirmButtonText = 'Confirm Location',
  });

  @override
  State<FloorPlanSelectorWidget> createState() =>
      _FloorPlanSelectorWidgetState();
}

class _FloorPlanSelectorWidgetState extends State<FloorPlanSelectorWidget> {
  final TransformationController _transformationController =
      TransformationController();
  Offset? _selectedPosition;
  Size? _imageSize;
  Size? _containerSize;
  Uint8List? _decodedImage;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(FloorPlanSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.base64FloorPlan != oldWidget.base64FloorPlan) {
      _decodeImage();
      _imageSize = null;
    }
  }

  void _decodeImage() {
    setState(() {
      _decodedImage = null;
    });
    // Explicitly evict images from cache when switching floors
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (widget.base64FloorPlan != null && widget.base64FloorPlan!.isNotEmpty) {
      try {
        _decodedImage = base64Decode(widget.base64FloorPlan!);
      } catch (e) {
        debugPrint('Error decoding floor plan: $e');
        _decodedImage = null;
      }
    } else {
      _decodedImage = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, RenderBox renderBox) {
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    if (_imageSize == null || _containerSize == null) return;

    // Calculate the displayed image size maintaining aspect ratio
    final imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final containerAspectRatio = _containerSize!.width / _containerSize!.height;

    double displayWidth;
    double displayHeight;

    if (imageAspectRatio > containerAspectRatio) {
      displayWidth = _containerSize!.width;
      displayHeight = _containerSize!.width / imageAspectRatio;
    } else {
      displayHeight = _containerSize!.height;
      displayWidth = _containerSize!.height * imageAspectRatio;
    }

    // Center offset for the image within the container
    final centerOffsetX = (_containerSize!.width - displayWidth) / 2;
    final centerOffsetY = (_containerSize!.height - displayHeight) / 2;

    // Get the transformation matrix
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();

    // Calculate the translation
    final translateX = matrix.getTranslation().x;
    final translateY = matrix.getTranslation().y;

    // Convert tap position to image coordinates
    final adjustedX = (localPosition.dx - translateX) / scale;
    final adjustedY = (localPosition.dy - translateY) / scale;

    // Check if tap is within the image bounds
    if (adjustedX < centerOffsetX ||
        adjustedX > centerOffsetX + displayWidth ||
        adjustedY < centerOffsetY ||
        adjustedY > centerOffsetY + displayHeight) {
      return; // Tap outside image
    }

    // Convert to image pixel coordinates
    final imageX =
        (adjustedX - centerOffsetX) * (_imageSize!.width / displayWidth);
    final imageY =
        (adjustedY - centerOffsetY) * (_imageSize!.height / displayHeight);

    setState(() {
      _selectedPosition = Offset(adjustedX, adjustedY);
    });

    // Store the actual image coordinates for callback
    _selectedImageCoordinates = Offset(imageX, imageY);
  }

  Offset? _selectedImageCoordinates;

  void _loadImageSize(Uint8List imageBytes) {
    if (_imageSize != null) return; // Prevent reloading

    final image = MemoryImage(imageBytes);
    image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (mounted && _imageSize == null) {
              setState(() {
                _imageSize = Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                );
              });
            }
          }),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Safety check for hot reload or if decode failed initially
    if (_decodedImage == null &&
        widget.base64FloorPlan != null &&
        widget.base64FloorPlan!.isNotEmpty) {
      _decodeImage();
    }

    if (_decodedImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Floor plan not available',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    _loadImageSize(_decodedImage!);

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Only update container size if it changed significantly
            final newSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (_containerSize == null ||
                (_containerSize!.width - newSize.width).abs() > 1 ||
                (_containerSize!.height - newSize.height).abs() > 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _containerSize = newSize;
                  });
                }
              });
            }

            return GestureDetector(
              onTapUp: (details) {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  _handleTap(details, renderBox);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(100),
                child: Center(
                  child: Image.memory(
                    _decodedImage!,
                    fit: BoxFit.contain,
                    // Limit the memory usage of the decoded bitmap.
                    // 1600 is usually plenty for a floor plan while saving significant RAM.
                    cacheHeight: 1600,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              const Text('Failed to load floor plan'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        // Selected position marker
        if (_selectedPosition != null)
          AnimatedBuilder(
            animation: _transformationController,
            builder: (context, child) {
              final matrix = _transformationController.value;
              final scale = matrix.getMaxScaleOnAxis();
              final transformedPosition = MatrixUtils.transformPoint(
                matrix,
                _selectedPosition!,
              );

              // Scale marker size with zoom level
              final scaledSize = 28.0 * scale;

              return Positioned(
                left: transformedPosition.dx - (scaledSize / 2),
                top: transformedPosition.dy - (scaledSize / 2),
                child: DestinationMarker(
                  size: scaledSize,
                  backgroundColor: theme.colorScheme.error,
                  icon: Icons.place,
                ),
              );
            },
          ),
        // Confirm button
        if (_selectedPosition != null && _selectedImageCoordinates != null)
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                widget.onLocationSelected(
                  _selectedImageCoordinates!.dx,
                  _selectedImageCoordinates!.dy,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.confirmButtonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
