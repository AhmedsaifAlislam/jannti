import 'dart:async';
import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../widgets/jannati_logo.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    // Extended duration (4.0 seconds) to enjoy the peaceful atmosphere
    Timer(const Duration(milliseconds: 4000), _navigateToNext);
  }

  void _navigateToNext() {
    if (!mounted) return;
    final hasSeenOnboarding = StorageService().hasSeenOnboarding();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (ctx, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: hasSeenOnboarding ? const HomeScreen() : const OnboardingScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04140D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Spiritual Glow Background
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1B5E34).withValues(alpha: 0.45),
                    const Color(0xFFFFD700).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo with guaranteed sizing
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: const JannatiLogo(size: 135, showGlow: true),
                ),

                const SizedBox(height: 28),

                // App Title
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFF9C4),
                            Color(0xFFFFD700),
                            Color(0xFFFFA000),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'جَنَّتِي',
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 46,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'وَاحَةُ الذِّكْرِ وَغِرَاسُ الجَنَّة',
                        style: TextStyle(
                          fontFamily: 'GESSTwo',
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D2818).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Text(
                          '«أَلَا أَدُلُّكَ عَلَى غِرَاسٍ خَيْرٍ مِنْ هَذَا؟»',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Loading Indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFFFFD700).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
