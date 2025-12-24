import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'injection.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'features/camera/presentation/bloc/camera_bloc.dart';
import 'features/destination/presentation/bloc/destination_bloc.dart';
import 'features/navigation/presentation/bloc/navigation_bloc.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<CameraBloc>()),
        BlocProvider(create: (_) => getIt<DestinationBloc>()),
        BlocProvider(create: (_) => getIt<NavigationBloc>()),
      ],
      child: MaterialApp(
        title: 'Smart Sense',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRouter.camera,
      ),
    );
  }
}
