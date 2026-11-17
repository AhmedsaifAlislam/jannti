import 'package:flutter/material.dart';

/// # نظام الطباعة المركزي — جنتي
///
/// هذا الملف هو **المصدر الوحيد** لأحجام الخطوط وأوزانها وارتفاعاتها وعائلتها.
/// لا يُكتب `fontFamily` أو `fontSize` أو `fontWeight` داخل الشاشات إلا في
/// استثناء موثّق (رموز تعبيرية، أو سطر قرآني واحد له طابع خاص).
///
/// ## القواعد
/// 1. **العائلة واحدة:** Cairo (Light 300 / Medium 500 / Bold 700) — B1.
/// 2. **الطباعة لا تحمل ألوانًا.** اللون من مخطط الألوان أو من السطح نفسه:
///    `AppType.cardTitle.copyWith(color: gold)`.
/// 3. **الدور يتبع المكان لا الرقم.** لا تستخدم `cardTitle` لعنوان شاشة، ولا
///    `caption` لزر. الجدول أدناه يحدد الدور بموضعه.
/// 4. **لا تكبير بلا سبب.** عند الشك اختر الدور الأصغر؛ النص العربي يحتاج
///    مساحة أكبر من اللاتيني في الارتفاع لا في العرض.
/// 5. الرموز التعبيرية (🌿 🎵 🌴) ليست نصًا: تُترك بأحجامها الصريحة لأنها
///    تُقاس كصور، وليست جزءًا من سلّم الطباعة.
///
/// ## سلّم الأدوار
///
/// | الدور | الحجم/الوزن | مكانه |
/// |---|---|---|
/// | [brandTitle] | 46 Bold · تباعد 2 | شعار شاشة الافتتاح |
/// | [brandSubtitle] | 14 · تباعد 1.5 | سطر «واحة الذكر» تحت الشعار |
/// | [brandMark] | 26 Bold | «جَنَّتِي» في رأس الرئيسية |
/// | [onboardingTitle] | 26 Bold | عنوان شريحة التعريف |
/// | [screenTitle] | 22 Bold | عنوان AppBar لكل شاشة |
/// | [cardTitleLarge] | 22 Bold | عنوان بطاقة بارزة (إذاعة السكينة) |
/// | [dialogHero] | 24 Bold | عنوان حوار التحديث |
/// | [dialogTitle] | 20 Bold | عنوان حوار/شيت |
/// | [sectionTitle] | 20 Bold | عنوان قسم داخل شاشة أو بطاقة |
/// | [cardTitle] | 18 Bold | عنوان بطاقة عادي |
/// | [cardTitleSmall] | 16 Bold | عنوان بطاقة صغيرة/وسم |
/// | [verseHero] | 32 Bold · 1.6 | الذكر في وضع الزن (ملء الشاشة) |
/// | [verse] | 24 Bold · 1.6 | الذكر المميز في الرئيسية |
/// | [verseCompact] | 19 Bold · 1.5 | بطاقة ذكر في قائمة |
/// | [verseSmall] | 14 Bold | ذكر قصير داخل بطاقة فضائل |
/// | [hadithBody] | 18 · 1.8 | متن حديث للقراءة |
/// | [quote] | 16 Bold · 1.5 | اقتباس/حكمة داخل بطاقة |
/// | [counterHero] | 58 Bold · 1.0 | رقم العدّاد في الزن |
/// | [counterValue] | 48 Bold · 1.1 | رقم العدّاد في الشاشة |
/// | [statValue] | 20 Bold · 1.0 | رقم إحصائي في بطاقة الرئيسية |
/// | [statValueSmall] | 18 Bold · 1.1 | رقم إحصائي في لوحة الإحصاءات |
/// | [statValueCompact] | 16 Bold | رقم صغير داخل بطاقة |
/// | [bodyHero] | 18 | سطر حالة/تحميل بارز |
/// | [bodyLarge] | 14 · 1.6 | وصف تعريف/نص قراءة |
/// | [body] | 13 · 1.5 | متن حوار/رسالة |
/// | [bodyStrong] | 13 Bold | متن مؤكد/سطر معلومات |
/// | [bodySmall] | 12 | تفاصيل بطاقة |
/// | [caption] | 11 | تسمية توضيحية |
/// | [micro] | 10 | تسمية دقيقة |
/// | [nano] | 9 | أصغر تسمية |
/// | [hudNano] | 8.5 | تسمية فرعية في HUD |
/// | [hudValue] | 14 Bold | قيمة في HUD |
/// | [button] | 13 Bold | زر رئيسي |
/// | [buttonSmall] | 12 | زر صغير داخل شيت |
/// | [buttonHero] | 16 Bold | زر CTA في التعريف |
/// | [textButton] | 13 | زر نصي ثانوي |
/// | [labelStrong] | 11 Bold | شريحة/وسم صغير |
/// | [labelMicro] | 10 Bold | وسم HUD/شريحة دقيقة |
/// | [labelNano] | 9 Bold | شارة تصنيف |
///
/// ## ما لا يفعله هذا الملف
/// - لا يغيّر ألوانًا ولا ظلالًا ولا تباعد أسطر خاصًا بسطح واحد.
/// - لا يستبدل `TextTheme` في Material: الثيم يبقى كما هو حتى لا تتغيّر
///   النصوص غير المنسّقة (أزرار الحوارات مثلًا) بلا قصد.
abstract final class AppType {
  const AppType._();

