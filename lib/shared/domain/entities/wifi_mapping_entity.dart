import 'package:equatable/equatable.dart';

/// Represents a stored WiFi network → place/building mapping.
///
/// The BSSID (Basic Service Set Identifier) is the MAC address of the
/// Wi-Fi access point — it never changes, making it a reliable identifier
/// unlike the SSID (network name) which can be shared or renamed.
class WifiMappingEntity extends Equatable {
  /// The BSSID of the WiFi access point, e.g. "AA:BB:CC:DD:EE:FF"
  final String bssid;

  /// Human-readable network name, stored for display purposes only
  final String ssid;

  /// The place name that this WiFi network maps to (e.g. "New_York_City")
  final String placeName;

  /// The building name that this WiFi network maps to (e.g. "LightHouse")
  final String buildingName;

  /// Optional floor name — may be null since WiFi is shared across floors
  final String? floorName;

  /// When this mapping was created
  final DateTime createdAt;

  const WifiMappingEntity({
    required this.bssid,
    required this.ssid,
    required this.placeName,
    required this.buildingName,
    this.floorName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        bssid,
        ssid,
        placeName,
        buildingName,
        floorName,
        createdAt,
      ];
}
