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

  factory Reward.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    final requiredFields = [
      'id',
      'type',
      'posX',
      'posY',
      'earnedAt',
      'dhikrId',
    ];
    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        throw FormatException(
          'Reward.fromJson: missing required field "$field"',
        );
      }
    }

    // Validate reward type
    final typeName = json['type'] as String;
    final typeIndex = RewardType.values.indexWhere((e) => e.name == typeName);
    if (typeIndex == -1) {
      throw FormatException('Reward.fromJson: invalid reward type "$typeName"');
    }
    final type = RewardType.values[typeIndex];

    // Validate numeric fields
    final posX = (json['posX'] as num?)?.toDouble();
    final posY = (json['posY'] as num?)?.toDouble();
    if (posX == null || posY == null) {
      throw FormatException(
        'Reward.fromJson: posX or posY is not a valid number',
      );
    }

    // Validate date
    final earnedAtStr = json['earnedAt'] as String;
    DateTime earnedAt;
    try {
      earnedAt = DateTime.parse(earnedAtStr);
    } catch (e) {
      throw FormatException(
        'Reward.fromJson: invalid earnedAt date format "$earnedAtStr"',
      );
    }

    return Reward(
      id: json['id'] as String,
      type: type,
      posX: posX,
      posY: posY,
      earnedAt: earnedAt,
      dhikrId: json['dhikrId'] as String,
    );
  }
}
