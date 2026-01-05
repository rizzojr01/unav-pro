import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/injection.dart';
import 'package:smart_sense/routes/app_router.dart';
import 'package:smart_sense/theme/app_theme.dart';
import 'package:smart_sense/theme/theme_bloc.dart';
import 'package:smart_sense/features/camera/presentation/bloc/camera_bloc.dart';
import 'package:smart_sense/features/destination/presentation/bloc/destination_bloc.dart';
import 'package:smart_sense/features/navigation/presentation/bloc/navigation_bloc.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ThemeBloc>()..add(LoadTheme())),
        BlocProvider(create: (_) => getIt<CameraBloc>()),
        BlocProvider(create: (_) => getIt<DestinationBloc>()),
        BlocProvider(create: (_) => getIt<NavigationBloc>()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'Smart Sense',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
