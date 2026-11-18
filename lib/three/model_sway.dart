/// Procedural sway for the palms and trees, applied in the vertex shader.
///
/// Every staged GLB here is a single mesh: no bones, no animation clips, one
/// material. Tilting the whole child in Dart would move the pivot — which
/// [fitModelToGround] seats *inside* the model, not at its base — so the trunk
/// would leave the ground and drag its shadow and root mound with it. Bending
/// the crown instead keeps the base exactly where it sits: each vertex is
/// displaced in x/z by a weight that grows with height and is zero at the
/// bottom.
///
/// **الترتيب مقصود:** `begin_vertex` يسبق `project_vertex`، فالإزاحة تُطبَّق
/// على `transformed` قبل تحويل العالم. القاعدة `h = 0` فلا تتحرك، والظل والكومة
/// وحلقة الزينة أطفال آخرون في المجموعة لا يمرّون بهذا الشادر أصلًا.
///
/// The phase comes from the model's world position (`modelMatrix[3]`), so no
/// two plants bend in lockstep and no per-instance phase uniform is needed —
/// every clone gets its own matrix for free.
library;

import 'package:three_dart_flutterflow/three_dart.dart' as three;

/// Master switch. A shader that fails to compile on some driver must never
/// take the garden down with it, so turning this off restores the previous
/// behaviour without touching any other code.
const bool kSwayEnabled = true;

/// Peak horizontal travel of the crown, as a fraction of the model height.
///
/// 1.8% of a 9-unit mature palm is 0.16 world units — about 3 px at the closest
/// zoom (`minDistance = 18`). The first pass used 5% (≈11 px on screen) and it
/// read as a rubber tree: a plant this still should only *breathe*. Bigger
/// amplitudes need a rig (B8), not a sine.
const double kPalmSwayFraction = 0.018;

/// Trees move less: their canopies are wider, so the same fraction is a longer
/// arc in world units.
const double kTreeSwayFraction = 0.012;

/// The 40 birches and trees of the nature island: background plants must be
/// even quieter than a reward tree, or the forest looks like it is underwater.
const double kNatureSwayFraction = 0.010;

/// The cross-wind axis travels this share of the main one, so the crown
/// traces an ellipse instead of sliding along a single line.
const double kSwayCrossRatio = 0.62;

/// Angular speeds in radians per second: periods of ≈11.4 s and ≈15.7 s.
///
/// The first pass ran at 1.45/1.15 (≈4.3 s / ≈5.5 s) and was rejected by eye
/// as "fast and obviously artificial" — a breeze at this scale should take
/// ten seconds to complete a breath, not four.
const double kSwaySpeedX = 0.55;
const double kSwaySpeedZ = 0.40;

/// Height weight exponent. 1 would bend the trunk like a uniform arc; 2.0
/// keeps the lower trunk nearly still and lets the fronds do the moving.
const double kSwayBendPower = 2.0;

/// Phase spread per world unit, so neighbouring plants are out of step.
const double kSwayPhasePerX = 0.7;
const double kSwayPhasePerZ = 1.3;

/// Extra phase drift on the cross axis.
const double kSwayPhaseDrift = 1.7;

/// Salt for the program cache.
///
/// **Bump this whenever the GLSL below changes.** The renderer keys programs
/// by this string, and a stale key would keep serving the previous shader
/// after a hot reload. It must also stay unique: the engine's default key is
/// the closure's own `toString()`, which is identical for every closure with
/// the same signature — another `onBeforeCompile` in the app would collide.
const String kSwayProgramCacheKey = 'jannati/sway/v3';

/// The shared time uniform. One object, updated once per frame in `render()`
/// and referenced by every swaying material, so ninety models cost one write
/// rather than ninety.
///
/// The value is **elapsed seconds since the scene started**, never a Unix
/// timestamp: 1.7 × 10⁹ s cannot be represented finely enough by a 32-bit
/// float (its step there is ≈256 s) and the sway would freeze.
Map<String, dynamic> newSwayClock() => <String, dynamic>{'value': 0.0};

