import 'package:flutter/material.dart';

import 'app_typography.dart';

/// ثيم التطبيق الموحّد.
///
/// الطباعة تُعرَّف في [AppType] وتُستهلك في الشاشات بالأدوار. أما
/// `TextTheme` هنا فيُترك على مقاسات Material الافتراضية عن قصد حتى لا
/// تتغيّر النصوص غير المنسّقة (مثل أزرار الحوارات التي ترث `labelLarge`)
/// بلا مراجعة بصرية. الدور الطباعي يُطلب صراحةً من [AppType].
ThemeData buildAppTheme() {
  return ThemeData(
    // خط واحد فقط: Cairo. لا عائلة ثانية في الحزمة، وكل نص يرث Cairo من هنا
    // ما لم يُعيَّن صراحةً — أُزيلت Amiri في 2026-11-17 (PROJECT.md §3.6/B1).
    fontFamily: AppType.family,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontWeight: FontWeight.w500),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D1F17),
    useMaterial3: true,
  );
}
