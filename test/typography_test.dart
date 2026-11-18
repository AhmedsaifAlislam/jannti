import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/theme/app_typography.dart';

/// حراسة نظام الطباعة المركزي.
///
/// الهدف ليس تجميل الكود: أي انحراف هنا يعني أن شاشة ما عادت ترث Cairo، أو أن
/// دورًا صار يحمل لونًا (واللون من مخطط الألوان لا من الطباعة)، أو أن حجمًا
/// خرج عن السلّم فصار أكبر من مكانه، أو أن Amiri تسلّل خارج النص الروحاني.
void main() {
  test('Cairo للواجهة وAmiri للنص الروحاني وحدهما', () {
    expect(AppType.all, isNotEmpty);
    expect(AppType.spiritualRoles, hasLength(9));
    for (final entry in AppType.all.entries) {
      final expected = AppType.spiritualRoles.contains(entry.key)
          ? AppType.spiritualFamily
          : AppType.family;
      expect(
        entry.value.fontFamily,
        expected,
        reason: '${entry.key} يجب أن يستخدم $expected',
      );
    }
  });

  test('Amiri لا يخرج عن الأدوار الروحانية', () {
    for (final entry in AppType.all.entries) {
      if (AppType.spiritualRoles.contains(entry.key)) continue;
      expect(
        entry.value.fontFamily,
        isNot(AppType.spiritualFamily),
        reason: '${entry.key} ليس نصًا روحانيًا فلا يلبس Amiri',
      );
    }
  });

  test('ملفا Amiri معلنان في pubspec وموجودان', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Amiri'));
    for (final path in const [
      'assets/fonts/Amiri-Regular.ttf',
      'assets/fonts/Amiri-Bold.ttf',
    ]) {
      expect(pubspec, contains(path), reason: 'pubspec لا يعلن $path');
      expect(File(path).existsSync(), isTrue, reason: '$path مفقود');
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
}