/// ثابت GLSL من نوع `float`، مضمون الفاصلة العشرية.
///
/// **لماذا دالة بدل `'$value'`:** `dart2js` يطبع `2.0` كـ«2» لأن رقم JS لا
/// يحمل نوعًا، فيصل إلى الشادر `pow(swayH, 2)` — ولا يوجد تحميل
/// `pow(float, int)` في GLSL، فيفشل ترجمة الشادر كله على الويب وحده. اختبار
/// الـVM يرى `2.0` فيمرّ، ولهذا يُحرس النص المُولَّد هنا لا قيمة Dart وحدها.
String glslFloat(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}.0' : '$value';

/// Uniform declarations prepended to the vertex shader.
final String swayVertexUniforms = '''
uniform float uSwayTime;
uniform float uSwayBase;
uniform float uSwaySpan;
uniform float uSwayAmpX;
uniform float uSwayAmpZ;
''';

/// Replacement for `#include <begin_vertex>`.
///
/// `position.y` is the height axis in every staged export. [uSwayBase] and
/// [uSwaySpan] are the geometry's own bounding box, so the normalised height
/// is correct for a 0.6 seedling and a 9-unit palm alike.
final String swayBeginVertex =
    '''
#include <begin_vertex>
{
  float swayH = clamp((position.y - uSwayBase) / max(uSwaySpan, 0.0001), 0.0, 1.0);
  float swayBend = pow(swayH, ${glslFloat(kSwayBendPower)});
  float swayPhase = modelMatrix[3][0] * ${glslFloat(kSwayPhasePerX)} +
                    modelMatrix[3][2] * ${glslFloat(kSwayPhasePerZ)};
  transformed.x += sin(uSwayTime * ${glslFloat(kSwaySpeedX)} + swayPhase) * uSwayAmpX * swayBend;
  transformed.z += cos(uSwayTime * ${glslFloat(kSwaySpeedZ)} + swayPhase * ${glslFloat(kSwayPhaseDrift)}) * uSwayAmpZ * swayBend;
}
''';

/// Installs the sway shader on every mesh under [root].
///
/// Returns whether anything was installed. A mesh with no position data, a
/// flat bounding box or no vertex shader include is skipped rather than
/// throwing: one malformed model must not blank the garden.
///
/// [amplitudeFraction] is a fraction of the geometry height, so the same call
/// works for every tier. [clock] is the shared object from [newSwayClock].
bool installModelSway(
  three.Object3D root, {
  required double amplitudeFraction,
  required Map<String, dynamic> clock,
}) {
  if (!kSwayEnabled || amplitudeFraction <= 0) return false;
  var installed = false;

  root.traverse((node) {
    if (node is! three.Mesh) return;
    final geometry = node.geometry;
    if (geometry == null) return;
    if (geometry.boundingBox == null) geometry.computeBoundingBox();
    final box = geometry.boundingBox;
    if (box == null) return;

    final base = box.min.y;
    final span = box.max.y - base;
    if (!base.isFinite || !span.isFinite || span <= 0.001) return;

    final ampX = span * amplitudeFraction;
    final ampZ = ampX * kSwayCrossRatio;

    void attach(three.Material material) {
      material.onBeforeCompile = (dynamic shader, dynamic renderer) {
        final uniforms = shader.uniforms;
        if (uniforms is! Map) return;
        final source = shader.vertexShader;
        if (source is! String || !source.contains('#include <begin_vertex>')) {
          return;
        }

        uniforms['uSwayTime'] = clock;
        uniforms['uSwayBase'] = <String, dynamic>{'value': base};
        uniforms['uSwaySpan'] = <String, dynamic>{'value': span};
        uniforms['uSwayAmpX'] = <String, dynamic>{'value': ampX};
        uniforms['uSwayAmpZ'] = <String, dynamic>{'value': ampZ};

        shader.vertexShader =
            '$swayVertexUniforms\n'
            '${source.replaceFirst('#include <begin_vertex>', swayBeginVertex)}';
      };
      material.customProgramCacheKey = () => kSwayProgramCacheKey;
      material.needsUpdate = true;
      installed = true;
    }

    final raw = node.material;
    if (raw is Iterable) {
      for (final material in raw) {
        if (material is three.Material) attach(material);
      }
    } else if (raw is three.Material) {
      attach(raw);
    }
  });

  return installed;
}
