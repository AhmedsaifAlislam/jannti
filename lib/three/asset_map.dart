import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/reward_type.dart';

/// Bundled model of a reward type that has no staged (tiered) variants.
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

/// Stage-by-stage models, keyed by relative path inside a models root.
///
/// The same table serves two roots:
///   * the on-demand download bundle (`localModelsDir`, the `models-v1`
///     Release asset), which carries a full tier1..tier5 tree, and
///   * the copy that ships inside the APK under `assets/3d/`.
///
/// Only [RewardType.palmTree] and [RewardType.tree] have real stages. The
/// buildings keep their hand-built procedural meshes on purpose: the GLB house
/// and palace are lower fidelity than what the scene draws today.
///
/// Where a stage has no model of its own we point at the nearest one that
/// exists. `_loadGLB` already scales every stage to its own height
/// (7 / 9 / 11 / 14 / 18), so a reused file still reads as a bigger tree.
const Map<RewardType, Map<int, String>> kTierModelPaths = {
  RewardType.palmTree: {
    1: 'tier1/palm_seedling.glb',
    2: 'tier2/palm_small.glb',
    3: 'tier3/palm_medium.glb',
    4: 'tier4/palm_large.glb',
    5: 'tier4/palm_large.glb',
  },
  RewardType.tree: {
    1: 'tier1/green_tree_seedling.glb',
    2: 'tier2/green_tree_small.glb',
    3: 'tier3/green_tree_medium.glb',
    4: 'tier3/green_tree_medium.glb',
    5: 'tier5/fantasy_tree.glb',
  },
};

/// Every model file the APK ships. Must stay in sync with `pubspec.yaml`;
/// `test/asset_map_test.dart` fails when the two drift apart.
const Set<String> kBundledModelAssets = {
  'assets/3d/tier1/palm_seedling.glb',
  'assets/3d/tier2/palm_small.glb',
  'assets/3d/tier3/palm_medium.glb',
  'assets/3d/tier4/palm_large.glb',
  'assets/3d/tier1/green_tree_seedling.glb',
  'assets/3d/tier2/green_tree_small.glb',
  'assets/3d/tier3/green_tree_medium.glb',
  'assets/3d/tier5/fantasy_tree.glb',
};

/// Whether [type] has staged models at all.
bool hasTierModels(RewardType type) => kTierModelPaths.containsKey(type);

/// Relative path (`tier3/palm_medium.glb`) for [type] at [tier], or null when
/// [type] has no staged lineage. Tiers outside 1..5 clamp into range.
String? tierRelativePath(RewardType type, int tier) {
  final stages = kTierModelPaths[type];
  if (stages == null) return null;
  return stages[tier.clamp(1, 5)] ?? stages[3];
}

/// The model to load for [type] at [tier], or null when the scene should keep
/// its procedural mesh.
///
/// Priority: a downloaded high-resolution file if one is on disk, then the
/// bundled asset, then null. Checking existence per file means a partial
/// download (or an older bundle without the newest stage) still resolves
/// instead of failing.
String? resolveTierModelPath(
  RewardType type,
  int tier, {
  String? localModelsDir,
}) {
  final rel = tierRelativePath(type, tier);
  if (rel == null) return null;

  if (localModelsDir != null && !kIsWeb) {
    final localPath = '$localModelsDir/$rel';
    if (File(localPath).existsSync()) return localPath;
  }

  final bundled = 'assets/3d/$rel';
  return kBundledModelAssets.contains(bundled) ? bundled : null;
}

/// Returns the best path for [type] and [tier], falling back to the generic
/// model of the type when no staged model is available.
///
/// Prefer [resolveTierModelPath] when the caller has to know whether a staged
/// model exists (the 3D scene only swaps out its procedural mesh when it does).
String assetForRewardTypeAndTier(
  RewardType type,
  int tier, {
  String? localModelsDir,
}) {
  return resolveTierModelPath(type, tier, localModelsDir: localModelsDir) ??
      assetForRewardType(type);
}
