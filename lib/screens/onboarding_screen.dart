import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../widgets/jannati_logo.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _pages = [
    _OnboardingItem(
      title: 'واحة الذكر وغراس الجنة 🌴',
      description:
          'اربط لسانك بذكر الله العظيم.. فكل تسبيحة وتهليلة وتحميدة تغرس لك في جنان الخلد نخيلاً وأشجاراً وقصوراً.',
      icon: Icons.fingerprint,
      badge: 'الذكر المبارك',
    ),
    _OnboardingItem(
      title: 'روضة تفاعلية ثلاثية الأبعاد 🌊',
      description:
          'شاهد عالم جنتك ينمو ويزدهر أمام عينيك في مشهد ثلاثي الأبعاد تفاعلي بنهر سماوي وجسور رخامية ومروج خضراء.',
      icon: Icons.public,
      badge: 'عالم الجنة 3D',
    ),
    _OnboardingItem(
      title: 'مراتب النماء والارتقاء 🌟',
      description:
          'كلما واظبت على الأذكار، ارتقى غراسك من براعم صغيرة إلى أشجار باسقة وقصور ذهبية نورانية من المرتبة الأولى حتى الخامسة.',
      icon: Icons.auto_awesome,
      badge: 'مراتب النماء (Tiers)',
    ),
    _OnboardingItem(
      title: 'سجل الحصاد والأوسمة 📊',
      description:
          'تتبع عدد تسبيحاتك وغراسك وافتح أوسمة الفضل الروحاني لتبني سلسلة إيمانية مباركة تعمر بها آخرتك.',
      icon: Icons.workspace_premium,
      badge: 'الحصاد والأوسمة',
    ),
  ];

  void _onFinish() async {
    await StorageService().setOnboardingSeen(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (ctx, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: const HomeScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF04140D),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Top Bar with Logo and Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const JannatiLogo(size: 42, showGlow: false),
                    if (!isLast)
                      TextButton(
                        onPressed: _onFinish,
                        child: Text(
                          'تخطي',
                          style: TextStyle(
                            fontFamily: 'GESSTwo',
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // Page View Slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Card Icon with Glowing Halo
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0D2818),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              size: 54,
                              color: const Color(0xFFFFD700),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              item.badge,
                              style: const TextStyle(
                                fontFamily: 'GESSTwo',
                                fontSize: 12,
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Title
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Description
                          Text(
                            item.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'GESSTwo',
                              fontSize: 14,
                              height: 1.6,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Indicator & Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  children: [
                    // Dot Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == i
                                ? const Color(0xFFFFD700)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Navigation Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (isLast) {
                            _onFinish();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: const Color(0xFFFFD700),
                          elevation: 6,
                          shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                            side: const BorderSide(
                              color: Color(0xFFFFD700),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          isLast ? 'ابدأ رحلتك الروحانية 🌴' : 'التالي',
                          style: const TextStyle(
                            fontFamily: 'GESSTwo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final String badge;

  _OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.badge,
  });
}
