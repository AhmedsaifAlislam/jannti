import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/adhkar_data.dart';
import '../models/dhikr.dart';
import '../models/reward_type.dart';
import '../services/storage_service.dart';
import '../utils/garden_assets.dart';
import '../utils/number_formatter.dart';
import '../widgets/islamic_pattern_overlay.dart';
import '../widgets/jannah_virtues_modal.dart';
import '../widgets/jannati_logo.dart';
import 'audio_sanctuary_screen.dart';
import 'dhikr_counter_screen.dart';
import 'garden_screen.dart';
import 'jannati_3d_screen.dart';
import 'jannati_isometric_screen.dart';
import 'notification_settings_screen.dart';
import 'onboarding_screen.dart';
import 'stats_screen.dart';

Color _rewardGradientStart(RewardType type) {
  switch (type) {
    case RewardType.palmTree:
      return const Color(0xFF1B5E20);
    case RewardType.tree:
      return const Color(0xFF0D4F1F);
    case RewardType.house:
      return const Color(0xFF0D47A1);
    case RewardType.palace:
      return const Color(0xFF4A148C);
    case RewardType.mosque:
      return const Color(0xFFE65100);
    case RewardType.treasure:
      return const Color(0xFFB78103);
  }
}

Color _rewardGradientEnd(RewardType type) {
  switch (type) {
    case RewardType.palmTree:
      return const Color(0xFF2E7D32);
    case RewardType.tree:
      return const Color(0xFF1B6F2F);
    case RewardType.house:
      return const Color(0xFF1976D2);
    case RewardType.palace:
      return const Color(0xFF7B1FA2);
    case RewardType.mosque:
      return const Color(0xFFF57C00);
    case RewardType.treasure:
      return const Color(0xFFFFD700);
  }
}

