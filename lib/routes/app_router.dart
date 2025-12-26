import 'package:flutter/material.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/camera/presentation/pages/camera_page.dart';
import '../features/location/presentation/pages/location_detection_page.dart';
import '../features/destination/presentation/pages/destination_page.dart';
import '../features/navigation/presentation/pages/navigation_page.dart';
import '../features/destination/domain/entities/destination_entity.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String camera = '/camera';
  static const String locationDetection = '/location-detection';
  static const String destination = '/destination';
  static const String navigation = '/navigation';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());

      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());

      case camera:
        return MaterialPageRoute(builder: (_) => const CameraPage());

      case locationDetection:
        return MaterialPageRoute(builder: (_) => const LocationDetectionPage());

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
