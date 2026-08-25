import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reward_type.dart';
import '../utils/garden_assets.dart';
import 'islamic_pattern_overlay.dart';

class JannahVirtueItem {
  final RewardType rewardType;
  final String title;
  final String hadith;
  final String narrator;
  final String wisdom;
  final String dhikrText;
  final List<Color> gradient;

  const JannahVirtueItem({
    required this.rewardType,
    required this.title,
    required this.hadith,
    required this.narrator,
    required this.wisdom,
    required this.dhikrText,
    required this.gradient,
  });
}

class JannahVirtuesModal extends StatelessWidget {
  const JannahVirtuesModal({super.key});

  static const List<JannahVirtueItem> virtues = [
    JannahVirtueItem(
      rewardType: RewardType.palmTree,
      title: 'نخيل النعيم والسلسبيل 🌴',
      dhikrText: 'سُبْحَانَ اللَّهِ العَظِيمِ وَبِحَمْدِهِ',
      hadith: '«مَنْ قَالَ: سُبْحَانَ اللَّهِ العَظِيمِ وَبِحَمْدِهِ، غُرِسَتْ لَهُ نَخْلَةٌ فِي الجَنَّةِ»',
      narrator: 'رواه الترمذي وقال حديث حسن صحيح',
      wisdom: 'نخل الجنة جذوعها من ذهب وفضة وسعفها من سندس خضر، ثمرها أحلى من العسل وألين من الزبد.',
      gradient: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
    ),
    JannahVirtueItem(
      rewardType: RewardType.tree,
      title: 'أشجار الفردوس والظلال المديدة 🌳',
      dhikrText: 'سُبْحَانَ اللَّهِ، وَالحَمْدُ لِلَّهِ، وَلا إِلَهَ إِلا اللَّهُ، وَاللَّهُ أَكْبَرُ',
      hadith: '«لَقِيتُ إِبْرَاهِيمَ لَيْلَةَ أُسْرِيَ بِي فَقَالَ: يَا مُحَمَّدُ، أَقْرِئْ أُمَّتَكَ مِنِّي السَّلامَ وَأَخْبِرْهُمْ أَنَّ الجَنَّةَ طَيِّبَةُ التُّرْبَةِ، عَذْبَةُ المَاءِ، وَأَنَّهَا قِيعَانٌ، وَأَنَّ غِرَاسَهَا: سُبْحَانَ اللَّهِ، وَالحَمْدُ لِلَّهِ، وَلا إِلَهَ إِلا اللَّهُ، وَاللَّهُ أَكْبَرُ»',
      narrator: 'رواه الترمذي وحسنه الألباني',
      wisdom: 'شجر الجنة يسير الراكب الجواد المضمر في ظلها مائة عام لا يقطعها، تتفتح أزهارها بالمسك والريحان.',
      gradient: [Color(0xFF0D4F1F), Color(0xFF1B6F2F)],
    ),
    JannahVirtueItem(
      rewardType: RewardType.house,
      title: 'بيوت الحمد والرِّضوان 🏡',
      dhikrText: 'الحَمْدُ لِلَّهِ عَلَى كُلِّ حَال',
      hadith: '«يَقُولُ اللَّهُ تَعَالَى لِمَلائِكَتِهِ: قَبَضْتُمْ وَلَدَ عَبْدِي؟ فَيَقُولُونَ: نَعَمْ. فَيَقُولُ: قَبَضْتُمْ ثَمَرَةَ فُؤَادِهِ؟ فَيَقُولُونَ: نَعَمْ. فَيَقُولُ: فَمَاذَا قَالَ عَبْدِي؟ فَيَقُولُونَ: حَمِدَكَ وَاسْتَرْجَعَ. فَيَقُولُ اللَّهُ: ابْنُوا لِعَبْدِي بَيْتًا فِي الجَنَّةِ، وَسَمُّوهُ بَيْتَ الحَمْدِ»',
      narrator: 'رواه الترمذي وحسنه',
      wisdom: 'بيوت النعيم مبنية من لبنة ذهب ولبنة فضة، طمأنينة وسكينة أبدية لأهل الصبر والشكر.',
      gradient: [Color(0xFF0D47A1), Color(0xFF1976D2)],
    ),
    JannahVirtueItem(
      rewardType: RewardType.palace,
      title: 'قصور الإخلاص المشيدة 🏰',
      dhikrText: 'قُلْ هُوَ اللَّهُ أَحَدٌ (سورة الإخلاص)',
      hadith: '«مَنْ قَرَأَ ﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾ عَشْرَ مَرَّاتٍ، بَنَى اللَّهُ لَهُ قَصْرًا فِي الجَنَّةِ»',
      narrator: 'رواه أحمد وصححه الألباني',
      wisdom: 'قصور شامخة مشرفة على أنهار الكوثر والسلسبيل، ملاطها المسك الأذفر وحصباؤها الدر والياقوت.',
      gradient: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
    ),
    JannahVirtueItem(
      rewardType: RewardType.mosque,
      title: 'صروح النور والمساجد 🕌',
      dhikrText: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ العَظِيمِ',
      hadith: '«مَنْ بَنَى مَسْجِدًا لِلَّهِ بَنَى اللَّهُ لَهُ فِي الجَنَّةِ مِثْلَهُ»',
      narrator: 'متفق عليه (البخاري ومسلم)',
      wisdom: 'محراب ملائكي ومنابر من نور يغشاها فيض التجلي والسكينة الأبدية في روضات الجنات.',
      gradient: [Color(0xFFE65100), Color(0xFFF57C00)],
    ),
    JannahVirtueItem(
      rewardType: RewardType.treasure,
      title: 'كنوز العرش الأكبر 💎',
      dhikrText: 'لا حَوْلَ وَلا قُوَّةَ إِلا بِاللَّهِ',
      hadith: '«يَا عَبْدَ اللَّهِ بْنَ قَيْسٍ، أَلا أَدُلُّكَ عَلَى كَنْزٍ مِنْ كُنُوزِ الجَنَّةِ؟ فَقُلْتُ: بَلَى يَا رَسُولَ اللَّهِ، قَالَ: قُلْ: لا حَوْلَ وَلا قُوَّةَ إِلا بِاللَّهِ»',
      narrator: 'متفق عليه (البخاري ومسلم)',
      wisdom: 'كنز ادخره الله تحت العرش للذاكرين، يورث عزة ويقيناً وتوكلاً وفردوساً أعلى لا يفنى.',
      gradient: [Color(0xFFB78103), Color(0xFFFFD700)],
    ),
  ];

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JannahVirtuesModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF03140C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.25),
            blurRadius: 24,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Living Islamic Background
          IslamicPatternOverlay(opacity: 0.05),

          Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                // Top Drag Handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1B5E20),
                          border: Border.all(color: const Color(0xFFFFD700)),
                        ),
                        child: const Icon(Icons.auto_stories, color: Color(0xFFFFD700), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'أَسْرَارُ وَفَضَائِلُ غِرَاسِ الجَنَّةِ 📜✨',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'الكنوز النبوية الصحيحة الواردة في بناء دار الخلود',
                              style: TextStyle(
                                fontFamily: 'GESSTwo',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 20),

                // Virtues List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: virtues.length,
                    itemBuilder: (context, index) {
                      final item = virtues[index];
                      return _buildVirtueCard(item);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtueCard(JannahVirtueItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.gradient.first.withValues(alpha: 0.9),
            item.gradient.last.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Icon Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: const Color(0xFFFFD700)),
                  ),
                  child: Image.asset(
                    GardenAssets.getIconAsset(item.rewardType),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.dhikrText,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Authentic Hadith Quote Box (White Marble Glass)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.hadith,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '• ${item.narrator}',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 10,
                        color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Spiritual Secret / Wisdom
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌿 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    item.wisdom,
                    style: TextStyle(
                      fontFamily: 'GESSTwo',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
