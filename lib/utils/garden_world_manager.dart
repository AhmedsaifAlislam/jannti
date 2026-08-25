import 'dart:math';
import 'dart:ui';
import '../models/reward.dart';
import '../models/reward_type.dart';
import 'garden_assets.dart';

class RewardPlacement {
  final Reward reward;
  final double x;
  final double y;
  final double size;
  final String assetPath;
  final double depthOpacity;
  final double priority;

  const RewardPlacement({
    required this.reward,
    required this.x,
    required this.y,
    required this.size,
    required this.assetPath,
    required this.depthOpacity,
    required this.priority,
  });

  Rect get rect =>
      Rect.fromLTWH(x - size / 2, y - size / 2, size + 16, size + 16);
}

class GardenWorldManager {
  GardenWorldManager._();

  static const double worldWidth = 5000;
  static const double worldHeight = 2000;
  static const double groundStart = worldHeight * 0.44;
  static const double groundEnd = worldHeight * 0.92;
  static const double groundHeight = groundEnd - groundStart;
  static const double oasisCenterX = worldWidth / 2;
  static const double oasisCenterY = groundStart + groundHeight * 0.5;

  static double _priorityScore(RewardType type) {
    switch (type) {
      case RewardType.palace:
        return 6;
      case RewardType.mosque:
        return 5;
      case RewardType.house:
        return 4;
      case RewardType.palmTree:
        return 3;
      case RewardType.tree:
        return 2;
      case RewardType.treasure:
        return 1;
    }
  }

  static double _groundCurveY(double x, double amplitude) {
    final dx = (x - oasisCenterX) / (worldWidth * 0.4);
    return -amplitude * dx * dx;
  }

  static double _collisionMargin(RewardType type) {
    switch (type) {
      case RewardType.palace:
        return 110;
      case RewardType.mosque:
        return 85;
      case RewardType.house:
        return 60;
      case RewardType.palmTree:
        return 50;
      case RewardType.tree:
        return 40;
      case RewardType.treasure:
        return 35;
    }
  }

  static List<RewardPlacement> placeRewards(List<Reward> rewards) {
    if (rewards.isEmpty) return [];

    final rng = Random(42);
    final placements = <RewardPlacement>[];

    final sorted = List<Reward>.from(rewards);
    sorted.sort((a, b) =>
        _priorityScore(b.type).compareTo(_priorityScore(a.type)));

    for (final reward in sorted) {
      final type = reward.type;
      final baseSize = GardenAssets.getBaseSize(type);
      final margin = _collisionMargin(type);
      const maxRetries = 60;

      double finalX = oasisCenterX;
      double finalY = oasisCenterY;

      for (int retry = 0; retry < maxRetries; retry++) {
        final cx = rng.nextDouble() * (worldWidth - baseSize * 2) + baseSize;
        final rawY = rng.nextDouble() * (groundHeight - baseSize * 2) +
            groundStart + baseSize;
        final curveOffset = _groundCurveY(cx, 80.0);
        final cy = (rawY + curveOffset)
            .clamp(groundStart + baseSize, groundEnd - baseSize);

        final tryRect = Rect.fromLTWH(
            cx - baseSize / 2 - margin,
            cy - baseSize / 2 - margin,
            baseSize + margin * 2 + 20,
            baseSize + margin * 2 + 20);

        bool overlap = false;
        for (final p in placements) {
          if (tryRect.overlaps(p.rect)) {
            overlap = true;
            break;
          }
        }

        if (!overlap) {
          finalX = cx;
          finalY = cy;
          break;
        }

        if (retry == maxRetries - 1) {
          finalX = cx;
          finalY = cy;
        }
      }

      final sizeVariation = 0.85 + rng.nextDouble() * 0.3;
      final perspectiveScale =
          1.0 - ((finalY - groundStart) / groundHeight) * 0.15;
      final imageSize = baseSize * sizeVariation * perspectiveScale;

      final dx = (finalX - oasisCenterX) / (worldWidth / 2);
      final dy = (finalY - oasisCenterY) / (groundHeight / 2);
      final dist = sqrt(dx * dx + dy * dy);
      final depthOpacity = (1.0 - dist * 0.12).clamp(0.7, 1.0);

      final assetPath =
          GardenAssets.getRandomAsset(type, seed: reward.id.hashCode);

      placements.add(RewardPlacement(
        reward: reward,
        x: finalX,
        y: finalY,
        size: imageSize,
        assetPath: assetPath,
        depthOpacity: depthOpacity,
        priority: _priorityScore(type).toDouble(),
      ));
    }

    placements.sort((a, b) => a.y.compareTo(b.y));
    return placements;
  }
}
