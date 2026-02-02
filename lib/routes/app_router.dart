import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/camera/presentation/pages/camera_page.dart';
import '../features/location/presentation/pages/location_detection_page.dart';
import '../features/destination/presentation/pages/destination_page.dart';
import '../features/navigation/presentation/pages/navigation_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/destination/domain/entities/destination_entity.dart';
import '../features/locate_me/presentation/pages/locate_me_camera_page.dart';
import '../features/locate_me/presentation/pages/locate_me_floor_plan_page.dart';
import '../features/locate_me/presentation/bloc/locate_me_bloc.dart';
import '../features/localization_history/presentation/pages/localization_history_page.dart';
import '../features/localization_history/presentation/bloc/localization_history_bloc.dart';
import '../injection.dart';
import '../features/destination/presentation/pages/floor_map_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String camera = '/camera';
  static const String locationDetection = '/location-detection';
  static const String destination = '/destination';
  static const String navigation = '/navigation';
  static const String profile = '/profile';
  static const String locateMe = '/locate-me';
  static const String localizationHistory = '/localization-history';
  static const String locateMeFloorPlan = '/locate-me/floor-plan';
  static const String floorMap = '/floor-map';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(path: splash, builder: (context, state) => const SplashPage()),
      GoRoute(
        path: onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: login, builder: (context, state) => const LoginPage()),
      GoRoute(path: signup, builder: (context, state) => const SignupPage()),
      GoRoute(
        path: dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: camera,
        builder: (context, state) {
          final destination = state.extra as DestinationEntity?;
          return CameraPage(destination: destination);
        },
      ),
      GoRoute(
        path: locationDetection,
        builder: (context, state) => const LocationDetectionPage(),
      ),
      GoRoute(
        path: destination,
        builder: (context, state) => const DestinationPage(),
      ),
      GoRoute(path: profile, builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: floorMap,
        builder: (context, state) => const FloorMapPage(),
      ),
      GoRoute(
        path: navigation,
        builder: (context, state) {
          final extra = state.extra;
          DestinationEntity? destination;
          String? imagePath;

          if (extra is Map<String, dynamic>) {
            destination = extra['destination'] as DestinationEntity?;
            imagePath = extra['imagePath'] as String?;
          } else if (extra is DestinationEntity) {
            destination = extra;
          }

          if (destination == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Destination is required')),
            );
          }
          return NavigationPage(destination: destination, imagePath: imagePath);
        },
      ),
      GoRoute(
        path: locateMe,
        builder: (context, state) {
          return BlocProvider(
            create: (context) => getIt<LocateMeBloc>(),
            child: const LocateMeCameraPage(),
          );
        },
      ),
      GoRoute(
        path: localizationHistory,
        builder: (context, state) {
          return BlocProvider(
            create: (context) => getIt<LocalizationHistoryBloc>(),
            child: const LocalizationHistoryPage(),
          );
        },
      ),
      GoRoute(
        path: locateMeFloorPlan, // Using the static const
        builder: (context, state) {
          final bloc = state.extra as LocateMeBloc;
          return BlocProvider.value(
            value: bloc,
            child: const LocateMeFloorPlanPage(),
          );
        },
      ),
    ],
  );
}
