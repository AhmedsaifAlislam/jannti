import '../models/reward_type.dart';

String assetForRewardType(RewardType t) {
  switch (t) {
    case RewardType.palmTree:
      return 'assets/3d/palm.glb';
    case RewardType.tree:
      return 'assets/3d/tree.glb';
    case RewardType.house:
      return 'assets/3d/house.glb';
    case RewardType.palace:
      return 'assets/3d/palace.glb';
    case RewardType.mosque:
      return 'assets/3d/palace.glb';
    case RewardType.treasure:
      return 'assets/3d/chest.glb';
  }
}

String assetForRewardTypeAndTier(RewardType type, int tier) {
  const tierAssets = {
    // تسبيح كامل → نخلة متدرجة النمو
    RewardType.palmTree: {
      1: 'assets/3d/tier1/palm_seedling.glb',
      2: 'assets/3d/tier2/palm_small.glb',
      3: 'assets/3d/tier3/palm_medium.glb',
      4: 'assets/3d/tier4/palm_large.glb',
      5: 'assets/3d/tier5/palm_large.glb',
    },

    // حمد وباقيات صالحات → شجرة متدرجة النمو
    RewardType.tree: {
      1: 'assets/3d/tier1/green_tree_seedling.glb',
      2: 'assets/3d/tier2/green_tree_small.glb',
      3: 'assets/3d/tier3/green_tree_medium.glb',
      4: 'assets/3d/tier4/green_tree_large.glb',
      5: 'assets/3d/tier5/green_tree_large.glb',
    },

    // بيوت
    RewardType.house: {
      1: 'assets/3d/house.glb',
      2: 'assets/3d/house.glb',
      3: 'assets/3d/house.glb',
      4: 'assets/3d/house.glb',
      5: 'assets/3d/house.glb',
    },

    // قصور ومساجد
    RewardType.palace: {
      1: 'assets/3d/house.glb',
      2: 'assets/3d/palace.glb',
      3: 'assets/3d/palace.glb',
      4: 'assets/3d/palace.glb',
      5: 'assets/3d/palace.glb',
    },
    RewardType.mosque: {
      1: 'assets/3d/house.glb',
      2: 'assets/3d/palace.glb',
      3: 'assets/3d/palace.glb',
      4: 'assets/3d/palace.glb',
      5: 'assets/3d/palace.glb',
    },

    // كنوز
    RewardType.treasure: {
      1: 'assets/3d/chest.glb',
      2: 'assets/3d/chest.glb',
      3: 'assets/3d/chest.glb',
      4: 'assets/3d/chest.glb',
      5: 'assets/3d/chest.glb',
    },
  };

  final typeMap = tierAssets[type];
  if (typeMap == null) return assetForRewardType(type);

  return typeMap[tier] ?? typeMap[3] ?? assetForRewardType(type);
}
