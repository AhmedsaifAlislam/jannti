import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/community_stats_service.dart';
import '../utils/number_formatter.dart';

/// شريحة عدد المستخدمين النشطين.
/// الضغط 5 مرات خلال ثانيتين يكشف الرقم الحقيقي لثوانٍ.
class CommunityStatsChip extends StatefulWidget {
  const CommunityStatsChip({super.key});

  @override
  State<CommunityStatsChip> createState() => _CommunityStatsChipState();
}

class _CommunityStatsChipState extends State<CommunityStatsChip> {
  final CommunityStatsService _svc = CommunityStatsService();
  int _tapCount = 0;
  DateTime? _firstTapAt;

  void _onTap() {
    final now = DateTime.now();
    if (_firstTapAt == null || now.difference(_firstTapAt!).inSeconds >= 2) {
      _firstTapAt = now;
      _tapCount = 0;
    }
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      HapticFeedback.mediumImpact();
      _svc.revealTrueNumber();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_svc.enabled) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: _svc.reveal,
      builder: (_, revealOn, child) => ValueListenableBuilder<int>(
        valueListenable: _svc.displayed,
        builder: (_, driftValue, child) {
          final value = revealOn ? _svc.trueBase : driftValue;
          final color = revealOn
              ? const Color(0xFF00E676)
              : const Color(0xFFFFD700);
          return InkWell(
            onTap: _onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2818).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_alt_outlined, size: 13, color: color),
                  const SizedBox(width: 5),
                  Text(
                    '${NumberFormatter.toArabicCompact(value)} يذكرون الآن',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
