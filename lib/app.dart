import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/core/constants/app_text.dart';
import 'package:smart_sense/injection.dart';
import 'package:smart_sense/routes/app_router.dart';
import 'package:smart_sense/shared/services/location_config_service.dart';
import 'package:smart_sense/theme/app_theme.dart';
import 'package:smart_sense/theme/theme_bloc.dart';
import 'package:smart_sense/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smart_sense/features/auth/presentation/bloc/auth_event.dart';
import 'package:smart_sense/shared/widgets/fcm_banner_overlay.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ThemeBloc>()..add(LoadTheme())),
        BlocProvider(
          create: (_) => getIt<AuthBloc>()..add(AuthCheckRequested()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return ValueListenableBuilder<bool>(
            valueListenable: getIt<LocationConfigService>().debugBannerNotifier,
            builder: (_, showBanner, __) => FcmBannerOverlay(
              child: MaterialApp.router(
                title: AppText.appName,
                debugShowCheckedModeBanner: showBanner,
                theme: AppTheme.light(state.palette.scheme),
                darkTheme: AppTheme.light(state.palette.scheme),
                themeMode: ThemeMode.light,
                routerConfig: AppRouter.router,
              ),
            ),
          );
        },
      ),
    );
  }
}
