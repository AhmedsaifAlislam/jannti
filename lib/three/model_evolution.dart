/// Visual evolution ladder for the 3D reward models.
///
/// This is deliberately separate from `TierSystem` (the player's rank): the
/// garden shows a model stage, while the rank screen counts milestones. Both
/// now share the same tier boundaries so the two never contradict each other.
///
/// The ladder is:
///   * tier 1: 1-99, with a growth step at 10 and growth + colour at 25.
///     Every ten rewards merge into one grown model; the remainder still shows
///     as individual seedlings (see [modelDisplayCount]).
///   * tier 2: 100-999, growth at 200, growth + colour at 500.
///   * tier 3: 1000-4999, growth at 2000, growth + colour at 3000.
///   * tier 4: 5000-9999, growth at 6000, growth + colour at 8000.
///   * tier 5: 10000+, growth at 15000, growth + colour at 20000, then a
///     growth step every 10000 (capped so a palm never outgrows the world).
library;

/// First count of each tier (index 0 is tier 1).
const List<int> kModelTierStarts = <int>[1, 100, 1000, 5000, 10000];

/// Sub-stage counts inside each tier.
///
/// Index 0 is the first sub-stage (growth only) and index 1 is the second
/// (growth plus colour). Tier 5 repeats the pattern every 10000 after 20000.
const List<List<int>> kModelSubStages = <List<int>>[
  <int>[10, 25],
  <int>[200, 500],
  <int>[2000, 3000],
  <int>[6000, 8000],
  <int>[15000, 20000],
];

/// The tier that [count] rewards unlock.
int modelTierForCount(int count) {
  if (count >= 10000) return 5;
  if (count >= 5000) return 4;
  if (count >= 1000) return 3;
  if (count >= 100) return 2;
  return 1;
}

/// 0 = base model, 1 = first sub-stage (grow), 2 = second (grow + colour).
int modelStageForCount(int count) {
  if (count <= 0) return 0;
  final tier = modelTierForCount(count);
  final stages = kModelSubStages[tier - 1];
  if (count >= stages[1]) return 2;
  if (count >= stages[0]) return 1;
  return 0;
}

/// How many rewards one full model absorbs inside tier 1.
const int kModelMergeBlock = 10;

/// Number of *completed* tier-1 models: one for every full block of ten.
int modelFullCount(int count) {
  if (count < kModelMergeBlock) return 0;
  return count ~/ kModelMergeBlock;
}

/// How many models of one type the scene should show.
///
/// Every dhikr is a seedling, but ten of them merge into one grown model so the
/// meadow never fills with a hundred copies. Tier 1 therefore shows
/// `completed blocks + leftover seedlings`: at 11 that is the block of ten plus
/// the eleventh seedling, at 19 one grown model plus nine seedlings, and at 20
/// the nine seedlings have merged into a second grown model. Above tier 1 the
/// type is represented by a single model that steps at its own thresholds.
int modelDisplayCount(int count) {
  if (count <= 0) return 0;
  if (modelTierForCount(count) > 1) return 1;
  return modelFullCount(count) + (count % kModelMergeBlock);
}

/// True when the model at [index] stands for a completed block, so it carries
/// the tier's growth and colour instead of waiting as a single seedling.
bool modelIsFull(int count, int index) {
  if (count <= 0) return false;
  if (modelTierForCount(count) > 1) return true;
  return index < modelFullCount(count);
}

/// Extra scale for an explicit tier/stage pair, without the tier-5 repeats.
///
/// The decor system rolls a random tier/stage, so it needs the multiplier
/// directly rather than by reconstructing a count.
double modelScaleForStage(int tier, int stage) {
  var multiplier = 1.0;
  if (stage >= 1) multiplier += tier == 1 ? 0.05 : 0.08;
  if (stage >= 2) multiplier += 0.08;
  return multiplier.clamp(1.0, 1.25);
}

/// Extra scale applied on top of [tierHeight] for the current count.
///
/// +5% for the first tier-1 step, +8% for every other step, capped at 1.25 so
/// even a tier-5 palm stays well inside the world's proportions.
double modelScaleMultiplier(int count) {
  if (count <= 0) return 1.0;
  final tier = modelTierForCount(count);
  var multiplier = modelScaleForStage(tier, modelStageForCount(count));
  if (tier == 5) {
    for (var start = 30000; start <= count; start += 10000) {
      multiplier += 0.08;
    }
  }
  return multiplier.clamp(1.0, 1.25);
}

/// Colour tint for an explicit tier/stage pair, or null for the base look.
int? modelTintForStage(int tier, int stage) {
  if (stage < 2) return null;
  switch (tier) {
    case 1:
      return 0xFFE8C97A; // warm gold
    case 2:
      return 0xFF7FE3B0; // deep emerald
    case 3:
      return 0xFFFFD700; // gold
    case 4:
      return 0xFFFFF3C4; // radiant gold
    default:
      return 0xFFFFF8E1; // celestial light
  }
}

/// Colour tint for the second sub-stage of a tier, or null for the base look.
int? modelTintForCount(int count) {
  if (count <= 0) return null;
  return modelTintForStage(modelTierForCount(count), modelStageForCount(count));
}
