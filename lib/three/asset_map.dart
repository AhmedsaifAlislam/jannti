import 'dart:io';
import 'package:flutter/foundation.dart';
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

/// Returns the file/asset path for a given [RewardType] and [tier].
/// If high-resolution on-demand models are downloaded locally, points to local file;
/// otherwise gracefully falls back to bundled base assets.
String assetForRewardTypeAndTier(RewardType type, int tier, {String? localModelsDir}) {
  final relativeMap = {
    RewardType.palmTree: {
      1: 'tier1/palm_seedling.glb',
      2: 'tier2/palm_small.glb',
      3: 'tier3/palm_medium.glb',
      4: 'tier4/palm_large.glb',
      5: 'tier5/palm_large.glb',
    },
    RewardType.tree: {
      1: 'tier1/green_tree_seedling.glb',
      2: 'tier2/green_tree_small.glb',
      3: 'tier3/green_tree_medium.glb',
      4: 'tier4/green_tree_large.glb',
      5: 'tier5/green_tree_large.glb',
    },
    RewardType.house: {
      1: 'house.glb',
      2: 'house.glb',
      3: 'house.glb',
      4: 'house.glb',
      5: 'house.glb',
    },
    RewardType.palace: {
      1: 'house.glb',
      2: 'palace.glb',
      3: 'palace.glb',
      4: 'palace.glb',
      5: 'palace.glb',
    },
    RewardType.mosque: {
      1: 'house.glb',
      2: 'palace.glb',
      3: 'palace.glb',
      4: 'palace.glb',
      5: 'palace.glb',
    },
    RewardType.treasure: {
      1: 'chest.glb',
      2: 'chest.glb',
      3: 'chest.glb',
      4: 'chest.glb',
      5: 'chest.glb',
    },
  };

  final typeMap = relativeMap[type];
  final relPath = typeMap?[tier] ?? typeMap?[3];

  if (relPath != null && localModelsDir != null && !kIsWeb) {
    final localPath = '$localModelsDir/$relPath';
    if (File(localPath).existsSync()) {
      return localPath;
    }
  }

  return assetForRewardType(type);
}
