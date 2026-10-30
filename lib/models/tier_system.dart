class TierSystem {
  static int calculate(int count) {
    if (count >= 10000) return 5;
    if (count >= 2000) return 4;
    if (count >= 500) return 3;
    if (count >= 100) return 2;
    return 1;
  }

  static int nextThreshold(int tier) {
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
