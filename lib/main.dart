import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/dlog_theme.dart';
import 'theme/dlog_theme_controller.dart';
import 'screens/splash/splash_screen.dart';
import 'services/grace_period_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GracePeriodNotificationService.instance.initialize();
  await DLogThemeController.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DLogThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'DLog',
        debugShowCheckedModeBanner: false,
        theme: DLogTheme.lightTheme,
        darkTheme: DLogTheme.darkTheme,
        themeMode: DLogThemeController.instance.themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}
