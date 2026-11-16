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
/// exists. The loader already scales every stage to its own height
/// (`tierHeight` in `model_fit.dart`: 0.6 / 2.3 / 3.4 / 5.5 / 9 world units), so a
/// reused file still reads as a bigger tree.
const Map<RewardType, Map<int, String>> kTierModelPaths = {
  RewardType.palmTree: {
    1: 'tier1/palm_seedling.glb',
    2: 'tier2/palm_small.glb',
    3: 'tier3/palm_medium.glb',
    4: 'tier4/palm_large.glb',
    5: 'tier5/palm_mature.glb',
  },
  RewardType.tree: {
    1: 'tier1/tree_seedling.glb',
    2: 'tier2/tree_sapling.glb',
    3: 'tier3/tree_growing.glb',
    4: 'tier4/tree_fruitful.glb',
    5: 'tier5/tree_celestial.glb',
  },
};

/// جسر النهر: موديل حجري مرسوم يعيش في جذر `assets/3d/` (يغطّيه إدخال
/// المجلد في `pubspec.yaml`، بعكس مجلدات المراحل التي تُسرد ملفًا ملفًا).
/// يصل من المصدر بمليون مثلث، ويُصغَّر إلى ٥٨ ألفًا بـ`gltf-transform` ثم
/// يُطبَّع بـ`tool/assets/prepare_bridge.py`.
const String kBridgeModel = 'assets/3d/bridge.glb';

/// هضبة القصور: موديل الجزيرة العشبية (١٫٨٨ × ٠٫١٩ × ١٫٣٣ وحدة) بديلًا عن
/// أسطوانة `CylinderGeometry(28, 33, 2.5)`. يُمدَّد إلى قاعدة الأسطوانة نفسها
/// (٨٥٫٨ × ٢٫٥ × ٥٩٫٤) كي تبقى `_calculateGroundElevation` والأبنية فوقها كما
/// هي. يعيش في جذر `assets/3d/` فيغطّيه إدخال المجلد في `pubspec.yaml`.
const String kPlateauModel = 'assets/3d/plateau.glb';

/// Every model file the APK ships. Must stay in sync with `pubspec.yaml`;
/// `test/asset_map_test.dart` fails when the two drift apart.
///
/// Files sitting directly in `assets/3d/` are covered by that folder entry and
/// are not repeated here. Anything under a subfolder is listed, because Flutter
/// does not walk a directory entry into its children.
const Set<String> kBundledModelAssets = {
  'assets/3d/tier1/palm_seedling.glb',
  'assets/3d/tier2/palm_small.glb',
  'assets/3d/tier3/palm_medium.glb',
  'assets/3d/tier4/palm_large.glb',
  'assets/3d/tier5/palm_mature.glb',
  'assets/3d/tier1/tree_seedling.glb',
  'assets/3d/tier2/tree_sapling.glb',
  'assets/3d/tier3/tree_growing.glb',
  'assets/3d/tier4/tree_fruitful.glb',
  'assets/3d/tier5/tree_celestial.glb',
  // The FreeLowPolyForest scene: one mesh per unique shape, cloned per
  // placement. Listed here (and not only in `nature_layout.dart`) so the
  // pubspec guard below also covers them — an undeclared mesh is a silent 404.
  'assets/3d/nature/birch_a.glb',
  'assets/3d/nature/birch_b.glb',
  'assets/3d/nature/grass_a.glb',
  'assets/3d/nature/grass_b.glb',
  'assets/3d/nature/lake_shore.glb',
  'assets/3d/nature/lake_water.glb',
  'assets/3d/nature/meadow_a.glb',
  'assets/3d/nature/meadow_b.glb',
  'assets/3d/nature/meadow_path.glb',
  'assets/3d/nature/mountain_a.glb',
  'assets/3d/nature/mountain_b.glb',
  'assets/3d/nature/rock_moss_a.glb',
  'assets/3d/nature/rock_moss_b.glb',
  'assets/3d/nature/rock_pile_a.glb',
  'assets/3d/nature/rock_pile_b.glb',
  'assets/3d/nature/tree_a.glb',
  'assets/3d/nature/tree_b.glb',
};

/// Colour maps that travel beside the staged models.
///
/// They are not optional decoration: three_dart's `GLTFLoader` wraps an image
/// stored inside the GLB in its own `Blob` class, and the browser image loader
/// only understands `String` and `html.Blob`. It falls through to
/// `url.startsWith(...)` on the wrapper, throws inside an image `onLoad`
/// callback, and the load future never completes — which is why every model
/// used to die on a 15 s timeout. A sidecar file takes the plain-string path.
///
/// The sidecar must sit in the same folder as its model and share its stem,
/// because that is the URI the rewritten glTF asks for.
Set<String> get kBundledModelTextures => {
  for (final model in kBundledModelAssets)
    model.replaceFirst(RegExp(r'\.glb$'), '.png'),
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
