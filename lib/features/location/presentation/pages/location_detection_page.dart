import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_card.dart';

class LocationDetectionPage extends StatefulWidget {
  final String? photoPath;

  const LocationDetectionPage({super.key, this.photoPath});

  @override
  State<LocationDetectionPage> createState() => _LocationDetectionPageState();
}

class _LocationDetectionPageState extends State<LocationDetectionPage> {
  Map<String, dynamic>? _locationData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _detectIndoorLocation();
  }

  Future<void> _detectIndoorLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate location detection delay
      await Future.delayed(const Duration(seconds: 2));

      final String jsonString = await rootBundle.loadString(
        'assets/mock_data/current_location.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);

      setState(() {
        _locationData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to detect indoor location';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        title: const Text(
          'Location Detection',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage != null
          ? _buildErrorView()
          : _buildLocationView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Detecting your indoor location...',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing building position',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 80, color: AppColors.error),
          const SizedBox(height: 24),
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CustomButton(
            text: 'Try Again',
            onPressed: _detectIndoorLocation,
            icon: Icons.refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationView() {
    final buildingName = _locationData!['buildingName'] as String;
    final floor = _locationData!['floor'] as int;
    final zone = _locationData!['zone'] as String;
    final roomNumber = _locationData!['roomNumber'] as String;
    final roomName = _locationData!['roomName'] as String;
    final accuracy = _locationData!['accuracy'] as double;
    final landmarks = List<String>.from(
      _locationData!['nearbyLandmarks'] as List,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.successGradient,
                ),
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                size: 60,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Here You Are!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Indoor location detected successfully',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            CustomCard(
              hasShadow: true,
              child: Column(
                children: [
                  _buildInfoHeader(Icons.business, 'Building', buildingName),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(Icons.layers, 'Floor', '$floor'),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.greyLight,
                      ),
                      Expanded(
                        child: _buildInfoItem(Icons.explore, 'Zone', zone),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildInfoHeader(
                    Icons.meeting_room,
                    'Room',
                    '$roomNumber - $roomName',
                  ),
                  const Divider(height: 32),
                  _buildInfoItem(
                    Icons.speed,
                    'Accuracy',
                    '±${accuracy.toStringAsFixed(1)}m',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomCard(
              hasShadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.pin_drop,
                          color: AppColors.info,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Nearby Landmarks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...landmarks.map(
                    (landmark) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            landmark,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Navigate to Destination',
              onPressed: () {
                Navigator.of(context).pushNamed('/destination');
              },
              icon: Icons.navigation,
              width: double.infinity,
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Back to Dashboard',
              onPressed: () {
                Navigator.of(
                  context,
                ).popUntil((route) => route.settings.name == '/dashboard');
              },
              isOutlined: true,
              icon: Icons.home,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
