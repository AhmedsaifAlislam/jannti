import 'reward_type.dart';

class Dhikr {
  final String id;
  final String arabicText;
  final String hadith;
  final RewardType rewardType;
  final String rewardDescription;
  final String actionLabel;

  const Dhikr({
    required this.id,
    required this.arabicText,
    required this.hadith,
    required this.rewardType,
    required this.rewardDescription,
    required this.actionLabel,
  });
}