final List<Map<String, String>> _jannahWisdoms = [
  {
    'title': 'غراس الجنة 🌱',
    'quote': '«الجنة قيعان، وغراسها: سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر»',
  },
  {
    'title': 'أشجار الفردوس 🌳',
    'quote': '«إن في الجنة شجرة يسير الراكب الجواد في ظلها مائة عام لا يقطعها»',
  },
  {
    'title': 'بنيان القصور 🏰',
    'quote': '«لبنة من فضة ولبنة من ذهب، وملاطها المسك، وحصباؤها اللؤلؤ والياقوت»',
  },
  {
    'title': 'نخيل النعيم 🌴',
    'quote': '«من قال: سبحان الله العظيم وبحمده، غُرست له نخلة في الجنة»',
  },
  {
    'title': 'كنوز العرش 💎',
    'quote': '«ألا أدلك على كلمة هي كنز من كنوز الجنة؟ لا حول ولا قوة إلا بالله»',
  },
  {
    'title': 'قصور الإخلاص 📖',
    'quote': '«من قرأ ﴿قل هو الله أحد﴾ عشر مرات بنى الله له قصراً في الجنة»',
  },
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final GlobalKey<GardenScreenState> _gardenKey = GlobalKey();

  Map<RewardType, int> _rewardCounts = {};
  Map<String, int> _dhikrCounts = {};
  int _currentIndex = 0;
  RewardType? _filterType;

  late List<Dhikr> _shuffledAdhkar;
  int _featuredDhikrIndex = 0;
  int _wisdomIndex = 0;

  late AnimationController _ambientGlowController;

  @override
  void initState() {
    super.initState();
    _shuffledAdhkar = List.from(adhkarList)..shuffle();

    _loadData();

    final now = DateTime.now();
    _featuredDhikrIndex = now.day % adhkarList.length;
    _wisdomIndex = now.day % _jannahWisdoms.length;

    _ambientGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientGlowController.dispose();
    super.dispose();
  }

  void _loadData() {
    try {
      final rewards = _storage.getAllRewards();
      final counts = <RewardType, int>{};
      for (final type in RewardType.values) {
        counts[type] = 0;
      }
      for (final r in rewards) {
        counts[r.type] = (counts[r.type] ?? 0) + 1;
      }
      setState(() {
        _rewardCounts = counts;
        _dhikrCounts = _storage.getAllDhikrCounts();
      });
    } catch (e) {
      debugPrint('⚠️ _loadData() failed: $e');
    }
  }

  void _shuffleAdhkarList() {
    HapticFeedback.selectionClick();
    setState(() {
      _shuffledAdhkar.shuffle();
    });
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      if (index == 0) {
        _loadData();
      } else if (index == 1) {
        _gardenKey.currentState?.refreshGarden();
      }
      _currentIndex = index;
    });
  }

  void _rotateFeaturedDhikr() {
    HapticFeedback.selectionClick();
    setState(() {
      _featuredDhikrIndex = (_featuredDhikrIndex + 1) % adhkarList.length;
    });
  }

  void _rotateWisdom() {
    HapticFeedback.selectionClick();
    setState(() {
      _wisdomIndex = (_wisdomIndex + 1) % _jannahWisdoms.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03140C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Celestial Radial Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientGlowController,
              builder: (context, _) {
                final glow = 0.2 + _ambientGlowController.value * 0.12;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 0.9,
                      colors: [
                        const Color(0xFF1B5E34).withValues(alpha: glow),
                        const Color(0xFF072417),
                        const Color(0xFF020E08),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Screen Switcher
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildBentoMainContent(),
              const JannatiIsometricScreen(),
              const AudioSanctuaryScreen(),
              const StatsScreen(),
            ],
          ),

          // Bottom Glass Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildLuxuryBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoMainContent() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final filteredAdhkar = _filterType == null
        ? _shuffledAdhkar
        : _shuffledAdhkar.where((d) => d.rewardType == _filterType).toList();

    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Top Header Bar
            SliverToBoxAdapter(child: _buildHeaderBar()),

            // 2. 🌟 The Beloved Horizontal Rewards Stats Strip
            SliverToBoxAdapter(child: _buildRewardsStatsRow()),

            // 3. Quick Oasis & Audio Navigation Strip
            SliverToBoxAdapter(child: _buildQuickWorldSelector()),

            // 4. Hero Bento Card (Dynamic Featured Dhikr in Pure White Marble)
            SliverToBoxAdapter(child: _buildHeroBentoCard()),

            // 5. Daily Spiritual Wisdom Card (Dynamic Rotating Wisdom)
            SliverToBoxAdapter(child: _buildSpiritualWisdomCard()),

            // 6. Section Title & Active Filter
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      'أوراد الذكر والغراس 🌿',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _shuffleAdhkarList,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E34).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.shuffle, size: 13, color: Color(0xFFFFD700)),
                            SizedBox(width: 4),
                            Text(
                              'خلط 🔀',
                              style: TextStyle(
                                fontFamily: 'GESSTwo',
                                fontSize: 10,
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_filterType != null) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _filterType = null),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD700)),
                          ),
                          child: Text(
                            '${_filterType!.displayName} ✕',
                            style: const TextStyle(
                              fontFamily: 'GESSTwo',
                              fontSize: 10,
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 7. Dynamic Colorful Bento Dhikr Cards
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dhikr = filteredAdhkar[index];
                    final count = _dhikrCounts[dhikr.id] ?? 0;
                    return _buildBentoDhikrCard(dhikr, count, index);
                  },
                  childCount: filteredAdhkar.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    final totalRewards = _rewardCounts.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const JannatiLogo(size: 46, showGlow: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                    'جَنَّتِي 🌴',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${NumberFormatter.toArabic(totalRewards)} غرسة مباركة في رياضك',
                  style: const TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'أسرار وفضائل غراس الجنة 📜',
            icon: const Icon(Icons.auto_stories_outlined, color: Color(0xFFFFD700), size: 22),
            onPressed: () => JannahVirtuesModal.show(context),
          ),
          IconButton(
            tooltip: 'مركز التنبيهات والأوراد',
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.white70, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'الجولة الإرشادية',
            icon: const Icon(Icons.help_outline, color: Colors.white70, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsStatsRow() {
    return Container(
      height: 106,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: RewardType.values.length,
        itemBuilder: (context, index) {
          final type = RewardType.values[index];
          final count = _rewardCounts[type] ?? 0;
          final isSelected = _filterType == type;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _filterType = isSelected ? null : type;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 78,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _rewardGradientStart(type),
                      _rewardGradientEnd(type),
                    ],
                  ),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFD700)
                        : Colors.white.withValues(alpha: 0.3),
                    width: isSelected ? 2.2 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFFFFD700).withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.35),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Image.asset(
                      GardenAssets.getIconAsset(type),
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),

                    // Number Count in Bright Yellow/Gold
                    Text(
                      NumberFormatter.toArabic(count),
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFEB3B),
                        height: 1.0,
                      ),
                    ),

                    // Crisp Pure White Arabic Title
                    Text(
                      type.arabicSingular,
                      style: const TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickWorldSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // 2.5D World Button
          Expanded(
            flex: 11,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JannatiIsometricScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2818).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('🌿', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 4),
                    Text(
                      'واحة 2.5D',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Audio Sanctuary Button
          Expanded(
            flex: 12,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AudioSanctuaryScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2818).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF00A8CC).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('🎵', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 4),
                    Text(
                      'إذاعة السكينة',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 3D World Button
          Expanded(
            flex: 8,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Jannati3DScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2818).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('🌌', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 3),
                    Text(
                      'عالم 3D',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBentoCard() {
    final featuredDhikr = adhkarList[_featuredDhikrIndex % adhkarList.length];
    final count = _dhikrCounts[featuredDhikr.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white, // 🤍 Pure White Marble / Ceramic Card
          border: Border.all(
            color: const Color(0xFFFFD700),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            IslamicPatternOverlay(opacity: 0.08),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '⭐ ذكر اليوم المقترح',
                          style: TextStyle(
                            fontFamily: 'GESSTwo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _rotateFeaturedDhikr,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.cached, size: 13, color: Color(0xFF2E7D32)),
                              SizedBox(width: 3),
                              Text(
                                'تغيير 🎲',
                                style: TextStyle(
                                  fontFamily: 'GESSTwo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  GardenAssets.getIconAsset(featuredDhikr.rewardType),
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              featuredDhikr.arabicText,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A2E18), // Deep Rich Emerald
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'الإجمالي: ${NumberFormatter.toArabic(count)} ${featuredDhikr.rewardType.arabicSingular}',
                  style: const TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openCounter(featuredDhikr),
                  icon: const Icon(Icons.touch_app, size: 18),
                  label: const Text(
                    'ابدأ التسبيح',
                    style: TextStyle(
                      fontFamily: 'GESSTwo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ],
        ),
            ), // Padding
          ], // Stack children
        ), // Stack
      ),
    );
  }

  Widget _buildSpiritualWisdomCard() {
    final wisdom = _jannahWisdoms[_wisdomIndex % _jannahWisdoms.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFFF9FBE7), // Warm Luminous Cream-White
          border: Border.all(
            color: const Color(0xFFC0CA33).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _rotateWisdom,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF827717).withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.refresh, color: Color(0xFF827717), size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'قبس من رياض الجنة • ${wisdom['title']}',
                          style: const TextStyle(
                            fontFamily: 'GESSTwo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF558B2F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '✨',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wisdom['quote']!,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 16,
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoDhikrCard(Dhikr dhikr, int count, int index) {
    final startColor = _rewardGradientStart(dhikr.rewardType);
    final endColor = _rewardGradientEnd(dhikr.rewardType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openCounter(dhikr),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [startColor, endColor],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container with Light Halo
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    GardenAssets.getIconAsset(dhikr.rewardType),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Text Content in Pure Crisp White
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dhikr.arabicText,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'يغرس: ${dhikr.rewardType.arabicSingular} • الإجمالي ${NumberFormatter.toArabic(count)}',
                      style: const TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 11,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Arrow Action
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCounter(Dhikr dhikr) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DhikrCounterScreen(dhikr: dhikr)),
    ).then((_) => _loadData());
  }

  Widget _buildLuxuryBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, 'الأذكار', Icons.auto_stories),
            _buildNavItem(1, 'الواحة 2.5D', Icons.park_outlined),
            _buildNavItem(2, 'السكينة 🎵', Icons.graphic_eq),
            _buildNavItem(3, 'الإحصائيات', Icons.military_tech_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onNavTap(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFFD700) : Colors.white70,
              size: 19,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