  /// العائلة الوحيدة المسموح بها في الحزمة.
  static const String family = 'Cairo';

  // ── الهوية والشعار ────────────────────────────────────────────────────────
  static const TextStyle brandTitle = TextStyle(
    fontFamily: family,
    fontSize: 46,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
  );

  static const TextStyle brandSubtitle = TextStyle(
    fontFamily: family,
    fontSize: 14,
    letterSpacing: 1.5,
  );

  static const TextStyle brandMark = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle onboardingTitle = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.bold,
  );

  // ── هيكل الشاشة ───────────────────────────────────────────────────────────
  static const TextStyle screenTitle = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle cardTitleLarge = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle dialogHero = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle dialogTitle = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle cardTitleSmall = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  // ── النص الروحاني ─────────────────────────────────────────────────────────
  static const TextStyle verseHero = TextStyle(
    fontFamily: family,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.6,
  );

  static const TextStyle verse = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.6,
  );

  static const TextStyle verseCompact = TextStyle(
    fontFamily: family,
    fontSize: 19,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );

  static const TextStyle verseSmall = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle hadithBody = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.8,
  );

  static const TextStyle quote = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );

  // ── الأرقام ───────────────────────────────────────────────────────────────
  static const TextStyle counterHero = TextStyle(
    fontFamily: family,
    fontSize: 58,
    fontWeight: FontWeight.bold,
    height: 1.0,
  );

  static const TextStyle counterValue = TextStyle(
    fontFamily: family,
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  static const TextStyle statValue = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.0,
  );

  static const TextStyle statValueSmall = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  static const TextStyle statValueCompact = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  // ── متن ───────────────────────────────────────────────────────────────────
  static const TextStyle bodyHero = TextStyle(fontFamily: family, fontSize: 18);

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.6,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.5,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 12,
  );

  static const TextStyle caption = TextStyle(fontFamily: family, fontSize: 11);

  static const TextStyle micro = TextStyle(fontFamily: family, fontSize: 10);

  static const TextStyle nano = TextStyle(fontFamily: family, fontSize: 9);

  static const TextStyle hudNano = TextStyle(fontFamily: family, fontSize: 8.5);

  static const TextStyle hudValue = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // ── أزرار ووسوم ───────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: family,
    fontSize: 12,
  );

  static const TextStyle buttonHero = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle textButton = TextStyle(
    fontFamily: family,
    fontSize: 13,
  );

  static const TextStyle labelStrong = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle labelMicro = TextStyle(
    fontFamily: family,
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle labelNano = TextStyle(
    fontFamily: family,
    fontSize: 9,
    fontWeight: FontWeight.bold,
  );

  /// كل الأدوار، لاختبارات الانضباط وللتوثيق.
  static const Map<String, TextStyle> all = <String, TextStyle>{
    'brandTitle': brandTitle,
    'brandSubtitle': brandSubtitle,
    'brandMark': brandMark,
    'onboardingTitle': onboardingTitle,
    'screenTitle': screenTitle,
    'cardTitleLarge': cardTitleLarge,
    'dialogHero': dialogHero,
    'dialogTitle': dialogTitle,
    'sectionTitle': sectionTitle,
    'cardTitle': cardTitle,
    'cardTitleSmall': cardTitleSmall,
    'verseHero': verseHero,
    'verse': verse,
    'verseCompact': verseCompact,
    'verseSmall': verseSmall,
    'hadithBody': hadithBody,
    'quote': quote,
    'counterHero': counterHero,
    'counterValue': counterValue,
    'statValue': statValue,
    'statValueSmall': statValueSmall,
    'statValueCompact': statValueCompact,
    'bodyHero': bodyHero,
    'bodyLarge': bodyLarge,
    'body': body,
    'bodyStrong': bodyStrong,
    'bodySmall': bodySmall,
    'caption': caption,
    'micro': micro,
    'nano': nano,
    'hudNano': hudNano,
    'hudValue': hudValue,
    'button': button,
    'buttonSmall': buttonSmall,
    'buttonHero': buttonHero,
    'textButton': textButton,
    'labelStrong': labelStrong,
    'labelMicro': labelMicro,
    'labelNano': labelNano,
  };
}
