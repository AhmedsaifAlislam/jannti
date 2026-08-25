import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dhikr.dart';
import '../models/reward.dart';
import '../models/reward_type.dart';
import '../services/storage_service.dart';
import '../utils/garden_assets.dart';
import '../utils/number_formatter.dart';
import '../widgets/islamic_pattern_overlay.dart';

class DhikrCounterScreen extends StatefulWidget {
  final Dhikr dhikr;
  const DhikrCounterScreen({super.key, required this.dhikr});

  @override
  State<DhikrCounterScreen> createState() => _DhikrCounterScreenState();
}

class _FloatingSeed {
  final int id;
  final Offset startPos;
  final AnimationController controller;
  final RewardType rewardType;

  _FloatingSeed({
    required this.id,
    required this.startPos,
    required this.controller,
    required this.rewardType,
  });
}

class _DhikrCounterScreenState extends State<DhikrCounterScreen>
    with TickerProviderStateMixin {
  final StorageService _storage = StorageService();

  int _sessionCount = 0;
  int _totalCount = 0;
  int _targetCycle = 33; // 33, 100, or 0 for infinite
  int _seedId = 0;
  bool _isZenFullscreenMode = false;

  final List<_FloatingSeed> _floatingSeeds = [];
  final List<_ZenRipple> _zenRipples = [];

  late AnimationController _pulseController;
  late AnimationController _bloomController;
  late AnimationController _tapAnimationController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _totalCount = _storage.getDhikrCount(widget.dhikr.id);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _tapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _tapScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _tapAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    for (final s in _floatingSeeds) {
      s.controller.dispose();
    }
    _pulseController.dispose();
    _bloomController.dispose();
    _tapAnimationController.dispose();
    super.dispose();
  }

  void _onTasbeehTap() {
    _tapAnimationController.forward().then((_) => _tapAnimationController.reverse());
    HapticFeedback.lightImpact();

    setState(() {
      _sessionCount++;
      _totalCount++;
    });

    unawaited(_storage.saveDhikrCount(widget.dhikr.id, _totalCount));

    final reward = Reward(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: widget.dhikr.rewardType,
      posX: Random().nextDouble(),
      posY: 0.4 + (Random().nextDouble() * 0.5),
      earnedAt: DateTime.now(),
      dhikrId: widget.dhikr.id,
    );
    unawaited(_storage.addReward(reward));

    _spawnFloatingSeed();

    // Check Cycle Milestones
    final cycleProgress = _targetCycle > 0 ? _sessionCount % _targetCycle : _sessionCount % 33;
    if (cycleProgress == 0 && _sessionCount > 0) {
      _onCycleComplete();
    }
  }

  void _onCycleComplete() {
    _bloomController.forward(from: 0.0);
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1B5E34),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                ),
                child: Image.asset(
                  GardenAssets.getIconAsset(widget.dhikr.rewardType),
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text: 'مبارك! أتممت الدورة وغرست ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: widget.dhikr.rewardType.arabicSingular,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      const TextSpan(
                        text: ' في جنتك 🌿✨',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF0C301A),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
        ),
      ),
    );
  }

  void _spawnFloatingSeed() {
    final key = _seedId++;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    final seed = _FloatingSeed(
      id: key,
      startPos: Offset((Random().nextDouble() * 120) - 60, 0),
      controller: controller,
      rewardType: widget.dhikr.rewardType,
    );

    setState(() => _floatingSeeds.add(seed));

    controller.forward().then((_) {
      if (mounted) {
        setState(() => _floatingSeeds.removeWhere((s) => s.id == key));
        controller.dispose();
      }
    });
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D2818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            ),
          ),
          title: const Text(
            'إعادة ضبط عداد الجلسة',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD700),
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'سيتم تصفير عداد هذه الجلسة فقط، بينما يظل إجمالي غراسك (${NumberFormatter.toArabic(_totalCount)} ${widget.dhikr.rewardType.arabicSingular}) محفوظاً في رياض الجنة.',
            style: const TextStyle(
              fontFamily: 'GESSTwo',
              fontSize: 13,
              color: Colors.white70,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _sessionCount = 0);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'تصفير',
                style: TextStyle(fontFamily: 'GESSTwo', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHadithModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2818).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.menu_book, color: Color(0xFFFFD700), size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'فضل الذكر في السنة النبوية',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Text(
                widget.dhikr.hadith,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 18,
                  color: Colors.white,
                  height: 1.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E34).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                ),
                child: Text(
                  '🌱 يغرس لك: ${widget.dhikr.rewardType.arabicSingular}',
                  style: const TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 12,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: const Color(0xFFFFD700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(fontFamily: 'GESSTwo', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCycleTarget = _targetCycle > 0 ? _targetCycle : 33;
    final currentInCycle = _sessionCount % activeCycleTarget;

    if (_isZenFullscreenMode) {
      return _buildZenFullscreenSanctuary(activeCycleTarget, currentInCycle);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020E08),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Spiritual Glow Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glow = 0.25 + _pulseController.value * 0.15;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        const Color(0xFF1B5E34).withValues(alpha: glow),
                        const Color(0xFF082216),
                        const Color(0xFF020E08),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  // Top Navigation & Stats Bar
                  _buildHeaderBar(),

                  // Dhikr Sacred Arabic Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _buildSacredDhikrCard(),
                  ),

                  // Target Cycle Selector Pills (33 / 100 / ∞)
                  _buildTargetSelector(),

                  const Spacer(),

                  // Centerpiece: The Sacred Blooming Lotus Counter
                  GestureDetector(
                    onTap: _onTasbeehTap,
                    child: ScaleTransition(
                      scale: _tapScale,
                      child: SizedBox(
                        width: 270,
                        height: 270,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 33 Petal Glowing Lotus Painter
                            CustomPaint(
                              size: const Size(270, 270),
                              painter: _BloomingLotusPainter(
                                completedPetals: currentInCycle,
                                totalPetals: activeCycleTarget,
                                glowIntensity: _pulseController.value,
                              ),
                            ),

                            // Central Sacred Core Pebble
                            Container(
                              width: 175,
                              height: 175,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFF2E8A4E),
                                    Color(0xFF1B5E34),
                                    Color(0xFF0C301A),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.75),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.25),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    NumberFormatter.toArabic(_sessionCount),
                                    style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFD700),
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    widget.dhikr.actionLabel,
                                    style: TextStyle(
                                      fontFamily: 'GESSTwo',
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom Total Rewards Strip
                  _buildBottomGardenLink(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 3. Floating Golden Seeds Drops
          ..._buildFloatingSeedSprites(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'وضع الخشوع بملء الشاشة 🌌',
            icon: const Icon(Icons.fullscreen, color: Color(0xFFFFD700), size: 24),
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() => _isZenFullscreenMode = true);
            },
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2818).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  GardenAssets.getIconAsset(widget.dhikr.rewardType),
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
                Text(
                  'غرس: ${widget.dhikr.rewardType.arabicSingular}',
                  style: const TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 12,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'إعادة تصفير العداد',
            icon: const Icon(Icons.refresh, color: Colors.white60, size: 22),
            onPressed: _showResetDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSacredDhikrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.dhikr.arabicText,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showHadithModal,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_stories, color: Color(0xFFFFD700), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'عرض فضل الذكر والحديث الشريف',
                    style: TextStyle(
                      fontFamily: 'GESSTwo',
                      fontSize: 12,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [33, 100, 0].map((t) {
          final isSelected = _targetCycle == t;
          final label = t == 0 ? 'مفتوح ∞' : '$t تسبيحة';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: () => setState(() => _targetCycle = t),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                      : const Color(0xFF0D2818).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFFFD700).withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFFFFD700) : Colors.white60,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomGardenLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2818).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset(
                  GardenAssets.getIconAsset(widget.dhikr.rewardType),
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي رصيد الغراس',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${NumberFormatter.toArabic(_totalCount)} ${widget.dhikr.rewardType.arabicSingular}',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFFFD700), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFloatingSeedSprites() {
    return _floatingSeeds.map((seed) {
      final progress = seed.controller.value;

      // 1. Smooth physical rising curve
      final curvedProgress = Curves.easeOutCubic.transform(progress);
      final dy = -curvedProgress * 220.0;

      // 2. Fluid Scale: Starts at 0.35, blossoms to 1.25, then settles to 1.0
      double scale;
      if (progress < 0.3) {
        scale = 0.35 + (progress / 0.3) * 0.90; // 0.35 -> 1.25
      } else if (progress < 0.6) {
        scale = 1.25 - ((progress - 0.3) / 0.3) * 0.25; // 1.25 -> 1.0
      } else {
        scale = 1.0 - ((progress - 0.6) / 0.4) * 0.15; // 1.0 -> 0.85
      }

      // 3. Fluid Opacity: Instant soft fade-in, long visible sustain, smooth soft fade-out
      double opacity;
      if (progress < 0.15) {
        opacity = progress / 0.15; // 0.0 -> 1.0
      } else if (progress < 0.65) {
        opacity = 1.0;
      } else {
        opacity = (1.0 - ((progress - 0.65) / 0.35)).clamp(0.0, 1.0);
      }

      return Positioned(
        bottom: 230,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Transform.translate(
            offset: Offset(seed.startPos.dx, dy),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.65),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFF00E676).withValues(alpha: 0.45),
                          blurRadius: 32,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      GardenAssets.getIconAsset(seed.rewardType),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildZenFullscreenSanctuary(int activeCycleTarget, int currentInCycle) {
    final progress = activeCycleTarget > 0 ? (currentInCycle / activeCycleTarget).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF010A06),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _onZenTap(details.globalPosition),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Living Cosmic Background
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final glow = 0.2 + _pulseController.value * 0.15;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFF1B5E34).withValues(alpha: glow),
                        const Color(0xFF04180E),
                        const Color(0xFF010A06),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 2. Dynamic Touch Ripples
            ..._zenRipples.map((ripple) {
              return AnimatedBuilder(
                animation: ripple.controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ZenTouchRipplePainter(
                      center: ripple.position,
                      progress: ripple.controller.value,
                    ),
                  );
                },
              );
            }),

            // 3. Floating Seeds
            ..._buildFloatingSeedSprites(),

            // 4. Zen Content Layout
            SafeArea(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      // Top Exit & Controls Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'العودة للوضع العادي',
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                              ),
                              child: const Icon(Icons.fullscreen_exit, color: Color(0xFFFFD700), size: 22),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isZenFullscreenMode = false);
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2818).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  GardenAssets.getIconAsset(widget.dhikr.rewardType),
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'الدورة: ${NumberFormatter.toArabic(currentInCycle)} / ${NumberFormatter.toArabic(activeCycleTarget)}',
                                  style: const TextStyle(
                                    fontFamily: 'GESSTwo',
                                    fontSize: 12,
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'تصفير الجلسة',
                            icon: const Icon(Icons.refresh, color: Colors.white60, size: 22),
                            onPressed: _showResetDialog,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Sacred Dhikr Text
                      Text(
                        widget.dhikr.arabicText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.6,
                          shadows: [
                            Shadow(color: Color(0xFFFFD700), blurRadius: 16),
                            Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Large 3D Ceramic Centerpiece Counter
                      Container(
                        width: 220,
                        height: 220,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white, // 🤍 Pure White Marble
                          border: Border.all(color: const Color(0xFFFFD700), width: 3.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.3),
                              blurRadius: 50,
                              spreadRadius: 4,
                            ),
                            const BoxShadow(
                              color: Colors.black45,
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IslamicPatternOverlay(opacity: 0.09),
                            // Progress Circular Ring
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                backgroundColor: const Color(0xFFE0E0E0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B5E20)),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  NumberFormatter.toArabic(_sessionCount),
                                  style: const TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 58,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A2E18),
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.dhikr.actionLabel,
                                  style: const TextStyle(
                                    fontFamily: 'GESSTwo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Bottom Zen Guidance Note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('🕊️ ', style: TextStyle(fontSize: 14)),
                            Text(
                              'المس في أي مكان على الشاشة للتسبيح المبارك',
                              style: TextStyle(
                                fontFamily: 'GESSTwo',
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onZenTap(Offset position) {
    _onTasbeehTap();
    final key = _seedId++;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final ripple = _ZenRipple(
      id: key,
      position: position,
      controller: controller,
    );

    setState(() => _zenRipples.add(ripple));
    controller.forward().then((_) {
      if (mounted) {
        setState(() => _zenRipples.removeWhere((r) => r.id == key));
        controller.dispose();
      }
    });
  }
}

class _ZenRipple {
  final int id;
  final Offset position;
  final AnimationController controller;

  _ZenRipple({
    required this.id,
    required this.position,
    required this.controller,
  });
}

class _ZenTouchRipplePainter extends CustomPainter {
  final Offset center;
  final double progress;

  _ZenTouchRipplePainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final radius = 20.0 + progress * 90.0;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: opacity * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - progress * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final linePaint = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: opacity * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ZenTouchRipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =========================================================================
// 🌸 SACRED BLOOMING LOTUS PAINTER
// =========================================================================

class _BloomingLotusPainter extends CustomPainter {
  final int completedPetals;
  final int totalPetals;
  final double glowIntensity;

  _BloomingLotusPainter({
    required this.completedPetals,
    required this.totalPetals,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final petalCount = totalPetals;

    // Outer Delicate Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw Sacred Petal Beads
    for (int i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * pi * 2 - (pi / 2);
      final px = center.dx + cos(angle) * radius;
      final py = center.dy + sin(angle) * radius;
      final isCompleted = i < completedPetals;
      final isActive = i == completedPetals;

      if (isCompleted) {
        // Glowing Golden Completed Bead
        final beadGlow = Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(px, py), 6.5, beadGlow);

        final beadCore = Paint()..color = const Color(0xFFFFD700);
        canvas.drawCircle(Offset(px, py), 4.5, beadCore);
      } else if (isActive) {
        // Active Pulsing Bead
        final activeR = 5.0 + glowIntensity * 2.5;
        final activeGlow = Paint()
          ..color = const Color(0xFF00E676).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(px, py), activeR + 2, activeGlow);

        final activeCore = Paint()..color = const Color(0xFF69F0AE);
        canvas.drawCircle(Offset(px, py), activeR, activeCore);
      } else {
        // Empty Dim Bead
        final emptyBead = Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), 3.0, emptyBead);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BloomingLotusPainter oldDelegate) {
    return oldDelegate.completedPetals != completedPetals ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}

