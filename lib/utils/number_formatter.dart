import '../models/reward_type.dart';

class NumberFormatter {
  static const arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  static String toArabic(int number) {
    return number.toString().split('').map((digit) {
      final intDigit = int.tryParse(digit);
      return intDigit != null ? arabicDigits[intDigit] : digit;
    }).join();
  }

  static String formatLarge(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    }
    return toArabic(number);
  }

  static String formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${toArabic(diff.inMinutes)} دقيقة';
    if (diff.inHours < 24) return 'منذ ${toArabic(diff.inHours)} ساعة';
    if (diff.inDays < 30) return 'منذ ${toArabic(diff.inDays)} يوم';
    return 'منذ ${toArabic(diff.inDays ~/ 30)} شهر';
  }

  static String countWithType(int count, RewardType type) {
    if (count == 0) {
      return 'لا ${type.arabicPluralFew}';
    }
    if (count == 1) {
      return '${type.arabicSingular} واحدة';
    }
    if (count == 2) {
      return type.arabicDual;
    }
    if (count >= 3 && count <= 10) {
      return '${toArabic(count)} ${type.arabicPluralFew}';
    }
    return '${toArabic(count)} ${type.arabicSingular}';
  }

  /// Número compacto باللغة العربية (مثلاً: 14200 → ١٤٫٢ ألف).
  static String toArabicCompact(int number) {
    if (number >= 1000000) return '${_arabicDecimal(number / 1000000)} مليون';
    if (number >= 1000) return '${_arabicDecimal(number / 1000)} ألف';
    return toArabic(number);
  }

  static String _arabicDecimal(double v) {
    final s = v >= 100 ? v.round().toString() : v.toStringAsFixed(1);
    // تحويل كل رقم إلى عربي مع الاحتفاظ بالنقطة العشرية كما هي
    return s.split('').map((ch) {
      final d = int.tryParse(ch);
      return d != null ? arabicDigits[d] : ch;
    }).join();
  }
}
