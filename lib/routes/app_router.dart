import 'package:flutter/material.dart';
import '../features/camera/presentation/pages/camera_page.dart';
import '../features/destination/presentation/pages/destination_page.dart';
import '../features/navigation/presentation/pages/navigation_page.dart';
import '../features/destination/domain/entities/destination_entity.dart';

class AppRouter {
  static const String camera = '/';
  static const String destination = '/destination';
  static const String navigation = '/navigation';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case camera:
        return MaterialPageRoute(builder: (_) => const CameraPage());

      case destination:
        return MaterialPageRoute(builder: (_) => const DestinationPage());

      case navigation:
        final destination = settings.arguments as DestinationEntity?;
        if (destination == null) {
          return _errorRoute('Destination is required');
        }
        return MaterialPageRoute(
          builder: (_) => NavigationPage(destination: destination),
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
