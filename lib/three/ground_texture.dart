import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_gl_flutterflow/flutter_gl.dart' show Uint8Array;
import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// حِزَم الخامات المرسومة يدويًا لأرض الجنة (FreeStylized، رخصة حرة للاستخدام
/// التجاري وغير التجاري).
///
/// «grass_02» هي الأرضية الأساسية: عشب ناعم بأزهار بيضاء صغيرة، تكراره لا يقرأ
/// كنمط. «moss_ground_01» مخصّصة لبقع الغرس والكومة تحت الشجرة: طحلب وأرض بنية
/// وبقع فاتحة، فتفصل مكان الغرسة عن المرج بلا لون مصمت.
const String kGrassBaseTexture = 'assets/3d/textures/grass_base.png';
const String kGroundSpotTexture = 'assets/3d/textures/ground_spots.png';

/// ماء مرسوم يدويًا (موج فيروزي برغوة) بدل الفيروزي المصمت.
///
/// الملف الأصلي ٢٠٤٨×٢٠٤٨ و٢٫٥ ميجابايت، وهذا تكرار بلا نهاية: أي مقطع منه
/// يكفي. النسخة المدمجة ٥١٢×٥١٢ (٤٢٨ ك.ب) — أكبر من أي مربع يظهر على الشاشة.
const String kRiverWaterTexture = 'assets/3d/textures/river_water.png';

/// عشب بصخور مستديرة (FreeStylized `grass_with_rocks_01`) لحواف النهر.
/// تعطي الضفة حصى وأعشابًا معًا، فتنتهي حافة الماء عند شيء مرسوم بدل شريط
/// رملي مصمت كان يخرج أصفر فوسفوريًا تحت شمس الظهيرة.
const String kGrassRocksTexture = 'assets/3d/textures/grass_rocks.png';

/// صخر الجرف: مولَّد إجرائيًا بـ`tool/assets/prep_cliff_texture.py`.
///
/// لا مرجع فني له لأن الجزيرة كلها تُبنى في الكود (`_buildIslandShell`): لا
/// يوجد UV جاهز لأي أطلس، فالمطلوب خامة متكرّرة بلا خطّ لحام. الوصفات نفسها
/// (فورونوي ملتوٍ + طبقات أفقية + حبيبات) تُغني عن الموديل الجاهز، واللون
/// **بارد** لأن شمس الظهيرة تحذف نصف الأزرق فيخرج رماديًا دافئًا لا أصفر.
const String kCliffRockTexture = 'assets/3d/textures/cliff_rock.png';

/// يفكّ ترميز صورة [asset] ويلفّها في `DataTexture` قابل للتكرار.
///
/// التكرار نفسه **لا** يُضبط هنا عبر `texture.repeat`: الظلّال في three_dart
/// يعرّف `uvTransform` لكن المُصيِّر لا ينسخ مصفوفة الخامة إليه أبدًا، فتبقى
/// الخامة بمقياس ١:١ مهما كانت قيمة `repeat`. من يريد تكرارًا يضرب إحداثيات
/// UV على الهندسة نفسها قبل رفع الخامة، مع `RepeatWrapping` هنا.
///
/// لا نستخدم `TextureLoader` عن قصد: الخامة العادية تُرفَع عبر مسار يقرأ
/// `image.data`، وعنصر `<img>` في المتصفح لا يملك هذا الحقل، فتصل الأرض إلى
/// WebGL كسطح أسود معتم — وهو بالضبط العطل الذي جعل كل موديلات GLB تُرسم ظلًا
/// أسود قبل `model_texture.dart`. أما `DataTexture` فترفع مصفوفة البايتات التي
/// نسلّمها لها كما هي، فيعمل المسار على الويب وعلى الجهاز.
///
/// `generateMipmaps` يبقى `false`: مُحمِّل three_dart يحجز مستويات الـmip عبر
/// `texStorage2D` لكنه يملأ المستوى صفر فقط، فتُملأ الباقي أصفارًا — وحينها
/// تُقرأ الأرض البعيدة سوداء. خامة بمستوى واحد تُظهر البكسلات التي رفعناها.
Future<three.DataTexture?> loadGroundTexture(
  String asset, {
  bool mirrored = false,
}) async {
  ui.Image? image;
  try {
    final ByteData data = await rootBundle.load(asset);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    image = frame.image;

    final ByteData? pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (pixels == null) return null;

    final wrap = mirrored ? three.MirroredRepeatWrapping : three.RepeatWrapping;

    return three.DataTexture(
        Uint8Array.from(
          pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
        ),
        image.width,
        image.height,
        three.RGBAFormat,
        three.UnsignedByteType,
      )
      ..name = asset.split('/').last
      ..wrapS = wrap
      ..wrapT = wrap
      ..magFilter = three.LinearFilter
      ..minFilter = three.LinearFilter
      ..generateMipmaps = false
      // three_dart لا يضبط `needsUpdate` في مُنشئ DataTexture، فتبقى `version`
      // صفرًا ولا يرفع المُصيِّر الخامة أبدًا.
      ..needsUpdate = true;
  } catch (e) {
    // ignore: avoid_print
    print('⚠️ ground texture failed for $asset: $e');
    return null;
  } finally {
    image?.dispose();
  }
}
