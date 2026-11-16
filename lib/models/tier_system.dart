/// Player rank milestones.
///
/// These mirror the visual model ladder in `lib/three/model_evolution.dart`:
/// tier 2 begins at 100 rewards, tier 3 at 1000, tier 4 at 5000 and tier 5 at
/// 10000. The garden's *stage* (base / grow / colour / transform) is richer
/// than this rank, but the tier number always matches.
class TierSystem {
  static int calculate(int count) {
    if (count >= 10000) return 5;
    if (count >= 5000) return 4;
    if (count >= 1000) return 3;
    if (count >= 100) return 2;
    return 1;
  }

  static int nextThreshold(int tier) {
    switch (tier) {
      case 1:
        return 100;
      case 2:
        return 1000;
      case 3:
        return 5000;
      case 4:
        return 10000;
      default:
        return 10000;
    }
  }

  static String title(int tier) {
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
}
