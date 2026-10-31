import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';

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
      theme: ThemeData(
        fontFamily: 'Cairo',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Amiri'),
          displayMedium: TextStyle(fontFamily: 'Amiri'),
          displaySmall: TextStyle(fontFamily: 'Amiri'),
          headlineLarge: TextStyle(fontFamily: 'Amiri'),
          headlineMedium: TextStyle(fontFamily: 'Amiri'),
          headlineSmall: TextStyle(fontFamily: 'Amiri'),
          titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontFamily: 'Cairo'),
          bodyLarge: TextStyle(fontFamily: 'Cairo'),
          bodyMedium: TextStyle(fontFamily: 'Cairo'),
          bodySmall: TextStyle(fontFamily: 'Cairo'),
          labelLarge: TextStyle(fontFamily: 'Cairo'),
          labelMedium: TextStyle(fontFamily: 'Cairo'),
          labelSmall: TextStyle(fontFamily: 'Cairo'),
        ),
        primaryTextTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Amiri'),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1F17),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

