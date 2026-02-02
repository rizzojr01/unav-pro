import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/step_indicator.dart';

class PhotoPreviewWidget extends StatelessWidget {
  final String imagePath;
  final VoidCallback onRetake;
  final VoidCallback onContinue;

  const PhotoPreviewWidget({
    super.key,
    required this.imagePath,
    required this.onRetake,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 60),
        child: StepIndicator(
          currentStep: 2,
          title: 'Review Photo',
          onBack: onRetake,
        ),
      ),
      body: Stack(
        children: [
          // 1. Centered Image Preview
          Center(child: Image.file(File(imagePath), fit: BoxFit.contain)),

          // 2. Beautiful Footer with Guidance Text
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Guidance Text Section
                  Column(
                    children: [
                      const Text(
                        'Is this photo clear?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ensure your surroundings are well-lit and the image is not blurry for better navigation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    children: [
                      // Retake Outlined Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRetake,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 22,
                          ),
                          label: const Text(
                            'Retake',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Continue Elevation Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onContinue,
                          icon: Icon(
                            Icons.check,
                            size: 22,
                            color: theme.colorScheme.onPrimary,
                          ),
                          label: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 5,
                            shadowColor: theme.colorScheme.primary.withOpacity(
                              0.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
