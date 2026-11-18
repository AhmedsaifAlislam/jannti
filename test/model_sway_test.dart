import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/three/model_sway.dart';
import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// يحاكي `WebGLParameters` بما يكفي: الحقول التي يلمسها التثبيت فقط.
class _FakeShader {
  Map<String, dynamic>? uniforms = <String, dynamic>{};
  String vertexShader = 'void main() {\n#include <begin_vertex>\n}';
}

/// حراسات التمايل الإجرائي. لا تحتاج سياق WebGL: الشادر يُحقن في
/// `onBeforeCompile` يدويًا ويُفحص نصه وقيمه، فلا يتحول انحدار في الصيغة إلى
/// نخيل ساكن على الجهاز بلا أن يفشل شيء.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('تمايل السعف', () {
    test('يثبّت uniform السعة والارتفاع ويحقن الشادر', () {
      final material = three.MeshStandardMaterial({'color': 0xFFFFFF});
      final mesh = three.Mesh(three.BoxGeometry(1, 4, 1), material);
      final clock = newSwayClock();

      final installed = installModelSway(
        mesh,
        amplitudeFraction: kPalmSwayFraction,
        clock: clock,
      );
      expect(installed, isTrue);
      expect(material.onBeforeCompile, isNotNull);
      expect(material.customProgramCacheKey(), kSwayProgramCacheKey);

      final shader = _FakeShader();
      material.onBeforeCompile!(shader, null);

      final uniforms = shader.uniforms!;
      // الساعة كائن واحد مشترك: تحديثه في `render()` يصل إلى كل المواد.
      expect(identical(uniforms['uSwayTime'], clock), isTrue);

      // BoxGeometry(1, 4, 1) يمتد من y = -2 إلى 2، فالقاعدة -2 والمدى 4.
      expect((uniforms['uSwayBase'] as Map)['value'], closeTo(-2.0, 1e-6));
      expect((uniforms['uSwaySpan'] as Map)['value'], closeTo(4.0, 1e-6));
      expect(
        (uniforms['uSwayAmpX'] as Map)['value'],
        closeTo(4 * kPalmSwayFraction, 1e-6),
      );
      expect(
        (uniforms['uSwayAmpZ'] as Map)['value'],
        closeTo(4 * kPalmSwayFraction * kSwayCrossRatio, 1e-6),
      );

      final vertex = shader.vertexShader;
      expect(vertex, contains('uniform float uSwayTime;'));
      expect(vertex, contains('pow(swayH, 2.0)'));
      // الحراسة الحقيقية: `dart2js` يكتب `2.0` كـ«2» فيفشل الشادر على الويب
      // وحده. النص المُولَّد هو ما يُفحص، لا قيمة Dart.
      expect(vertex, isNot(contains('pow(swayH, 2)')));
      expect(vertex, contains('uSwayTime * 0.55'));
      // الإزاحة على x/z وحدها: القاعدة لا ترتفع ولا تغرق.
      expect(vertex, isNot(contains('transformed.y')));
    });

    test('القاعدة مثبتة والطور مشتق من موضع الموديل', () {
      // الوزن يصفر عند أدنى نقطة ويصل واحدًا عند القمة؛ هذا ما يبقي الجذع
      // ثابتًا بينما يتحرك السعف وحده.
      expect(
        swayBeginVertex,
        contains(
          'clamp((position.y - uSwayBase) / max(uSwaySpan, 0.0001), 0.0, 1.0)',
        ),
      );
      // الطور من عمود الترجمة في مصفوفة العالم: نخيلتان متجاورتان لا تتمايلان
      // بتزامن آلي، ولا نحتاج uniform طور لكل نسخة.
      expect(swayBeginVertex, contains('modelMatrix[3][0]'));
      expect(swayBeginVertex, contains('modelMatrix[3][2]'));
    });

    test('الثابت الصحيح يُكتب كسرًا عشريًا في GLSL', () {
      // `dart2js` يطبع 2.0 كـ«2»؛ `pow(float, int)` بلا تحميل في GLSL.
      expect(glslFloat(2.0), '2.0');
      expect(glslFloat(0.55), '0.55');
      expect(glslFloat(1.0), '1.0');
      expect(glslFloat(0.0), '0.0');
      expect(swayBeginVertex, contains('pow(swayH, 2.0)'));
      expect(swayBeginVertex, isNot(contains('pow(swayH, 2)')));
    });

    test('النسب مضبوطة ومفتاح البرنامج مستقر', () {
      expect(kPalmSwayFraction, 0.018);
      expect(kTreeSwayFraction, 0.012);
      expect(kNatureSwayFraction, 0.010);
      expect(kPalmSwayFraction, greaterThan(kTreeSwayFraction));
      expect(kTreeSwayFraction, greaterThan(kNatureSwayFraction));
      expect(kSwayCrossRatio, inExclusiveRange(0.0, 1.0));
      // التمايل هادئ عن قصد: دورة تتجاوز العشر ثوانٍ.
      expect(2 * 3.141592653589793 / kSwaySpeedX, greaterThan(10.0));
      // تغيير الشادر يستلزم رفع الإصدار، وإلا بقي البرنامج القديم في الكاش.
      expect(kSwayProgramCacheKey, 'jannati/sway/v3');
    });

    test('مجموعة بلا شبكات لا تُثبّت شيئًا', () {
      final group = three.Group();
      expect(
        installModelSway(
          group,
          amplitudeFraction: kPalmSwayFraction,
          clock: newSwayClock(),
        ),
        isFalse,
      );
    });
  });
}
