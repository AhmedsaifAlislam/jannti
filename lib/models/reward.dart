import 'reward_type.dart';

class Reward {
  final String id;
  final RewardType type;
  final double posX;
  final double posY;
  final DateTime earnedAt;
  final String dhikrId;

  const Reward({
    required this.id,
    required this.type,
    required this.posX,
    required this.posY,
    required this.earnedAt,
    required this.dhikrId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'posX': posX,
        'posY': posY,
        'earnedAt': earnedAt.toIso8601String(),
        'dhikrId': dhikrId,
      };

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: json['id'] as String,
        type: RewardType.values.firstWhere((e) => e.name == json['type']),
        posX: (json['posX'] as num).toDouble(),
        posY: (json['posY'] as num).toDouble(),
        earnedAt: DateTime.parse(json['earnedAt'] as String),
        dhikrId: json['dhikrId'] as String,
      );
}
