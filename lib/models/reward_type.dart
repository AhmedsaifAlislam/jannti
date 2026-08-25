enum RewardType {
  palmTree,
  tree,
  house,
  palace,
  mosque,
  treasure,
}

extension RewardTypeExtension on RewardType {
  String get emoji {
    switch (this) {
      case RewardType.palmTree:
        return '🌴';
      case RewardType.tree:
        return '🌳';
      case RewardType.house:
        return '🏠';
      case RewardType.palace:
        return '🏰';
      case RewardType.mosque:
        return '🕌';
      case RewardType.treasure:
        return '💎';
    }
  }

  String get arabicSingular {
    switch (this) {
      case RewardType.palmTree:
        return 'نخلة';
      case RewardType.tree:
        return 'شجرة';
      case RewardType.house:
        return 'بيت';
      case RewardType.palace:
        return 'قصر';
      case RewardType.mosque:
        return 'مسجد';
      case RewardType.treasure:
        return 'كنز';
    }
  }

  String get arabicDual {
    switch (this) {
      case RewardType.palmTree:
        return 'نخلتان';
      case RewardType.tree:
        return 'شجرتان';
      case RewardType.house:
        return 'بيتان';
      case RewardType.palace:
        return 'قصران';
      case RewardType.mosque:
        return 'مسجدان';
      case RewardType.treasure:
        return 'كنزان';
    }
  }

  String get arabicPluralFew {
    switch (this) {
      case RewardType.palmTree:
        return 'نخلات';
      case RewardType.tree:
        return 'أشجار';
      case RewardType.house:
        return 'بيوت';
      case RewardType.palace:
        return 'قصور';
      case RewardType.mosque:
        return 'مساجد';
      case RewardType.treasure:
        return 'كنوز';
    }
  }

  String get arabicPluralMany {
    return arabicSingular;
  }

  String get displayName {
    return arabicSingular;
  }
}
