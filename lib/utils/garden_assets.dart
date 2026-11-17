import '../models/reward_type.dart';

/// أيقونات أنواع المكافآت الستة فقط.
///
/// كانت تحمل أيضًا خلفية العالم 2D وشمسه وسحبه ونسخًا بديلة لكل نوع، وكلها
/// ذهبت مع حذف شاشتي 2D و«الواحة 2.5D» (§3.6/B7). `getIconAsset` هو ما
/// تستعمله الرئيسية والعدّاد والإحصاءات وشاشة 3D.
class GardenAssets {
  GardenAssets._();

  static const Map<RewardType, List<String>> variations = {
    RewardType.palmTree: ['assets/images/palm_tree_1.png'],
    RewardType.tree: ['assets/images/tree_1.png'],
    RewardType.house: ['assets/images/house_1.png'],
    RewardType.palace: ['assets/images/palace_1.png'],
    RewardType.mosque: ['assets/images/mosque_1.png'],
    RewardType.treasure: ['assets/images/treasure_1.png'],
  };

  static String getIconAsset(RewardType type) => variations[type]!.first;
}
