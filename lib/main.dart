import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();
  debugPrint('✅ StorageService initialized');
  runApp(const JannatiApp());
}

class JannatiApp extends StatelessWidget {
  const JannatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جنتي',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
