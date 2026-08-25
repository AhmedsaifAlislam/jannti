import 'dart:math';
import '../models/reward_type.dart';

class GardenAssets {
  GardenAssets._();

  static const String background = 'assets/images/Backround.png';
  static const String sun = 'assets/images/SUN.png';
  static const List<String> clouds = [
    'assets/images/cloud_1.png',
    'assets/images/cloud_2.png',
    'assets/images/cloud_3.png',
  ];

  static const Map<RewardType, List<String>> variations = {
    RewardType.palmTree: [
      'assets/images/palm_tree_1.png',
      'assets/images/palm_tree_2.png',
      'assets/images/palm_tree_3.png',
    ],
    RewardType.tree: [
      'assets/images/tree_1.png',
      'assets/images/tree_2.png',
      'assets/images/tree_3.png',
    ],
    RewardType.house: [
      'assets/images/house_1.png',
      'assets/images/house_2.png',
      'assets/images/house_3.png',
    ],
    RewardType.palace: [
      'assets/images/palace_1.png',
      'assets/images/palace_2.png',
      'assets/images/palace_3.png',
      'assets/images/palace_4.png',
      'assets/images/palace_5.png',
      'assets/images/palace_6.png',
    ],
    RewardType.mosque: [
      'assets/images/mosque_1.png',
      'assets/images/mosque_2.png',
      'assets/images/mosque_3.png',
      'assets/images/mosque_4.png',
    ],
    RewardType.treasure: [
      'assets/images/treasure_1.png',
      'assets/images/treasure_2.png',
    ],
  };

  static String getIconAsset(RewardType type) => variations[type]!.first;

  static String getRandomAsset(RewardType type, {int? seed}) {
    final list = variations[type]!;
    final rng = seed != null ? Random(seed) : Random();
    return list[rng.nextInt(list.length)];
  }

  static double getBaseSize(RewardType type) {
    switch (type) {
      case RewardType.palmTree:
        return 170;
      case RewardType.tree:
        return 140;
      case RewardType.house:
        return 210;
      case RewardType.mosque:
        return 310;
      case RewardType.palace:
        return 400;
      case RewardType.treasure:
        return 110;
    }
  }
}
