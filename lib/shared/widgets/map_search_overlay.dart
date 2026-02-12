import 'dart:ui';
import 'package:flutter/material.dart';
import '../../features/destination/domain/entities/destination_entity.dart';
import 'map_markers.dart';

class MapSearchOverlay extends StatelessWidget {
  final TextEditingController controller;
  final List<DestinationEntity> filteredDestinations;
  final VoidCallback onClose;
  final Function(DestinationEntity) onDestinationTap;
  final String hintText;

  const MapSearchOverlay({
    super.key,
    required this.controller,
    required this.filteredDestinations,
    required this.onClose,
    required this.onDestinationTap,
    this.hintText = 'Search destinations...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top + 12;

    return Stack(
      children: [
        // Background dim/blur that can be tapped to close
        GestureDetector(
          onTap: onClose,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: Colors.black.withValues(alpha: 0.1),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),

        // Floating Search Panel
        Positioned(
          top: topPadding,
          left: 16,
          right: 16,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + 40, // Avoid keyboard
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Bar
              Hero(
                tag: 'map_search_bar',
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surface,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: onClose,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Results Panel
              Flexible(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildResultsList(context, theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context, ThemeData theme) {
    if (filteredDestinations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.text.isEmpty ? Icons.manage_search : Icons.search_off,
              size: 40,
              color:
                  (controller.text.isEmpty
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error)
                      .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              controller.text.isEmpty
                  ? 'Start typing to search...'
                  : 'No destinations found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: filteredDestinations.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 56,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final destination = filteredDestinations[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              DestinationMarker.getIconForDestination(destination.name),
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            destination.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onTap: () => onDestinationTap(destination),
        );
      },
    );
  }
}
