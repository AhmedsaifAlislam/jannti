import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/theme/app_typography.dart';

/// حراسة نظام الطباعة المركزي.
///
/// الهدف ليس تجميل الكود: أي انحراف هنا يعني أن شاشة ما عادت ترث Cairo، أو أن
/// دورًا صار يحمل لونًا (واللون من مخطط الألوان لا من الطباعة)، أو أن حجمًا
/// خرج عن السلّم فصار أكبر من مكانه.
void main() {
  test('كل دور يستخدم Cairo وحده', () {
    expect(AppType.all, isNotEmpty);
    for (final entry in AppType.all.entries) {
      expect(
        entry.value.fontFamily,
        AppType.family,
        reason: '${entry.key} لا يستخدم ${AppType.family}',
      );
    }
  });

  test('الطباعة لا تحمل ألوانًا', () {
    for (final entry in AppType.all.entries) {
      expect(entry.value.color, isNull, reason: '${entry.key} يحمل color');
      expect(
        entry.value.backgroundColor,
        isNull,
        reason: '${entry.key} يحمل backgroundColor',
      );
    }
  });

  test('سلّم الأحجام محصور بين hudNano و counterHero', () {
    final smallest = AppType.all.values
        .map((style) => style.fontSize!)
        .reduce((a, b) => a < b ? a : b);
    final largest = AppType.all.values
        .map((style) => style.fontSize!)
        .reduce((a, b) => a > b ? a : b);

    expect(smallest, 8.5, reason: 'أصغر دور يجب أن يبقى hudNano');
    expect(largest, 58, reason: 'أكبر دور يجب أن يبقى counterHero');
  });

  test('الأدوار الأساسية مثبتة بقيمها', () {
    expect(AppType.brandTitle.fontSize, 46);
    expect(AppType.brandTitle.fontWeight, FontWeight.bold);
    expect(AppType.brandTitle.letterSpacing, 2);

    expect(AppType.verseHero.fontSize, 32);
    expect(AppType.verseHero.height, 1.6);

    expect(AppType.counterHero.fontSize, 58);
    expect(AppType.counterHero.height, 1.0);

    expect(AppType.body.fontSize, 13);
    expect(AppType.body.height, 1.5);

    expect(AppType.caption.fontSize, 11);
    expect(AppType.hudNano.fontSize, 8.5);
  });

  test('لا تعيين عائلة خط خارج lib/theme', () {
    final offenders = <String>[];
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'شغّل الاختبار من جذر المشروع');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.contains('lib/theme/')) continue;
      if (entity.readAsStringSync().contains('fontFamily:')) {
        offenders.add(normalized);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'العائلة تُضبط في lib/theme فقط: ${offenders.join(', ')}',
    );
  });

  test('لا تعود Amiri إلى الكود أو الحزمة', () {
    final amiriFamily = RegExp(r'''fontFamily:\s*['"]Amiri['"]''');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (amiriFamily.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path.replaceAll('\\', '/'));
      }
    }

    expect(offenders, isEmpty, reason: offenders.join(', '));
  });
}
