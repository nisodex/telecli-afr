import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'package:telecli_afr/ui/features/navigation/views/main_navigation_screen.dart';

/// Allows trusting Spanish Government FNMT certificates for geoportal.minetur.gob.es
class MineturHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host.contains('minetur.gob.es');
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MineturHttpOverrides();

  // Dark navigation bar for OLED battery saving and sun contrast
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SQLite database
  await ServiceLocator.localStorageService.database;

  runApp(const MovistarAfr5gApp());
}

class MovistarAfr5gApp extends StatelessWidget {
  const MovistarAfr5gApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movistar AFR 5G - Orientador de Antenas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
