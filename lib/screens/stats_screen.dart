import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reward_type.dart';
import '../models/spiritual_rank.dart';
import '../services/storage_service.dart';
import '../utils/garden_assets.dart';
import '../utils/number_formatter.dart';
import '../widgets/islamic_pattern_overlay.dart';

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

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  int _calculateTier(int count) {
    if (count >= 10000) return 5;
    if (count >= 2000) return 4;
    if (count >= 500) return 3;
    if (count >= 100) return 2;
    return 1;
  }

  int _nextTierThreshold(int tier) {
    switch (tier) {
      case 1:
        return 100;
      case 2:
        return 500;
      case 3:
        return 2000;
      case 4:
        return 10000;
      default:
        return 10000;
    }
  }

  String _tierTitle(int tier) {
    switch (tier) {
      case 1:
        return 'مرتبة الغرس الأولي (Tier 1)';
      case 2:
        return 'مرتبة النماء والازدهار (Tier 2)';
      case 3:
        return 'مرتبة العطاء والبركة (Tier 3)';
      case 4:
        return 'مرتبة الوفاء والارتقاء (Tier 4)';
      case 5:
        return 'مرتبة النور والخلود (Tier 5)';
      default:
        return 'المرتبة $tier';
    }
  }

  void _showAllRanksModal(int totalDhikr) {
    HapticFeedback.lightImpact();
    final currentRank = SpiritualRanksData.getCurrentRank(totalDhikr);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.84,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF072417).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: const [
                  Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'سُلَّمُ مَرَاتِبِ الارْتِقَاءِ الـ 14 🌟',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'كلما زادت تسبيحاتك وأذكارك ارتقيت في مراتب الجنان وتفتحت لك أبواب النعيم',
                style: TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Divider(color: Colors.white12, height: 20),

              // Ranks List
              Expanded(
                child: ListView.builder(
                  itemCount: SpiritualRanksData.allRanks.length,
                  itemBuilder: (context, index) {
                    final rank = SpiritualRanksData.allRanks[index];
                    final isUnlocked = totalDhikr >= rank.minDhikr;
                    final isCurrent = rank.level == currentRank.level;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: isCurrent
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.85)
                            : isUnlocked
                                ? const Color(0xFF0D2818).withValues(alpha: 0.85)
                                : Colors.black.withValues(alpha: 0.3),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFFFD700)
                              : isUnlocked
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                                  : Colors.white10,
                          width: isCurrent ? 2.0 : 1.0,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Level badge
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent
                                  ? const Color(0xFFFFD700)
                                  : isUnlocked
                                      ? const Color(0xFF2E7D32)
                                      : Colors.white10,
                            ),
                            child: Center(
                              child: Text(
                                rank.icon,
                                style: const TextStyle(fontSize: 19),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Rank Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rank.title,
                                        style: TextStyle(
                                          fontFamily: 'Amiri',
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: isUnlocked
                                              ? (isCurrent ? const Color(0xFFFFD700) : Colors.white)
                                              : Colors.white38,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'رتبتك الحالية',
                                          style: TextStyle(
                                            fontFamily: 'GESSTwo',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rank.description,
                                  style: TextStyle(
                                    fontFamily: 'GESSTwo',
                                    fontSize: 10,
                                    color: isUnlocked
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : Colors.white30,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'المطلوب: ${NumberFormatter.toArabic(rank.minDhikr)} تسبيحة',
                                  style: TextStyle(
                                    fontFamily: 'GESSTwo',
                                    fontSize: 10,
                                    color: isCurrent
                                        ? const Color(0xFFFFD700)
                                        : (isUnlocked ? const Color(0xFF81C784) : Colors.white24),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Lock / Unlocked Status Icon
                          Icon(
                            isUnlocked ? Icons.check_circle : Icons.lock_outline,
                            color: isCurrent
                                ? const Color(0xFFFFD700)
                                : isUnlocked
                                    ? const Color(0xFF81C784)
                                    : Colors.white24,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
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
    final allRewards = _storage.getAllRewards();
    final countsByType = <RewardType, int>{};
    for (final r in allRewards) {
      countsByType[r.type] = (countsByType[r.type] ?? 0) + 1;
    }

    final totalRewards = allRewards.length;
    final allDhikrCounts = _storage.getAllDhikrCounts();
    final totalDhikrCount = allDhikrCounts.values.fold(0, (sum, val) => sum + val);

    int maxTier = 1;
    for (final type in RewardType.values) {
      final t = _calculateTier(countsByType[type] ?? 0);
      if (t > maxTier) maxTier = t;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF03140C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2818).withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'متحف الإنجازات والأوسمة 🏆✨',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. Top Royal Hero Summary Section
            _buildHeroSummarySection(totalDhikrCount, totalRewards, maxTier),

            const SizedBox(height: 24),

            // 2. Section Header: Rewards Breakdown
            Row(
              children: const [
                Icon(Icons.park_outlined, color: Color(0xFFFFD700), size: 22),
                SizedBox(width: 8),
                Text(
                  'حصاد غراس الجنة ومراتب النماء',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Category Progress Cards
            ...RewardType.values.map((type) {
              final count = countsByType[type] ?? 0;
              final tier = _calculateTier(count);
              final nextThreshold = _nextTierThreshold(tier);
              final progress = (count / nextThreshold).clamp(0.0, 1.0);

              return _buildCategoryCard(type, count, tier, nextThreshold, progress);
            }),

            const SizedBox(height: 24),

            // 4. Section Header: Milestones & Badges
            Row(
              children: const [
                Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 22),
                SizedBox(width: 8),
                Text(
                  'أوسمة الارتقاء الروحاني الـ 14',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. 3D-Styled Colorful Achievements Grid
            _buildAchievementsGrid(totalDhikrCount, totalRewards, countsByType, maxTier),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🏛️ HERO SUMMARY CARD WITH SOLE INTUITIVE CENTRAL RANK BANNER
  // =========================================================================

  Widget _buildHeroSummarySection(int totalDhikr, int totalRewards, int maxTier) {
    final currentRank = SpiritualRanksData.getCurrentRank(totalDhikr);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white, // 🤍 Pure White Ceramic Card
        borderRadius: BorderRadius.circular(28),
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
          // 1. Subtle Islamic Arabesque Watermark Texture
          IslamicPatternOverlay(opacity: 0.08),

          // 2. Card Content Layout
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.stars, color: Color(0xFFC67D00), size: 24),
                        SizedBox(width: 6),
                        Text(
                          'رصيدك الروحاني المبارك',
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2E18),
                          ),
                        ),
                      ],
                    ),
                    // Non-conflicting static level badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'الرتبة ${currentRank.level} من 14',
                        style: const TextStyle(
                          fontFamily: 'GESSTwo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Sole Interactive Central Rank Card (Tap to view full ranks ladder)
                InkWell(
                  onTap: () => _showAllRanksModal(totalDhikr),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE8F5E9),
                          Color(0xFFC8E6C9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.5), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1B5E20),
                          ),
                          child: Center(
                            child: Text(currentRank.icon, style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentRank.title,
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A2E18),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'المس هنا لاستعراض سلم الألقاب الـ 14 ✨',
                                style: TextStyle(
                                  fontFamily: 'GESSTwo',
                                  fontSize: 10,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1B5E20)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3 Segmented Professional Metric Tiles
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'إجمالي الأذكار',
                        value: NumberFormatter.toArabic(totalDhikr),
                        icon: Icons.fingerprint,
                        color: const Color(0xFF1B5E20),
                        bgColor: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'غراس الجنة',
                        value: NumberFormatter.toArabic(totalRewards),
                        icon: Icons.eco,
                        color: const Color(0xFF0D47A1),
                        bgColor: const Color(0xFFE3F2FD),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'أعلى مرتبة',
                        value: 'المستوى $maxTier',
                        icon: Icons.auto_awesome,
                        color: const Color(0xFFE65100),
                        bgColor: const Color(0xFFFFF3E0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'GESSTwo',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🎴 DYNAMIC COLORFUL CATEGORY PROGRESS CARDS
  // =========================================================================

  Widget _buildCategoryCard(
    RewardType type,
    int count,
    int tier,
    int nextThreshold,
    double progress,
  ) {
    final startColor = _rewardGradientStart(type);
    final endColor = _rewardGradientEnd(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Image.asset(
                  GardenAssets.getIconAsset(type),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _tierTitle(tier),
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                ),
                child: Text(
                  '${NumberFormatter.toArabic(count)} غرسة',
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقدم نحو المستوى التالي',
                style: TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              Text(
                '${NumberFormatter.toArabic(count)} / ${NumberFormatter.toArabic(nextThreshold)}',
                style: const TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🌟 3D-STYLED COLORFUL ACHIEVEMENTS GRID (14 ALIGNED MEDALS)
  // =========================================================================

  Widget _buildAchievementsGrid(
    int totalDhikr,
    int totalRewards,
    Map<RewardType, int> counts,
    int maxTier,
  ) {
    final badges = [
      _Badge(
        title: 'غَارِسٌ مُبْتَدِئ 🌱',
        desc: 'أولى خطوات الغرس المبارك (1+ ذكر)',
        icon: '🌱',
        imageAsset: GardenAssets.getIconAsset(RewardType.tree),
        colors: [const Color(0xFF1B5E20), const Color(0xFF00E676)],
        unlocked: totalDhikr >= 1,
      ),
      _Badge(
        title: 'مُسَبِّحٌ أَوَّاب 🌿',
        desc: 'رطوبة اللسان بـ 50 تسبيحة',
        icon: '🌿',
        imageAsset: GardenAssets.getIconAsset(RewardType.tree),
        colors: [const Color(0xFF0D4F1F), const Color(0xFF2E7D32)],
        unlocked: totalDhikr >= 50,
      ),
      _Badge(
        title: 'سَاقِي الرِّيَاض 🍃',
        desc: 'عناية مستمرة بـ 150 تسبيحة',
        icon: '🍃',
        imageAsset: GardenAssets.getIconAsset(RewardType.palmTree),
        colors: [const Color(0xFF006064), const Color(0xFF00ACC1)],
        unlocked: totalDhikr >= 150,
      ),
      _Badge(
        title: 'زَارِعُ الفِرْدَوْس 🌴',
        desc: 'غرس واحة يانعة بـ 300 تسبيحة',
        icon: '🌴',
        imageAsset: GardenAssets.getIconAsset(RewardType.palmTree),
        colors: [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
        unlocked: totalDhikr >= 300,
      ),
      _Badge(
        title: 'خَازِنُ الأَنْوَار 💎',
        desc: 'ادخار كنوز العرش بـ 600 تسبيحة',
        icon: '💎',
        imageAsset: GardenAssets.getIconAsset(RewardType.treasure),
        colors: [const Color(0xFF0D47A1), const Color(0xFF29B6F6)],
        unlocked: totalDhikr >= 600,
      ),
      _Badge(
        title: 'سَاكِنُ الجِنَان 🏡',
        desc: 'بنيان بيوت الجنة بـ 1,000 تسبيحة',
        icon: '🏡',
        imageAsset: GardenAssets.getIconAsset(RewardType.house),
        colors: [const Color(0xFF311B92), const Color(0xFF7E57C2)],
        unlocked: totalDhikr >= 1000,
      ),
      _Badge(
        title: 'عَمَّارُ المَسَاجِد 🕌',
        desc: 'عمارة صروح النور بـ 2,000 تسبيحة',
        icon: '🕌',
        imageAsset: GardenAssets.getIconAsset(RewardType.mosque),
        colors: [const Color(0xFFE65100), const Color(0xFFFFA726)],
        unlocked: totalDhikr >= 2000,
      ),
      _Badge(
        title: 'أَمِيرُ الفِرْدَوْس 🏰',
        desc: 'قصور مشيدة بـ 3,500 تسبيحة',
        icon: '🏰',
        imageAsset: GardenAssets.getIconAsset(RewardType.palace),
        colors: [const Color(0xFF4A148C), const Color(0xFFAB47BC)],
        unlocked: totalDhikr >= 3500,
      ),
      _Badge(
        title: 'سَيِّدُ الذَّاكِرِين 🌟',
        desc: 'منارات ذكر ساطعة بـ 5,000 تسبيحة',
        icon: '🌟',
        colors: [const Color(0xFFF57F17), const Color(0xFFFFD54F)],
        unlocked: totalDhikr >= 5000,
      ),
      _Badge(
        title: 'صَاحِبُ السِّدْرَة 👑',
        desc: 'قرب من سدرة المنتهى بـ 7,500 تسبيحة',
        icon: '👑',
        colors: [const Color(0xFF880E4F), const Color(0xFFEC407A)],
        unlocked: totalDhikr >= 7500,
      ),
      _Badge(
        title: 'وَلِيُّ الرَّحْمَن 🕊️',
        desc: 'نور يسعى بين يديه بـ 10,000 تسبيحة',
        icon: '🕊️',
        colors: [const Color(0xFF004D40), const Color(0xFF26A69A)],
        unlocked: totalDhikr >= 10000,
      ),
      _Badge(
        title: 'عَارِفٌ بِاللَّه 💫',
        desc: 'يقين وإخلاص بـ 20,000 تسبيحة',
        icon: '💫',
        colors: [const Color(0xFF01579B), const Color(0xFF00E5FF)],
        unlocked: totalDhikr >= 20000,
      ),
      _Badge(
        title: 'صَاحِبُ المَقَام 🌌',
        desc: 'منابر من نور بـ 50,000 تسبيحة',
        icon: '🌌',
        colors: [const Color(0xFF3E2723), const Color(0xFF8D6E63)],
        unlocked: totalDhikr >= 50000,
      ),
      _Badge(
        title: 'نُورُ السَّمَاوَات ☀️',
        desc: 'أعلى وسام خلود بـ 100,000 تسبيحة',
        icon: '☀️',
        colors: [const Color(0xFFE65100), const Color(0xFFFFD700)],
        unlocked: totalDhikr >= 100000,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final b = badges[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: b.unlocked
                  ? [
                      b.colors.first.withValues(alpha: 0.95),
                      b.colors.last.withValues(alpha: 0.85),
                    ]
                  : [
                      const Color(0xFF15201A),
                      const Color(0xFF0B1410),
                    ],
            ),
            border: Border.all(
              color: b.unlocked
                  ? const Color(0xFFFFD700)
                  : Colors.white12,
              width: b.unlocked ? 1.6 : 1.0,
            ),
            boxShadow: b.unlocked
                ? [
                    BoxShadow(
                      color: b.colors.first.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, -1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 3D Sculpted Medallion with Double-Bezel & Radial Depth
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    radius: 0.8,
                    colors: b.unlocked
                        ? [
                            Colors.white.withValues(alpha: 0.45),
                            const Color(0xFF1B5E20).withValues(alpha: 0.6),
                            Colors.black.withValues(alpha: 0.35),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.4),
                          ],
                  ),
                  border: Border.all(
                    color: b.unlocked
                        ? const Color(0xFFFFD700)
                        : Colors.white24,
                    width: 2.0,
                  ),
                  boxShadow: b.unlocked
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Colors.black45,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: b.imageAsset != null
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            b.imageAsset!,
                            fit: BoxFit.contain,
                            color: b.unlocked ? null : Colors.white30,
                            colorBlendMode: b.unlocked ? null : BlendMode.srcIn,
                          ),
                        )
                      : Text(
                          b.icon,
                          style: TextStyle(
                            fontSize: 26,
                            shadows: b.unlocked
                                ? const [
                                    Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
                                    Shadow(color: Color(0xFFFFD700), blurRadius: 8),
                                  ]
                                : null,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                b.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: b.unlocked ? Colors.white : Colors.white38,
                  shadows: b.unlocked
                      ? const [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                        ]
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                b.desc,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 10,
                  color: b.unlocked ? Colors.white.withValues(alpha: 0.9) : Colors.white24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge {
  final String title;
  final String desc;
  final String icon;
  final String? imageAsset;
  final List<Color> colors;
  final bool unlocked;

  _Badge({
    required this.title,
    required this.desc,
    required this.icon,
    this.imageAsset,
    required this.colors,
    required this.unlocked,
  });
}


